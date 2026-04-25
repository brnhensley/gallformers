defmodule Gallformers.IngestionPipeline.DuplicateDetection do
  @moduledoc """
  Duplicate-detection ladder for source ingestions.
  """

  use Boundary,
    deps: [
      Gallformers.Ingestions,
      Gallformers.Repo,
      Gallformers.MinHash,
      Gallformers.IngestionPipeline.Workflow
    ],
    exports: :all

  import Ecto.Query

  alias Gallformers.IngestionPipeline.Workflow
  alias Gallformers.Ingestions.SourceIngestion
  alias Gallformers.MinHash
  alias Gallformers.Repo
  @minhash_fallback_limit 200

  @type evidence :: map()
  @type probable_match :: %{
          candidate: SourceIngestion.t(),
          evidence: evidence(),
          priority: integer()
        }

  @doc """
  Loads candidate ingestions that share an indexed duplicate signal.
  """
  @spec fetch_candidates(SourceIngestion.t()) :: [SourceIngestion.t()]
  def fetch_candidates(%SourceIngestion{} = ingestion) do
    signal_candidates = fetch_signal_candidates(ingestion)
    minhash_candidates = fetch_minhash_fallback_candidates(ingestion)

    (signal_candidates ++ minhash_candidates)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(&candidate_sort_key/1)
  end

  @doc """
  Runs the duplicate-detection ladder and returns the highest-confidence result.
  """
  @spec run_ladder(SourceIngestion.t(), [SourceIngestion.t()]) ::
          {:exact_duplicate, SourceIngestion.t()}
          | {:probable_duplicate, SourceIngestion.t(), evidence()}
          | :no_match
  def run_ladder(%SourceIngestion{} = ingestion, candidates) when is_list(candidates) do
    with nil <- exact_raw_input_match(ingestion, candidates),
         nil <- exact_preprocessed_match(ingestion, candidates),
         nil <- exact_doi_match(ingestion, candidates),
         [] <- probable_matches(ingestion, candidates) do
      :no_match
    else
      %SourceIngestion{} = candidate ->
        {:exact_duplicate, candidate}

      [%{candidate: candidate, evidence: evidence} | _] ->
        {:probable_duplicate, candidate, evidence}
    end
  end

  @doc """
  Returns all probable duplicate matches ordered by confidence.
  """
  @spec probable_matches(SourceIngestion.t(), [SourceIngestion.t()]) :: [probable_match()]
  def probable_matches(%SourceIngestion{} = ingestion, candidates) when is_list(candidates) do
    candidates
    |> Enum.reduce([], fn candidate, matches ->
      case probable_match(ingestion, candidate) do
        nil -> matches
        match -> [match | matches]
      end
    end)
    |> Enum.sort_by(fn match ->
      {match.priority, match.candidate.inserted_at, match.candidate.id}
    end)
  end

  defp exact_raw_input_match(%SourceIngestion{raw_input_sha256: nil}, _candidates), do: nil

  defp exact_raw_input_match(%SourceIngestion{raw_input_sha256: raw_hash}, candidates) do
    Enum.find(candidates, &(&1.raw_input_sha256 == raw_hash))
  end

  defp exact_preprocessed_match(%SourceIngestion{preprocessed_text_sha256: nil}, _candidates),
    do: nil

  defp exact_preprocessed_match(
         %SourceIngestion{preprocessed_text_sha256: hash} = ingestion,
         candidates
       ) do
    Enum.find(candidates, fn candidate ->
      candidate.preprocessed_text_sha256 == hash and
        non_conflicting_metadata?(ingestion, candidate)
    end)
  end

  defp exact_doi_match(%SourceIngestion{normalized_doi: nil}, _candidates), do: nil

  defp exact_doi_match(%SourceIngestion{normalized_doi: normalized_doi}, candidates) do
    Enum.find(candidates, &(&1.normalized_doi == normalized_doi))
  end

  defp non_conflicting_metadata?(left, right) do
    same_or_missing?(left.normalized_doi, right.normalized_doi) and
      same_or_missing?(left.publication_year, right.publication_year)
  end

  defp same_or_missing?(nil, _), do: true
  defp same_or_missing?(_, nil), do: true
  defp same_or_missing?(left, right), do: left == right

  defp probable_match(ingestion, candidate) do
    strong_bibliographic_match(ingestion, candidate) ||
      minhash_match(ingestion, candidate)
  end

  defp strong_bibliographic_match(
         %SourceIngestion{title_fingerprint: title_fingerprint} = ingestion,
         %SourceIngestion{title_fingerprint: candidate_title_fingerprint} = candidate
       )
       when is_binary(title_fingerprint) and title_fingerprint != "" and
              is_binary(candidate_title_fingerprint) and candidate_title_fingerprint != "" do
    author_match? = author_fingerprint_match?(ingestion, candidate)
    year_match? = publication_year_match?(ingestion, candidate)

    if title_fingerprint_match?(title_fingerprint, candidate_title_fingerprint) and
         (author_match? or year_match?) do
      %{
        candidate: candidate,
        priority: 1,
        evidence: %{
          match_type: "strong_bibliographic",
          title_fingerprint: true,
          author_fingerprint: author_match?,
          publication_year: year_match?
        }
      }
    end
  end

  defp strong_bibliographic_match(_ingestion, _candidate), do: nil

  defp minhash_match(
         %SourceIngestion{minhash_signature: signature},
         %SourceIngestion{minhash_signature: candidate_signature} = candidate
       )
       when is_list(signature) and signature != [] and is_list(candidate_signature) and
              candidate_signature != [] do
    similarity = MinHash.similarity(signature, candidate_signature)

    cond do
      similarity >= 0.9 ->
        %{
          candidate: candidate,
          priority: 2,
          evidence: %{match_type: "minhash_high", similarity: similarity}
        }

      similarity >= 0.7 ->
        %{
          candidate: candidate,
          priority: 3,
          evidence: %{match_type: "minhash_moderate", similarity: similarity}
        }

      true ->
        nil
    end
  end

  defp minhash_match(_ingestion, _candidate), do: nil

  defp nil_if_blank(nil), do: nil
  defp nil_if_blank(""), do: nil
  defp nil_if_blank(value), do: value

  defp fetch_signal_candidates(%SourceIngestion{} = ingestion) do
    case candidate_signal_clauses(ingestion) do
      [] ->
        []

      clauses ->
        signal_filter =
          Enum.reduce(clauses, dynamic(false), fn clause, dynamic_query ->
            dynamic([source_ingestion], ^dynamic_query or ^clause)
          end)

        ingestion
        |> candidate_scope()
        |> where(^signal_filter)
        |> order_by([source_ingestion],
          asc: source_ingestion.inserted_at,
          asc: source_ingestion.id
        )
        |> Repo.all()
    end
  end

  # Until we add an LSH/banding index, keep MinHash reachability via a capped
  # recent-candidates query rather than dropping fuzzy-only duplicates entirely.
  defp fetch_minhash_fallback_candidates(
         %SourceIngestion{minhash_signature: signature} = ingestion
       )
       when is_list(signature) and signature != [] do
    ingestion
    |> candidate_scope()
    |> where(
      [source_ingestion],
      fragment("coalesce(array_length(?, 1), 0) > 0", source_ingestion.minhash_signature)
    )
    |> order_by([source_ingestion],
      desc: source_ingestion.inserted_at,
      desc: source_ingestion.id
    )
    |> limit(^@minhash_fallback_limit)
    |> Repo.all()
  end

  defp fetch_minhash_fallback_candidates(_ingestion), do: []

  defp candidate_scope(%SourceIngestion{id: ingestion_id}) do
    SourceIngestion
    |> where(
      [source_ingestion],
      source_ingestion.id != ^ingestion_id and
        source_ingestion.status not in ^Workflow.duplicate_detection_excluded_statuses()
    )
  end

  defp candidate_sort_key(%SourceIngestion{id: id, inserted_at: inserted_at}) do
    {DateTime.to_unix(inserted_at, :microsecond), id}
  end

  defp candidate_signal_clauses(%SourceIngestion{} = ingestion) do
    []
    |> maybe_add_signal_clause(:raw_input_sha256, ingestion.raw_input_sha256)
    |> maybe_add_signal_clause(:preprocessed_text_sha256, ingestion.preprocessed_text_sha256)
    |> maybe_add_signal_clause(:normalized_doi, ingestion.normalized_doi)
    |> maybe_add_signal_clause(:normalized_title, ingestion.normalized_title)
    |> maybe_add_signal_clause(:title_fingerprint, ingestion.title_fingerprint)
    |> Enum.reverse()
  end

  defp maybe_add_signal_clause(clauses, _field, value) when value in [nil, ""], do: clauses

  defp maybe_add_signal_clause(clauses, field_name, value) do
    [dynamic([source_ingestion], field(source_ingestion, ^field_name) == ^value) | clauses]
  end

  defp title_fingerprint_match?(left, right), do: left == right

  defp author_fingerprint_match?(ingestion, candidate) do
    left = nil_if_blank(ingestion.author_fingerprint)
    right = nil_if_blank(candidate.author_fingerprint)

    same_or_missing?(left, right) and not is_nil(left) and not is_nil(right)
  end

  defp publication_year_match?(ingestion, candidate) do
    not is_nil(ingestion.publication_year) and
      ingestion.publication_year == candidate.publication_year
  end
end
