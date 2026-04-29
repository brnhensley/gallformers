defmodule Gallformers.IngestionPipeline.Stages.Extract.PythonExtractor do
  @moduledoc """
  Runs the Python-backed PDF text extractor in an external process.
  """

  use Boundary, deps: [], exports: :all

  @default_timeout_ms 120_000
  @script_name "pdf_text_extractor.py"
  @vendor_dir_name "vendor"

  @type extraction_result :: %{
          text: String.t(),
          page_count: non_neg_integer(),
          metadata: map()
        }

  @type runner :: %{
          executable: String.t(),
          args: [String.t()],
          env: [{charlist(), charlist()}]
        }

  @doc """
  Extracts text from a PDF through the Python-backed extractor.
  """
  @spec extract_text(Path.t(), keyword()) ::
          {:ok, extraction_result()}
          | {:error, :extraction_failed, term()}
          | {:error, :invalid_response, binary()}
  def extract_text(file_path, opts \\ []) when is_binary(file_path) and is_list(opts) do
    with {:ok, runner} <- find_runner(),
         {:ok, port} <- open_port(runner),
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

  defp find_runner do
    case config()[:python_executable] do
      executable when is_binary(executable) ->
        {:ok, python_runner(executable, config()[:python_path])}

      _ ->
        case {system_python_executable(), vendored_python_path()} do
          {executable, python_path} when is_binary(executable) and is_binary(python_path) ->
            {:ok, python_runner(executable, python_path)}

          _ ->
            find_uv_runner()
        end
    end
  end

  defp python_runner(executable, nil) do
    %{executable: executable, args: [@script_name], env: []}
  end

  defp python_runner(executable, python_path) do
    %{
      executable: executable,
      args: [@script_name],
      env: [{~c"PYTHONPATH", to_charlist(python_path)}]
    }
  end

  defp find_uv_runner do
    case config()[:uv_executable] || System.find_executable("uv") do
      nil -> {:error, :extraction_failed, "python extractor runner not found"}
      executable -> {:ok, %{executable: executable, args: ["run", @script_name], env: []}}
    end
  end

  defp vendored_python_path do
    path = Path.join(priv_python_dir(), @vendor_dir_name)

    if File.dir?(path), do: path, else: nil
  end

  defp system_python_executable do
    System.find_executable("python3") || System.find_executable("python")
  end

  defp open_port(%{executable: executable, args: args, env: env}) do
    options =
      [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: args,
        cd: priv_python_dir()
      ]
      |> maybe_put_env(env)

    port = Port.open({:spawn_executable, executable}, options)

    {:ok, port}
  rescue
    error ->
      {:error, :extraction_failed, Exception.message(error)}
  end

  defp maybe_put_env(options, []), do: options
  defp maybe_put_env(options, env), do: Keyword.put(options, :env, env)

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

  defp timeout_ms, do: config()[:timeout_ms] || @default_timeout_ms

  defp config, do: Application.get_env(:gallformers, __MODULE__, [])
end
