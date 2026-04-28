defmodule Gallformers.Keys.PdfGenerator do
  @moduledoc """
  Generates PDF versions of identification keys using Typst.

  Compiles key data with a Typst template and uploads the resulting PDF to S3.
  """

  require Logger

  alias Gallformers.Storage.PDFKeys
  alias Gallformers.Keys.Key

  @template_path "priv/typst/key.typ"

  @doc """
  Generates a PDF file from a key.

  Returns `{:ok, output_path}` on success or `{:error, reason}` on failure.

  ## Options
    * `:images` - Whether to include images (default: `false`)
    * `:output_path` - Custom output path (default: temp file)
    * `:typst_cmd` - Typst binary name (default: `"typst"`)
  """
  @spec generate_pdf(Key.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_pdf(key, opts \\ []) do
    images = Keyword.get(opts, :images, false)
    typst_cmd = Keyword.get(opts, :typst_cmd, "typst")

    output_path =
      Keyword.get_lazy(opts, :output_path, fn ->
        Path.join(System.tmp_dir!(), "key-#{key.slug}-#{System.unique_integer([:positive])}.pdf")
      end)

    json = Key.serialize(key)
    template = Application.app_dir(:gallformers, @template_path)

    args = [
      "compile",
      "--input",
      "data=#{json}",
      "--input",
      "images=#{images}",
      template,
      output_path
    ]

    try do
      case System.cmd(typst_cmd, args, stderr_to_stdout: true) do
        {_output, 0} ->
          {:ok, output_path}

        {output, exit_code} ->
          Logger.error("Typst compilation failed (exit #{exit_code}): #{output}")
          {:error, {:typst_failed, exit_code, output}}
      end
    rescue
      e in ErlangError ->
        Logger.error("Typst binary not found: #{inspect(e)}")
        {:error, {:typst_not_found, typst_cmd}}
    end
  end

  @doc """
  Generates PDFs and uploads them to S3.

  Generates the text-only variant always. Generates the with-images
  variant only if the key has images in its couplet data.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @spec generate_and_upload(Key.t()) :: :ok | {:error, term()}
  def generate_and_upload(key) do
    with {:ok, pdf_path} <- generate_pdf(key, images: false),
         pdf_data = File.read!(pdf_path),
         :ok <- PDFKeys.upload_pdf(key, :text_only, pdf_data),
         :ok <- File.rm(pdf_path) do
      if Key.key_has_images?(key) do
        generate_and_upload_variant(key, images: true)
      else
        :ok
      end
    else
      {:error, reason} ->
        Logger.error("PDF generation/upload failed for key #{key.slug}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_and_upload_variant(key, opts) do
    with {:ok, pdf_path} <- generate_pdf(key, opts),
         pdf_data = File.read!(pdf_path),
         :ok <- PDFKeys.upload_pdf(key, :with_images, pdf_data),
         :ok <- File.rm(pdf_path) do
      :ok
    else
      {:error, reason} ->
        Logger.error("PDF variant upload failed for key #{key.slug}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
