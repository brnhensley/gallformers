defmodule Gallformers.Hosts do
  @moduledoc """
  Facade for backward compatibility.

  This module delegates to the new decomposed contexts:
  - `Gallformers.Species.Plants` - Plant species queries/CRUD
  - `Gallformers.GallHosts` - Gall↔Host relationships
  - `Gallformers.Ranges` - Geographic range operations

  New code should use those contexts directly.
  """

  alias Gallformers.GallHosts
  alias Gallformers.Ranges
  alias Gallformers.Species.Plants

  # ============================================
  # Species.Plants delegates (plant queries/CRUD)
  # ============================================

  defdelegate list_hosts(), to: Plants
  defdelegate list_hosts_paginated(limit, offset), to: Plants
  defdelegate count_hosts(), to: Plants
  defdelegate get_host(id), to: Plants
  defdelegate get_host_by_name(name), to: Plants
  defdelegate get_host_species(id), to: Plants
  defdelegate search_hosts(query, limit \\ 20), to: Plants
  defdelegate get_aliases_for_host(host_id), to: Plants
  defdelegate get_aliases_for_host_full(host_id), to: Plants
  defdelegate get_host_for_edit(id), to: Plants
  defdelegate subscribe(), to: Plants
  defdelegate broadcast_change(host, event), to: Plants
  defdelegate change_host(host, attrs \\ %{}), to: Plants
  defdelegate create_host(attrs), to: Plants
  defdelegate update_host(host, attrs), to: Plants
  defdelegate delete_host(host_id), to: Plants
  defdelegate create_alias_for_host(host_id, alias_attrs), to: Plants
  defdelegate remove_alias_from_host(host_id, alias_id), to: Plants
  defdelegate rename_host(host_id, new_name, add_alias? \\ false), to: Plants

  defdelegate rename_host_with_new_genus(
                host_id,
                new_name,
                new_genus_name,
                family_id,
                add_alias?
              ),
              to: Plants

  # ============================================
  # GallHosts delegates (gall↔host relationships)
  # ============================================

  defdelegate get_hosts_for_gall(gall_species_id), to: GallHosts
  defdelegate get_hosts_for_galls(gall_species_ids), to: GallHosts
  defdelegate get_galls_for_host(host_species_id), to: GallHosts
  defdelegate get_gall_counts_for_hosts(host_species_ids), to: GallHosts
  defdelegate get_host_counts_for_galls(gall_species_ids), to: GallHosts

  # ============================================
  # Ranges delegates (geographic range operations)
  # ============================================

  defdelegate get_hosts_for_place(place_id), to: Ranges
  defdelegate get_places_for_host(host_species_id), to: Ranges
  defdelegate get_places_for_gall(gall_species_id), to: Ranges
  defdelegate get_places_for_galls(gall_species_ids), to: Ranges
  defdelegate get_places_for_host_species_ids(host_species_ids), to: Ranges
  defdelegate get_excluded_places_for_gall(gall_species_id), to: Ranges
  defdelegate get_place_ids_for_host(host_species_id), to: Ranges
  defdelegate add_place_to_host(host_species_id, place_id), to: Ranges
  defdelegate remove_place_from_host(host_species_id, place_id), to: Ranges
  defdelegate toggle_place_for_host(host_species_id, place_id), to: Ranges
  defdelegate update_host_places(host_species_id, place_ids), to: Ranges
  defdelegate get_excluded_place_ids_for_gall(gall_species_id), to: Ranges
  defdelegate set_range_exclusions_for_gall(gall_species_id, place_ids), to: Ranges
  defdelegate toggle_exclusion_for_gall(gall_species_id, place_id), to: Ranges
  defdelegate get_host_place_ids_for_gall(gall_species_id), to: Ranges
  defdelegate get_place_id_by_code(code), to: Ranges
end
