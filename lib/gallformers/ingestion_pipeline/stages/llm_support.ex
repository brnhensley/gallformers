defmodule Gallformers.IngestionPipeline.Stages.LLMSupport do
  @moduledoc false

  alias Gallformers.IngestionPipeline.LLMClient

  @spec load_prompt!(String.t(), map()) :: String.t()
  def load_prompt!(filename, replacements \\ %{})
      when is_binary(filename) and is_map(replacements) do
    filename
    |> prompt_path()
    |> File.read!()
    |> apply_replacements(replacements)
  end

  @spec llm_client(module(), module()) :: module()
  def llm_client(config_module, default \\ LLMClient)
      when is_atom(config_module) and is_atom(default) do
    :gallformers
    |> Application.get_env(config_module, [])
    |> Keyword.get(:llm_client, default)
  end

  @spec reduce_async_result(tuple(), {:ok, list()}) ::
          {:cont, {:ok, list()}} | {:halt, {:error, term()}}
  def reduce_async_result({:ok, {:ok, item}}, {:ok, acc}), do: {:cont, {:ok, [item | acc]}}
  def reduce_async_result({:ok, {:error, reason}}, _acc), do: {:halt, {:error, reason}}
  def reduce_async_result({:exit, reason}, _acc), do: {:halt, {:error, reason}}

  @spec strip_fenced_json(String.t()) :: String.t()
  def strip_fenced_json(raw_response) when is_binary(raw_response) do
    case Regex.run(~r/```(?:json)?\s*\n(.*?)(?:\n?```|\z)/s, raw_response,
           capture: :all_but_first
         ) do
      [json] -> String.trim(json)
      _ -> String.trim(raw_response)
    end
  end

  defp prompt_path(filename) do
    [:code.priv_dir(:gallformers), "prompts", filename]
    |> Path.join()
  end

  defp apply_replacements(prompt, replacements) do
    Enum.reduce(replacements, prompt, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", value)
    end)
  end
end
