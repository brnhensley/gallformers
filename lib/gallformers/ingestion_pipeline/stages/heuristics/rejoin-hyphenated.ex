defmodule Gallformers.IngestionPipeline.Heuristics.RejoinHyphenated do
  @behaviour Gallformers.IngestionPipeline.Heuristics.TextHeuristic

  @impl true
  def name, do: :rejoin_hyphenated

  @doc """
  Rejoins words hyphenated across line breaks.
  """
  @impl true
  def apply(text) when is_binary(text) do
    Regex.replace(~r/(\w)-\s*\n+\s*([a-z])/, text, "\\1\\2")
  end
end
