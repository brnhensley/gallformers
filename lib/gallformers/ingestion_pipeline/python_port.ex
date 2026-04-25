defmodule Gallformers.IngestionPipeline.PythonPort do
  @moduledoc """
  Runs the narrow Python PDF extraction script through an Erlang Port.
  """

  use Boundary, deps: [], exports: :all

  @default_timeout_ms 120_000

  @type extraction_result :: %{
          text: String.t(),
          page_count: non_neg_integer(),
          metadata: map()
        }

  @doc """
  Extracts text from a PDF through the Python port.
  """
  @spec extract_text(Path.t(), keyword()) ::
          {:ok, extraction_result()}
          | {:error, :extraction_failed, term()}
          | {:error, :invalid_response, binary()}
  def extract_text(file_path, opts \\ []) when is_binary(file_path) and is_list(opts) do
    with {:ok, uv_executable} <- find_uv_executable(),
         {:ok, port} <- open_port(uv_executable),
         :ok <- send_request(port, file_path, opts) do
      collect_response(port, "", timeout_ms())
    end
  end

  @doc """
  Returns the canonical Python working directory under the app's priv dir.
  """
  @spec priv_python_dir() :: String.t()
  def priv_python_dir do
    :gallformers
    |> :code.priv_dir()
    |> Path.join("python")
    |> to_string()
  end

  defp open_port(uv_executable) do
    port =
      Port.open(
        {:spawn_executable, uv_executable},
        [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          args: ["run", "extraction_port.py"],
          cd: priv_python_dir()
        ]
      )

    {:ok, port}
  rescue
    error ->
      {:error, :extraction_failed, Exception.message(error)}
  end

  defp send_request(port, file_path, opts) do
    payload = %{
      file_path: file_path,
      ocr_fallback: Keyword.get(opts, :ocr_fallback, false)
    }

    request = "#{Jason.encode!(payload)}\n"

    try do
      true = Port.command(port, request)
      :ok
    rescue
      error ->
        close_port(port)
        {:error, :extraction_failed, Exception.message(error)}
    catch
      kind, reason ->
        close_port(port)
        {:error, :extraction_failed, {kind, reason}}
    end
  end

  defp collect_response(port, buffer, timeout_ms) do
    receive do
      {^port, {:data, data}} ->
        collect_response(port, buffer <> data, timeout_ms)

      {^port, {:exit_status, 0}} ->
        decode_response(buffer)

      {^port, {:exit_status, exit_status}} ->
        {:error, :extraction_failed, %{exit_status: exit_status, output: buffer}}
    after
      timeout_ms ->
        Port.close(port)
        {:error, :extraction_failed, :timeout}
    end
  end

  defp close_port(port) when is_port(port) do
    Port.close(port)
    :ok
  end

  defp decode_response(raw_output) do
    case Jason.decode(raw_output) do
      {:ok, %{"error" => nil} = response} ->
        {:ok,
         %{
           text: Map.get(response, "text", ""),
           page_count: Map.get(response, "page_count", 0),
           metadata: Map.get(response, "metadata", %{})
         }}

      {:ok, %{"error" => error}} ->
        {:error, :extraction_failed, %{exit_status: 1, output: raw_output, error: error}}

      {:ok, _response} ->
        {:error, :invalid_response, raw_output}

      {:error, _reason} ->
        {:error, :invalid_response, raw_output}
    end
  end

  defp find_uv_executable do
    case config()[:uv_executable] || System.find_executable("uv") do
      nil -> {:error, :extraction_failed, "uv executable not found"}
      executable -> {:ok, executable}
    end
  end

  defp timeout_ms, do: config()[:timeout_ms] || @default_timeout_ms

  defp config, do: Application.get_env(:gallformers, __MODULE__, [])
end
