defmodule Gallformers.IngestionPipeline.Heuristics.StripBHLBoilerplate do
  @behaviour Gallformers.IngestionPipeline.Heuristics.TextHeuristic

  @impl true
  def name, do: :strip_bhl_boilerplate

  @doc """
  Removes BHL boilerplate from the start of a document when present.
  """
  @impl true
  def apply(text) when is_binary(text) do
    if bhl_document?(text) do
      case bhl_cut_point(text) do
        0 ->
          text

        cut_point ->
          text
          |> binary_part(cut_point, byte_size(text) - cut_point)
          |> String.trim_leading("\n")
      end
    else
      text
    end
  end

  defp bhl_document?(text) do
    String.contains?(String.slice(text, 0, 500), "biodiversitylibrary.org")
  end

  defp bhl_cut_point(text) do
    find_marker_cut_point(text) || find_generated_cut_point(text) || 0
  end

  defp find_marker_cut_point(text) do
    Enum.find_value(
      [
        "This page intentionally left blank.",
        "This page intentionally left blank"
      ],
      fn marker ->
        case :binary.match(text, marker) do
          {index, _length} -> index + String.length(marker)
          :nomatch -> nil
        end
      end
    )
  end

  defp find_generated_cut_point(text) do
    case Regex.run(~r/Generated .+(?:PM|AM)\b.*?\n/, text, return: :index, capture: :first) do
      [{start, match_length}] -> start + match_length
      _ -> nil
    end
  end
end
