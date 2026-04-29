defmodule Gallformers.IngestionPipeline.Heuristics.TextHeuristic do
  @moduledoc """
  A behavior for text heuristic preprocessing.
  """

  @doc """
  Applies text heuristic preprocessing to the given text.
  """
  @callback apply(String.t()) :: String.t()

  @doc """
  Returns the name of the text heuristic preprocessor for ordering and composition.
  """
  @callback name() :: atom()
end
