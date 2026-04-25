defmodule Gallformers.IngestionPipeline.Heuristics.StripPlatePages do
  @behaviour Gallformers.IngestionPipeline.Heuristics.TextHeuristic

  @impl true
  def name, do: :strip_plate_pages

  @doc """
  Removes OCR junk from plate pages (pages dedicated to photos/figures) from from scanned plate pages while preserving caption sections.
  """
  @impl true
  def apply(text) when is_binary(text) do
    {lines, _in_plate_image} =
      text
      |> String.split("\n", trim: false)
      |> Enum.reduce({[], false}, &reduce_plate_line/2)

    lines
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp reduce_plate_line(line, {result, in_plate_image}) do
    stripped = String.trim(line)

    apply_plate_action(line, result, plate_line_action(stripped, in_plate_image))
  end

  defp plate_image_start?(stripped), do: Regex.match?(~r/^PLATE\s+[IVXLCDM]+\.\s+/, stripped)
  defp plate_running_header?(stripped), do: Regex.match?(~r/^[A-Z]+:\s+[A-Z\s]+\./, stripped)
  defp plate_reference_line?(stripped), do: Regex.match?(~r/^PLATE\s+[IVXLCDM]+$/, stripped)

  defp plate_ocr_junk?(stripped) do
    String.length(stripped) <= 3 or Regex.match?(~r/^[|OoIl\s\W]+$/, stripped)
  end

  defp plate_content_line?(stripped), do: String.length(stripped) > 20

  defp plate_line_action(stripped, false) do
    if plate_image_start?(stripped), do: :enter_plate, else: :keep
  end

  defp plate_line_action(stripped, true) do
    cond do
      plate_running_header?(stripped) ->
        :skip_plate

      plate_ocr_junk?(stripped) ->
        :skip_plate

      plate_reference_line?(stripped) ->
        :keep_and_exit_plate

      plate_content_line?(stripped) ->
        :keep_and_exit_plate

      true ->
        :skip_plate
    end
  end

  defp apply_plate_action(_line, result, :enter_plate), do: {result, true}
  defp apply_plate_action(_line, result, :skip_plate), do: {result, true}
  defp apply_plate_action(line, result, :keep_and_exit_plate), do: {[line | result], false}
  defp apply_plate_action(line, result, :keep), do: {[line | result], false}
end
