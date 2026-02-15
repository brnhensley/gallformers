defmodule Gallformers.Keys.PdfGenerator do
  @moduledoc """
  Generates PDF versions of identification keys using Typst.

  Serializes key data to JSON, compiles with a Typst template,
  and uploads the resulting PDF to S3.
  """

  require Logger

  alias Gallformers.Storage

  @template_path "priv/typst/key.typ"

  @doc """
  Serializes a Key struct to a JSON string suitable for Typst input.
  """
  @spec serialize_key(Gallformers.Keys.Key.t()) :: String.t()
  def serialize_key(key) do
    %{
      title: key.title,
      slug: key.slug,
      subtitle: key.subtitle,
      authors: key.authors || [],
      citation: key.citation,
      citation_url: key.citation_url,
      description: key.description,
      version: key.version,
      couplets: key.couplets
    }
    |> Jason.encode!()
  end

  @doc """
  Generates a PDF file from a key.

  Returns `{:ok, output_path}` on success or `{:error, reason}` on failure.

  ## Options
    * `:images` - Whether to include images (default: `false`)
    * `:output_path` - Custom output path (default: temp file)
    * `:typst_cmd` - Typst binary name (default: `"typst"`)
  """
  @spec generate_pdf(Gallformers.Keys.Key.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_pdf(key, opts \\ []) do
    images = Keyword.get(opts, :images, false)
    typst_cmd = Keyword.get(opts, :typst_cmd, "typst")

    output_path =
      Keyword.get_lazy(opts, :output_path, fn ->
        Path.join(System.tmp_dir!(), "key-#{key.slug}-#{System.unique_integer([:positive])}.pdf")
      end)

    json = serialize_key(key)
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
  Returns the S3 paths for a key's PDFs.
  """
  @spec s3_paths(Gallformers.Keys.Key.t()) :: %{text_only: String.t(), with_images: String.t()}
  def s3_paths(key) do
    %{
      text_only: "keys/#{key.slug}/#{key.slug}.pdf",
      with_images: "keys/#{key.slug}/#{key.slug}-images.pdf"
    }
  end

  @doc """
  Returns the full CDN URLs for a key's PDFs.
  """
  @spec cdn_urls(Gallformers.Keys.Key.t()) :: %{text_only: String.t(), with_images: String.t()}
  def cdn_urls(key) do
    paths = s3_paths(key)
    cdn = Storage.cdn_url()

    %{
      text_only: "#{cdn}/#{paths.text_only}",
      with_images: "#{cdn}/#{paths.with_images}"
    }
  end

  @doc """
  Generates PDFs and uploads them to S3.

  Generates the text-only variant always. Generates the with-images
  variant only if the key has images in its couplet data.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @spec generate_and_upload(Gallformers.Keys.Key.t()) :: :ok | {:error, term()}
  def generate_and_upload(key) do
    paths = s3_paths(key)

    with {:ok, pdf_path} <- generate_pdf(key, images: false),
         pdf_data = File.read!(pdf_path),
         {:ok, _} <- Storage.upload(paths.text_only, pdf_data, "application/pdf"),
         :ok <- File.rm(pdf_path) do
      if key_has_images?(key) do
        generate_and_upload_variant(key, paths.with_images, images: true)
      else
        :ok
      end
    else
      {:error, reason} ->
        Logger.error("PDF generation/upload failed for key #{key.slug}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_and_upload_variant(key, s3_path, opts) do
    with {:ok, pdf_path} <- generate_pdf(key, opts),
         pdf_data = File.read!(pdf_path),
         {:ok, _} <- Storage.upload(s3_path, pdf_data, "application/pdf"),
         :ok <- File.rm(pdf_path) do
      :ok
    else
      {:error, reason} ->
        Logger.error("PDF variant upload failed for key #{key.slug}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc false
  def key_has_images?(key) do
    Enum.any?(key.couplets, fn {_number, couplet} ->
      Enum.any?(couplet.leads, fn lead ->
        lead.images != nil and lead.images != []
      end)
    end)
  end
end
