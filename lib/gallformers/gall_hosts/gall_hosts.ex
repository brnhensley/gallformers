defmodule Gallformers.GallHosts do
  @moduledoc """
  The GallHosts context.

  Manages the many-to-many relationship between gall species and their host plants.
  A gall forms on one or more host plant species; a host plant may have multiple
  gall species that form on it.

  Both galls and hosts are Species records (differentiated by taxoncode), and
  the `gallhost` table is the join table linking them.
  """

  import Ecto.Query

  alias Gallformers.GallHosts.GallHost
  alias Gallformers.Repo
  alias Gallformers.Species.{GallTraits, Species}

  @doc """
  Gets all hosts for a gall species.

  Returns a list of maps with host_relation_id, host_species_id, and host_name.
  """
  @spec get_hosts_for_gall(integer()) :: [map()]
  def get_hosts_for_gall(gall_species_id) do
    from(h in GallHost,
      join: s in Species,
      on: h.host_species_id == s.id,
      where: h.gall_species_id == ^gall_species_id,
      select: %{
        host_relation_id: h.id,
        host_species_id: s.id,
        host_name: s.name
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets hosts for multiple gall species in a single query (batch version).

  Returns a map of gall_species_id => [%{host_species_id, host_name}].
  """
  @spec get_hosts_for_galls([integer()]) :: %{integer() => [map()]}
  def get_hosts_for_galls([]), do: %{}

  def get_hosts_for_galls(gall_species_ids) do
    from(h in GallHost,
      join: s in Species,
      on: h.host_species_id == s.id,
      where: h.gall_species_id in ^gall_species_ids,
      select: %{
        gall_species_id: h.gall_species_id,
        host_species_id: s.id,
        host_name: s.name
      }
    )
    |> Repo.all()
    |> Enum.group_by(& &1.gall_species_id, fn row ->
      %{host_species_id: row.host_species_id, host_name: row.host_name}
    end)
  end

  @doc """
  Gets all galls for a host species.

  Returns a list of maps with gall info.
  """
  @spec get_galls_for_host(integer()) :: [map()]
  def get_galls_for_host(host_species_id) do
    from(h in GallHost,
      join: s in Species,
      on: h.gall_species_id == s.id,
      left_join: gt in GallTraits,
      on: gt.species_id == s.id,
      where: h.host_species_id == ^host_species_id,
      select: %{
        id: s.id,
        name: s.name,
        undescribed: gt.undescribed,
        datacomplete: s.datacomplete
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets galls for multiple host species in a single query (batch version).

  Returns a map of host_species_id => count of galls.
  This is optimized for counting - returns counts rather than full gall records.
  """
  @spec get_gall_counts_for_hosts([integer()]) :: %{integer() => integer()}
  def get_gall_counts_for_hosts([]), do: %{}

  def get_gall_counts_for_hosts(host_species_ids) do
    from(h in GallHost,
      where: h.host_species_id in ^host_species_ids,
      group_by: h.host_species_id,
      select: {h.host_species_id, count(h.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Gets host counts for multiple gall species in a single query (batch version).

  Returns a map of gall_species_id => count of hosts.
  """
  @spec get_host_counts_for_galls([integer()]) :: %{integer() => integer()}
  def get_host_counts_for_galls([]), do: %{}

  def get_host_counts_for_galls(gall_species_ids) do
    from(h in GallHost,
      where: h.gall_species_id in ^gall_species_ids,
      group_by: h.gall_species_id,
      select: {h.gall_species_id, count(h.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Gets the host species IDs for a gall.

  Simpler version of get_hosts_for_gall when you only need IDs.
  """
  @spec get_host_species_ids_for_gall(integer()) :: [integer()]
  def get_host_species_ids_for_gall(gall_species_id) do
    from(h in GallHost,
      where: h.gall_species_id == ^gall_species_id,
      select: h.host_species_id
    )
    |> Repo.all()
  end

  @doc """
  Creates a gall-host relationship.
  """
  @spec create_gall_host(map()) :: {:ok, GallHost.t()} | {:error, Ecto.Changeset.t()}
  def create_gall_host(attrs) do
    %GallHost{}
    |> GallHost.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a gall-host relationship by ID.
  """
  @spec delete_gall_host(integer()) :: {:ok, GallHost.t()} | {:error, :not_found}
  def delete_gall_host(id) do
    case Repo.get(GallHost, id) do
      nil -> {:error, :not_found}
      gall_host -> Repo.delete(gall_host)
    end
  end

  @doc """
  Gets a gall-host relationship by ID.
  """
  @spec get_gall_host(integer()) :: GallHost.t() | nil
  def get_gall_host(id), do: Repo.get(GallHost, id)
end
