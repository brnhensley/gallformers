defmodule Gallformers.IngestionPipeline.TextProcessing do
  @moduledoc """
  Deterministic text cleanup and cheap bibliographic sniffing for ingestions.
  """

  @doi_regex ~r/10\.\d{4,}\/[^\s]+/i
  @year_regex ~r/\b(18|19|20)\d{2}\b/
  @author_last_first_regex ~r/\b[A-Z][a-z]+,[ ]+(?:[A-Z]\.[ ]*){1,3}/
  @author_initials_last_regex ~r/\b(?:[A-Z]\.[ ]*){1,3}[ ]+[A-Z][a-z]+\b/

  @doc """
  Runs the full preprocessing pipeline in the Python PoC order.
  """
  @spec preprocess(String.t()) :: String.t()
  def preprocess(text) when is_binary(text) do
    text
    |> strip_bhl_boilerplate()
    |> strip_plate_pages()
    |> strip_page_headers()
    |> rejoin_hyphenated()
    |> rejoin_lines()
    |> String.trim()
  end

  @doc """
  Removes BHL boilerplate from the start of a document when present.
  """
  @spec strip_bhl_boilerplate(String.t()) :: String.t()
  def strip_bhl_boilerplate(text) when is_binary(text) do
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

  @doc """
  Rejoins OCR/PDF line breaks while preserving headings and real paragraphs.
  """
  @spec rejoin_lines(String.t()) :: String.t()
  def rejoin_lines(text) when is_binary(text) do
    text
    |> String.split(~r/\n{2,}/, trim: false)
    |> do_rejoin_lines([])
    |> Enum.reverse()
    |> Enum.join("\n\n")
  end

  @doc """
  Rejoins words hyphenated across line breaks.
  """
  @spec rejoin_hyphenated(String.t()) :: String.t()
  def rejoin_hyphenated(text) when is_binary(text) do
    Regex.replace(~r/(\w)-\s*\n+\s*([a-z])/, text, "\\1\\2")
  end

  @doc """
  Removes common page headers, footers, and standalone page numbers.
  """
  @spec strip_page_headers(String.t()) :: String.t()
  def strip_page_headers(text) when is_binary(text) do
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

  @doc """
  Removes OCR junk from scanned plate pages while preserving caption sections.
  """
  @spec strip_plate_pages(String.t()) :: String.t()
  def strip_plate_pages(text) when is_binary(text) do
    {lines, _in_plate_image} =
      text
      |> String.split("\n", trim: false)
      |> Enum.reduce({[], false}, &reduce_plate_line/2)

    lines
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  @doc """
  Extracts inexpensive bibliographic hints from the preprocessed text.
  """
  @spec cheap_sniff(String.t()) :: %{
          doi: String.t() | nil,
          title: String.t() | nil,
          authors: [String.t()],
          year: integer() | nil
        }
  def cheap_sniff(text) when is_binary(text) do
    doi =
      text
      |> String.slice(0, 2000)
      |> then(&Regex.run(@doi_regex, &1))
      |> case do
        [match | _] -> normalize_sniffed_doi(match)
        _ -> nil
      end

    start_text = String.slice(text, 0, 1000)

    year =
      case Regex.run(@year_regex, start_text) do
        [match | _] -> String.to_integer(match)
        _ -> nil
      end

    title =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.find(fn line ->
        String.length(line) >= 20 and
          not all_caps?(line) and
          not Regex.match?(~r/^\d+$/, line) and
          not Regex.match?(@doi_regex, line)
      end)

    authors =
      (Regex.scan(@author_last_first_regex, start_text) ++
         Regex.scan(@author_initials_last_regex, start_text))
      |> List.flatten()
      |> Enum.map(&String.trim/1)
      |> Enum.uniq()

    %{doi: doi, title: title, authors: authors, year: year}
  end

  @doc """
  Computes the lowercase SHA-256 hex digest for the given text.
  """
  @spec compute_sha256(String.t()) :: String.t()
  def compute_sha256(text) when is_binary(text) do
    :sha256
    |> :crypto.hash(text)
    |> Base.encode16(case: :lower)
  end

  defp do_rejoin_lines([], acc), do: acc

  defp do_rejoin_lines([block | rest], acc) do
    block = String.trim(block)

    cond do
      block == "" ->
        do_rejoin_lines(rest, acc)

      heading_or_special?(block) ->
        do_rejoin_lines(rest, [block | acc])

      true ->
        {parts, remaining} = collect_continuations([block], rest)

        joined =
          parts
          |> Enum.join(" ")
          |> then(&Regex.replace(~r/(?<!\n)\n(?!\n)/u, &1, " "))

        do_rejoin_lines(remaining, [joined | acc])
    end
  end

  defp collect_continuations(parts, []), do: {parts, []}

  defp collect_continuations(parts, [next_block | rest]) do
    next_block = String.trim(next_block)

    cond do
      next_block == "" ->
        collect_continuations(parts, rest)

      continuation?(List.last(parts), next_block) ->
        collect_continuations(parts ++ [next_block], rest)

      true ->
        {parts, [next_block | rest]}
    end
  end

  defp heading_or_special?(line) do
    stripped = String.trim(line)

    String.starts_with?(stripped, "#") or
      (all_caps?(stripped) and String.length(stripped) < 100) or
      Regex.match?(~r/^\d+$/, stripped)
  end

  defp continuation?(prev, current) do
    prev = String.trim_trailing(prev)
    current = String.trim_leading(current)

    if prev == "" or current == "" do
      false
    else
      prev_last = String.at(prev, -1)
      current_first = String.at(current, 0)

      prev_ends_mid = prev_last not in [".", "!", "?", ":", ";", "\""]

      current_continues =
        String.match?(current_first, ~r/^[[:lower:]]$/u) or
          current_first in [",", "(", ";", "—", "–", "-"]

      prev_ends_soft =
        prev_last in [",", ";", ":"] or
          Enum.any?(
            [" or", " and", " the", " of", " a", " an", " in", " to", " by"],
            &String.ends_with?(prev, &1)
          )

      (prev_ends_mid and current_continues) or prev_ends_soft
    end
  end

  defp all_caps?(line) do
    upcased = String.upcase(line)
    downcased = String.downcase(line)
    line == upcased and line != downcased
  end

  defp normalize_sniffed_doi(doi) do
    doi
    |> String.downcase()
    |> String.trim()
    |> String.trim_trailing(".")
    |> String.trim_trailing(",")
    |> String.trim_trailing(";")
    |> String.trim_trailing(":")
    |> String.trim_trailing(")")
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
