defmodule Gallformers.Ingestions do
  @moduledoc """
  The ingestion context.

  Owns persisted source-ingestion records, duplicate-review workflow, and
  gall-level review items derived from ingested sources.
  """

  use Boundary,
    deps: [
      Gallformers.Repo,
      Gallformers.ChangesetHelpers,
      Gallformers.SchemaFields,
      Gallformers.Accounts,
      Gallformers.Sources,
      Gallformers.Storage,
      Gallformers.Species,
      Gallformers.IngestionPipeline.Workflow
    ],
    exports: :all

  import Ecto.Changeset, only: [add_error: 3]
  import Ecto.Query

  alias Gallformers.IngestionPipeline.Workflow
  alias Gallformers.Ingestions.{DuplicateCandidate, SourceIngestion, SourceIngestionSpecies}
  alias Gallformers.Repo
  alias Gallformers.Sources.Source
  alias Gallformers.Storage.SourceArtifacts

  @ordered_duplicate_candidates_query from(duplicate_candidate in DuplicateCandidate,
                                        order_by: [
                                          asc: duplicate_candidate.status,
                                          asc: duplicate_candidate.inserted_at
                                        ]
                                      )

  @ordered_species_entries_query from(source_ingestion_species in SourceIngestionSpecies,
                                   order_by: source_ingestion_species.position
                                 )

  @source_ingestion_orchestration_lock_namespace 41_204

  @source_ingestion_detail_preloads [
    :source,
    :uploaded_by,
    :duplicate_of_source_ingestion,
    duplicate_candidates:
      {@ordered_duplicate_candidates_query, [:candidate_source_ingestion, :reviewed_by]},
    species_entries: {@ordered_species_entries_query, [:species, :reviewed_by]}
  ]

  @doc """
  Returns ingestions ordered newest-first.
  """
  @spec list_source_ingestions(keyword()) :: [SourceIngestion.t()]
  def list_source_ingestions(opts \\ []) do
    SourceIngestion
    |> order_by([source_ingestion], desc: source_ingestion.inserted_at)
    |> maybe_filter_status(Keyword.get(opts, :status))
    |> maybe_preload(Keyword.get(opts, :preload, false))
    |> Repo.all()
  end

  @doc """
  Gets a source ingestion by ID.
  """
  @spec get_source_ingestion(integer()) :: SourceIngestion.t() | nil
  def get_source_ingestion(id), do: Repo.get(SourceIngestion, id)

  @doc """
  Gets a source ingestion by ID, raising if it does not exist.
  """
  @spec get_source_ingestion!(integer()) :: SourceIngestion.t()
  def get_source_ingestion!(id), do: Repo.get!(SourceIngestion, id)

  @doc """
  Runs a function while holding a per-ingestion orchestration lock.
  """
  @spec with_source_ingestion_orchestration_lock(integer(), (-> result)) ::
          {:ok, result} | {:error, :already_processing}
        when result: var
  def with_source_ingestion_orchestration_lock(source_ingestion_id, fun)
      when is_integer(source_ingestion_id) and is_function(fun, 0) do
    Repo.checkout(fn ->
      if acquire_source_ingestion_orchestration_lock(source_ingestion_id) do
        try do
          {:ok, fun.()}
        after
          release_source_ingestion_orchestration_lock(source_ingestion_id)
        end
      else
        {:error, :already_processing}
      end
    end)
  end

  @doc """
  Gets a source ingestion with the detail preloads needed by review workflows.
  """
  @spec get_source_ingestion_with_details!(integer()) :: SourceIngestion.t()
  def get_source_ingestion_with_details!(id) do
    id
    |> get_source_ingestion!()
    |> Repo.preload(@source_ingestion_detail_preloads)
  end

  @doc """
  Returns a changeset for a source ingestion.
  """
  @spec change_source_ingestion(SourceIngestion.t(), map()) :: Ecto.Changeset.t()
  def change_source_ingestion(%SourceIngestion{} = source_ingestion, attrs \\ %{}) do
    SourceIngestion.changeset(source_ingestion, attrs)
  end

  @doc """
  Creates a source ingestion and assigns its canonical per-ingestion artifacts path.
  """
  @spec create_source_ingestion(map()) ::
          {:ok, SourceIngestion.t()} | {:error, Ecto.Changeset.t()}
  def create_source_ingestion(attrs \\ %{}) do
    Repo.transaction(fn ->
      attrs = Map.new(attrs)

      source_ingestion =
        %SourceIngestion{}
        |> SourceIngestion.changeset(attrs)
        |> insert_or_rollback()

      if blank_artifacts_path?(source_ingestion.artifacts_path) do
        source_ingestion
        |> SourceIngestion.changeset(%{
          artifacts_path: SourceArtifacts.private_artifact_prefix(source_ingestion.id)
        })
        |> update_or_rollback()
      else
        source_ingestion
      end
    end)
  end

  @doc """
  Transitions an ingestion to a new status.
  """
  @spec transition_source_ingestion_status(SourceIngestion.t(), String.t() | atom(), map()) ::
          {:ok, SourceIngestion.t()} | {:error, Ecto.Changeset.t()}
  def transition_source_ingestion_status(
        %SourceIngestion{} = source_ingestion,
        status,
        attrs \\ %{}
      ) do
    status = normalize_status(status)

    attrs =
      attrs
      |> Map.new()
      |> Map.put(:status, status)
      |> put_default_stage_for_status(source_ingestion)

    attrs = maybe_put_failed_at(attrs, status)

    source_ingestion
    |> SourceIngestion.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Persists a workflow event for an ingestion through the canonical workflow semantics.
  """
  @spec transition_source_ingestion_workflow(SourceIngestion.t(), Workflow.event(), map()) ::
          {:ok, SourceIngestion.t()}
          | {:error, :invalid_state | :invalid_transition | Ecto.Changeset.t()}
  def transition_source_ingestion_workflow(
        %SourceIngestion{} = source_ingestion,
        event,
        attrs \\ %{}
      ) do
    attrs = Map.new(attrs)

    with {:ok, workflow_attrs} <- Workflow.transition_attrs(source_ingestion, event) do
      status = Map.fetch!(workflow_attrs, :status)
      transition_attrs = Map.merge(attrs, Map.delete(workflow_attrs, :status))

      transition_source_ingestion_status(source_ingestion, status, transition_attrs)
    end
  end

  @doc """
  Updates the explicit duplicate signals and related normalized metadata on an ingestion.
  """
  @spec record_duplicate_signals(SourceIngestion.t(), map()) ::
          {:ok, SourceIngestion.t()} | {:error, Ecto.Changeset.t()}
  def record_duplicate_signals(%SourceIngestion{} = source_ingestion, attrs) do
    attrs = Map.new(attrs)

    allowed_attrs =
      SourceIngestion.signal_fields()
      |> Enum.reduce(%{}, fn field, acc ->
        case attr_value(attrs, field) do
          nil -> acc
          value -> Map.put(acc, field, value)
        end
      end)

    source_ingestion
    |> SourceIngestion.changeset(allowed_attrs)
    |> Repo.update()
  end

  @doc """
  Associates an ingestion with a source from the ingestion side of the boundary.
  """
  @spec associate_source(SourceIngestion.t(), Source.t() | integer()) ::
          {:ok, SourceIngestion.t()} | {:error, Ecto.Changeset.t()}
  def associate_source(%SourceIngestion{} = source_ingestion, %Source{id: source_id}) do
    associate_source(source_ingestion, source_id)
  end

  def associate_source(%SourceIngestion{} = source_ingestion, source_id)
      when is_integer(source_id) do
    source_ingestion
    |> SourceIngestion.changeset(%{source_id: source_id})
    |> Repo.update()
  end

  @doc """
  Clears the source association for an ingestion.
  """
  @spec clear_source_association(SourceIngestion.t()) ::
          {:ok, SourceIngestion.t()} | {:error, Ecto.Changeset.t()}
  def clear_source_association(%SourceIngestion{} = source_ingestion) do
    source_ingestion
    |> SourceIngestion.changeset(%{source_id: nil})
    |> Repo.update()
  end

  @doc """
  Returns whether an ingestion is currently waiting on duplicate review.
  """
  @spec duplicate_review_required?(SourceIngestion.t()) :: boolean()
  def duplicate_review_required?(%SourceIngestion{status: "needs_duplicate_review"}), do: true
  def duplicate_review_required?(_), do: false

  @doc """
  Returns whether source-level review can proceed.
  """
  @spec source_review_unlocked?(SourceIngestion.t()) :: boolean()
  def source_review_unlocked?(%SourceIngestion{status: status})
      when status in ["needs_review", "complete"] do
    true
  end

  def source_review_unlocked?(_), do: false

  @doc """
  Returns whether per-gall review can proceed.
  """
  @spec species_review_unlocked?(SourceIngestion.t()) :: boolean()
  def species_review_unlocked?(%SourceIngestion{source_id: source_id} = source_ingestion)
      when not is_nil(source_id) do
    source_review_unlocked?(source_ingestion)
  end

  def species_review_unlocked?(_), do: false

  @doc """
  Returns whether all per-gall review items are in a resolved state.
  """
  @spec all_species_entries_resolved?(SourceIngestion.t() | integer()) :: boolean()
  def all_species_entries_resolved?(%SourceIngestion{id: source_ingestion_id}) do
    all_species_entries_resolved?(source_ingestion_id)
  end

  def all_species_entries_resolved?(source_ingestion_id) when is_integer(source_ingestion_id) do
    from(source_ingestion_species in SourceIngestionSpecies,
      where:
        source_ingestion_species.source_ingestion_id == ^source_ingestion_id and
          source_ingestion_species.status == "pending"
    )
    |> Repo.exists?()
    |> Kernel.not()
  end

  @doc """
  Returns a changeset for a duplicate candidate.
  """
  @spec change_duplicate_candidate(DuplicateCandidate.t(), map()) :: Ecto.Changeset.t()
  def change_duplicate_candidate(%DuplicateCandidate{} = duplicate_candidate, attrs \\ %{}) do
    DuplicateCandidate.changeset(duplicate_candidate, attrs)
  end

  @doc """
  Lists duplicate candidates for an ingestion.
  """
  @spec list_duplicate_candidates(SourceIngestion.t() | integer()) :: [DuplicateCandidate.t()]
  def list_duplicate_candidates(%SourceIngestion{id: source_ingestion_id}) do
    list_duplicate_candidates(source_ingestion_id)
  end

  def list_duplicate_candidates(source_ingestion_id) when is_integer(source_ingestion_id) do
    @ordered_duplicate_candidates_query
    |> where(
      [duplicate_candidate],
      duplicate_candidate.source_ingestion_id == ^source_ingestion_id
    )
    |> Repo.all()
    |> Repo.preload([:reviewed_by, :candidate_source_ingestion])
  end

  @doc """
  Gets a duplicate candidate by ID, raising if it does not exist.
  """
  @spec get_duplicate_candidate!(integer()) :: DuplicateCandidate.t()
  def get_duplicate_candidate!(duplicate_candidate_id) when is_integer(duplicate_candidate_id) do
    DuplicateCandidate
    |> Repo.get!(duplicate_candidate_id)
    |> Repo.preload([:reviewed_by, :candidate_source_ingestion])
  end

  @doc """
  Creates a duplicate candidate for an ingestion pair.
  """
  @spec create_duplicate_candidate(SourceIngestion.t(), SourceIngestion.t(), map()) ::
          {:ok, DuplicateCandidate.t()} | {:error, Ecto.Changeset.t()}
  def create_duplicate_candidate(
        %SourceIngestion{id: source_ingestion_id},
        %SourceIngestion{id: candidate_source_ingestion_id},
        attrs \\ %{}
      ) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put(:source_ingestion_id, source_ingestion_id)
      |> Map.put(:candidate_source_ingestion_id, candidate_source_ingestion_id)

    create_duplicate_candidate(attrs)
  end

  def create_duplicate_candidate(attrs) do
    %DuplicateCandidate{}
    |> DuplicateCandidate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Confirms a duplicate candidate and links the subject ingestion to its canonical ingestion.
  """
  @spec confirm_duplicate_candidate(DuplicateCandidate.t(), map()) ::
          {:ok, %{candidate: DuplicateCandidate.t(), source_ingestion: SourceIngestion.t()}}
          | {:error, Ecto.Changeset.t()}
  def confirm_duplicate_candidate(%DuplicateCandidate{} = duplicate_candidate, attrs \\ %{}) do
    attrs = Map.new(attrs)

    candidate_status =
      normalize_status(attr_value(attrs, :status) || "confirmed")

    case candidate_status do
      status when status in ["confirmed", "auto_confirmed"] ->
        do_confirm_duplicate_candidate(duplicate_candidate, attrs, candidate_status)

      _ ->
        {:error,
         duplicate_candidate
         |> DuplicateCandidate.changeset(%{})
         |> add_error(:status, "must be confirmed or auto_confirmed")}
    end
  end

  @doc """
  Rejects a duplicate candidate and resumes pipeline processing if no pending
  candidates remain.
  """
  @spec reject_duplicate_candidate(DuplicateCandidate.t(), map()) ::
          {:ok, %{candidate: DuplicateCandidate.t(), source_ingestion: SourceIngestion.t()}}
          | {:error, Ecto.Changeset.t()}
  def reject_duplicate_candidate(%DuplicateCandidate{} = duplicate_candidate, attrs \\ %{}) do
    attrs = Map.new(attrs)

    Repo.transaction(fn ->
      source_ingestion =
        duplicate_candidate.source_ingestion_id
        |> lock_source_ingestion_for_duplicate_review!()
        |> ensure_duplicate_review_open!()

      duplicate_candidate =
        duplicate_candidate.id
        |> lock_duplicate_candidate!()
        |> ensure_pending_duplicate_candidate!()

      updated_candidate =
        duplicate_candidate
        |> DuplicateCandidate.changeset(%{
          status: "rejected",
          reviewed_by_id: attr_value(attrs, :reviewed_by_id),
          reviewed_at: attr_value(attrs, :reviewed_at) || now()
        })
        |> update_or_rollback()

      updated_source_ingestion =
        if no_pending_duplicate_candidates?(source_ingestion.id) do
          source_ingestion
          |> transition_source_ingestion_workflow(:duplicate_rejected_resume)
          |> update_result_or_rollback()
        else
          source_ingestion
        end

      %{
        candidate: Repo.preload(updated_candidate, [:reviewed_by, :candidate_source_ingestion]),
        source_ingestion: updated_source_ingestion
      }
    end)
  end

  @doc """
  Returns a changeset for a gall-level ingestion review item.
  """
  @spec change_source_ingestion_species(SourceIngestionSpecies.t(), map()) :: Ecto.Changeset.t()
  def change_source_ingestion_species(
        %SourceIngestionSpecies{} = source_ingestion_species,
        attrs \\ %{}
      ) do
    SourceIngestionSpecies.changeset(source_ingestion_species, attrs)
  end

  @doc """
  Lists gall-level review items for an ingestion.
  """
  @spec list_source_ingestion_species(SourceIngestion.t() | integer()) :: [
          SourceIngestionSpecies.t()
        ]
  def list_source_ingestion_species(%SourceIngestion{id: source_ingestion_id}) do
    list_source_ingestion_species(source_ingestion_id)
  end

  def list_source_ingestion_species(source_ingestion_id) when is_integer(source_ingestion_id) do
    @ordered_species_entries_query
    |> where(
      [source_ingestion_species],
      source_ingestion_species.source_ingestion_id == ^source_ingestion_id
    )
    |> Repo.all()
    |> Repo.preload([:species, :reviewed_by])
  end

  @doc """
  Creates a gall-level ingestion review item.
  """
  @spec create_source_ingestion_species(map() | Enumerable.t()) ::
          {:ok, SourceIngestionSpecies.t()} | {:error, Ecto.Changeset.t()}
  def create_source_ingestion_species(attrs) do
    attrs = Map.new(attrs)

    %SourceIngestionSpecies{}
    |> SourceIngestionSpecies.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Transitions a gall-level ingestion review item to a new status.
  """
  @spec transition_source_ingestion_species_status(
          SourceIngestionSpecies.t(),
          String.t() | atom(),
          map()
        ) :: {:ok, SourceIngestionSpecies.t()} | {:error, Ecto.Changeset.t()}
  def transition_source_ingestion_species_status(
        %SourceIngestionSpecies{} = source_ingestion_species,
        status,
        attrs \\ %{}
      ) do
    attrs = Map.new(attrs)
    status = normalize_status(status)

    attrs =
      attrs
      |> Map.put(:status, status)
      |> maybe_put_reviewed_at(attr_value(attrs, :reviewed_by_id))

    source_ingestion_species
    |> SourceIngestionSpecies.changeset(attrs)
    |> Repo.update()
  end

  defp maybe_filter_status(query, nil), do: query

  defp maybe_filter_status(query, status) when is_atom(status) do
    maybe_filter_status(query, Atom.to_string(status))
  end

  defp maybe_filter_status(query, statuses) when is_list(statuses) do
    normalized_statuses = Enum.map(statuses, &normalize_status/1)
    from(source_ingestion in query, where: source_ingestion.status in ^normalized_statuses)
  end

  defp maybe_filter_status(query, status) when is_binary(status) do
    from(source_ingestion in query, where: source_ingestion.status == ^status)
  end

  defp maybe_preload(query, true), do: preload(query, ^@source_ingestion_detail_preloads)
  defp maybe_preload(query, false), do: query

  defp put_default_stage_for_status(attrs, %SourceIngestion{processing_stage: processing_stage}) do
    case attr_value(attrs, :processing_stage) do
      nil ->
        case attr_value(attrs, :status) do
          "needs_duplicate_review" -> Map.put(attrs, :processing_stage, "duplicate_review")
          "needs_review" -> Map.put(attrs, :processing_stage, "review")
          "duplicate_confirmed" -> Map.put(attrs, :processing_stage, "duplicate_review")
          "complete" -> Map.put(attrs, :processing_stage, "complete")
          "failed" -> Map.put(attrs, :processing_stage, "failed")
          _ -> Map.put(attrs, :processing_stage, processing_stage)
        end

      _ ->
        attrs
    end
  end

  defp maybe_put_failed_at(attrs, "failed") do
    case attr_value(attrs, :failed_at) do
      nil -> Map.put(attrs, :failed_at, now())
      _ -> attrs
    end
  end

  defp maybe_put_failed_at(attrs, _status), do: attrs

  defp maybe_put_reviewed_at(attrs, nil), do: attrs

  defp maybe_put_reviewed_at(attrs, _reviewed_by_id) do
    case attr_value(attrs, :reviewed_at) do
      nil -> Map.put(attrs, :reviewed_at, now())
      _ -> attrs
    end
  end

  defp acquire_source_ingestion_orchestration_lock(source_ingestion_id) do
    %{rows: [[locked?]]} =
      Repo.query!(
        "SELECT pg_try_advisory_lock($1, $2)",
        [@source_ingestion_orchestration_lock_namespace, source_ingestion_id]
      )

    locked?
  end

  defp release_source_ingestion_orchestration_lock(source_ingestion_id) do
    Repo.query!(
      "SELECT pg_advisory_unlock($1, $2)",
      [@source_ingestion_orchestration_lock_namespace, source_ingestion_id]
    )

    :ok
  end

  defp update_result_or_rollback({:ok, result}), do: result
  defp update_result_or_rollback({:error, reason}), do: Repo.rollback(reason)

  defp no_pending_duplicate_candidates?(source_ingestion_id) do
    # Lock pending candidates to prevent race conditions with concurrent insertions.
    # We select IDs with FOR UPDATE rather than using aggregate count (which doesn't support locking).
    pending_ids =
      from(duplicate_candidate in DuplicateCandidate,
        where:
          duplicate_candidate.source_ingestion_id == ^source_ingestion_id and
            duplicate_candidate.status == "pending",
        select: duplicate_candidate.id,
        lock: "FOR UPDATE"
      )
      |> Repo.all()

    Enum.empty?(pending_ids)
  end

  defp do_confirm_duplicate_candidate(duplicate_candidate, attrs, candidate_status) do
    Repo.transaction(fn ->
      source_ingestion =
        duplicate_candidate.source_ingestion_id
        |> lock_source_ingestion_for_duplicate_review!()
        |> ensure_duplicate_review_open!()

      duplicate_candidate =
        duplicate_candidate.id
        |> lock_duplicate_candidate!()
        |> ensure_pending_duplicate_candidate!()

      canonical_source_ingestion_id =
        attrs
        |> attr_value(:canonical_source_ingestion_id)
        |> case do
          nil -> duplicate_candidate.candidate_source_ingestion_id
          source_ingestion_id -> source_ingestion_id
        end
        |> resolve_canonical_source_ingestion_id()

      ensure_not_self_duplicate!(
        duplicate_candidate,
        source_ingestion,
        canonical_source_ingestion_id
      )

      updated_candidate =
        duplicate_candidate
        |> DuplicateCandidate.changeset(%{
          status: candidate_status,
          reviewed_by_id: attr_value(attrs, :reviewed_by_id),
          reviewed_at: attr_value(attrs, :reviewed_at) || now()
        })
        |> update_or_rollback()

      updated_source_ingestion =
        source_ingestion
        |> transition_source_ingestion_workflow(:duplicate_confirmed, %{
          duplicate_of_source_ingestion_id: canonical_source_ingestion_id
        })
        |> update_result_or_rollback()

      %{
        candidate: Repo.preload(updated_candidate, [:reviewed_by, :candidate_source_ingestion]),
        source_ingestion: updated_source_ingestion
      }
    end)
  end

  defp lock_source_ingestion_for_duplicate_review!(source_ingestion_id) do
    from(source_ingestion in SourceIngestion,
      where: source_ingestion.id == ^source_ingestion_id,
      lock: "FOR UPDATE"
    )
    |> Repo.one!()
  end

  defp lock_duplicate_candidate!(duplicate_candidate_id) do
    from(duplicate_candidate in DuplicateCandidate,
      where: duplicate_candidate.id == ^duplicate_candidate_id,
      lock: "FOR UPDATE"
    )
    |> Repo.one!()
  end

  defp ensure_duplicate_review_open!(
         %SourceIngestion{status: "needs_duplicate_review"} =
           source_ingestion
       ) do
    source_ingestion
  end

  defp ensure_duplicate_review_open!(%SourceIngestion{} = source_ingestion) do
    Repo.rollback(
      source_ingestion
      |> SourceIngestion.changeset(%{})
      |> add_error(:status, "duplicate review is no longer pending")
    )
  end

  defp ensure_pending_duplicate_candidate!(
         %DuplicateCandidate{status: "pending"} =
           duplicate_candidate
       ) do
    duplicate_candidate
  end

  defp ensure_pending_duplicate_candidate!(%DuplicateCandidate{} = duplicate_candidate) do
    Repo.rollback(
      duplicate_candidate
      |> DuplicateCandidate.changeset(%{})
      |> add_error(:status, "duplicate candidate is no longer pending")
    )
  end

  defp ensure_not_self_duplicate!(
         duplicate_candidate,
         source_ingestion,
         canonical_source_ingestion_id
       ) do
    if canonical_source_ingestion_id == source_ingestion.id do
      Repo.rollback(
        duplicate_candidate
        |> DuplicateCandidate.changeset(%{})
        |> add_error(
          :candidate_source_ingestion_id,
          "cannot confirm a source ingestion as a duplicate of itself"
        )
      )
    end
  end

  defp resolve_canonical_source_ingestion_id(source_ingestion_id) do
    do_resolve_canonical_source_ingestion_id(source_ingestion_id, [])
  end

  @spec do_resolve_canonical_source_ingestion_id(integer() | nil, [integer()]) :: integer() | nil
  defp do_resolve_canonical_source_ingestion_id(source_ingestion_id, visited_ids) do
    cond do
      is_nil(source_ingestion_id) ->
        nil

      source_ingestion_id in visited_ids ->
        source_ingestion_id

      true ->
        visited_ids = [source_ingestion_id | visited_ids]

        case Repo.get(SourceIngestion, source_ingestion_id) do
          %SourceIngestion{duplicate_of_source_ingestion_id: nil} ->
            source_ingestion_id

          %SourceIngestion{duplicate_of_source_ingestion_id: canonical_source_ingestion_id} ->
            do_resolve_canonical_source_ingestion_id(canonical_source_ingestion_id, visited_ids)

          nil ->
            source_ingestion_id
        end
    end
  end

  defp attr_value(attrs, key) do
    # Look up by atom key first, then fall back to string key.
    # Explicitly checks for nil to preserve false/0/"" values.
    case Map.get(attrs, key) do
      nil -> Map.get(attrs, Atom.to_string(key))
      value -> value
    end
  end

  defp normalize_status(status) when is_atom(status), do: Atom.to_string(status)
  defp normalize_status(status) when is_binary(status), do: status

  defp blank_artifacts_path?(artifacts_path), do: artifacts_path in [nil, ""]

  defp now do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  defp insert_or_rollback(changeset) do
    case Repo.insert(changeset) do
      {:ok, record} -> record
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp update_or_rollback(changeset) do
    case Repo.update(changeset) do
      {:ok, record} -> record
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end
end
