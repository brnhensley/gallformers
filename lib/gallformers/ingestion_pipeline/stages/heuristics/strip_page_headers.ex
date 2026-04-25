defmodule Gallformers.IngestionPipeline.Heuristics.StripPageHeaders do
  @behaviour Gallformers.IngestionPipeline.Heuristics.TextHeuristic

  @impl true
  def name, do: :strip_page_headers

  @doc """
  Removes common page headers, footers, and standalone page numbers.
  """
  @impl true
  def apply(text) when is_binary(text) do
    text
    |> then(
      &Regex.replace(
        ~r/\n+\d{3,4}\s+Philippine Journal of Science\s*\n+\d{4}\s*\n*/u,
        &1,
        "\n\n"
      )
    )
    |> then(
      &Regex.replace(
        ~r/\n+\d{3,4}\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+\s+\d{4}\s*\n*/u,
        &1,
        "\n\n"
      )
    )
    |> then(
      &Regex.replace(
        ~r/\n+[A-Z]+:\s+[A-Z\s]+\.\s*\]\s*\[?[A-Z\s.,]+\d+[.,]\s*(?:No\.\s*\d+\.?)?\s*\n*/u,
        &1,
        "\n\n"
      )
    )
    |> then(&Regex.replace(~r/\n+(\d{3,4})\s*\n+/u, &1, "\n\n"))
    |> then(&Regex.replace(~r/\n{3,}/u, &1, "\n\n"))
  end
end
