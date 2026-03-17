defmodule Gallformers.Wcvp.WcvpName do
  @moduledoc """
  Ecto schema for the `wcvp_names` table in the WCVP database.

  Read-only reference data from the World Checklist of Vascular Plants (Kew Gardens).
  All 31 columns are text fields matching the Kew CSV format. Two virtual fields
  hold distribution data populated by `Wcvp.Lookup.get/1`.
  """

  use Ecto.Schema

  @primary_key {:plant_name_id, :string, autogenerate: false}

  schema "wcvp_names" do
    field :ipni_id, :string
    field :taxon_rank, :string
    field :taxon_status, :string
    field :family, :string
    field :genus_hybrid, :string
    field :genus, :string
    field :species_hybrid, :string
    field :species, :string
    field :infraspecific_rank, :string
    field :infraspecies, :string
    field :parenthetical_author, :string
    field :primary_author, :string
    field :publication_author, :string
    field :place_of_publication, :string
    field :volume_and_page, :string
    field :first_published, :string
    field :nomenclatural_remarks, :string
    field :geographic_area, :string
    field :lifeform_description, :string
    field :climate_description, :string
    field :taxon_name, :string
    field :taxon_authors, :string
    field :accepted_plant_name_id, :string
    field :basionym_plant_name_id, :string
    field :replaced_synonym_author, :string
    field :homotypic_synonym, :string
    field :parent_plant_name_id, :string
    field :powo_id, :string
    field :hybrid_formula, :string
    field :reviewed, :string

    field :native_distribution, {:array, :string}, virtual: true, default: []
    field :introduced_distribution, {:array, :string}, virtual: true, default: []
  end
end
