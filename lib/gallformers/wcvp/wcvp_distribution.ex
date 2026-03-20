defmodule Gallformers.Wcvp.WcvpDistribution do
  @moduledoc """
  Ecto schema for the `wcvp_distributions` table in the WCVP database.

  Read-only reference data from the World Checklist of Vascular Plants (Kew Gardens).
  All 11 columns are text fields matching the Kew CSV format.
  """

  use Ecto.Schema

  @primary_key {:plant_locality_id, :string, autogenerate: false}

  schema "wcvp_distributions" do
    field :plant_name_id, :string
    field :continent_code_l1, :string
    field :continent, :string
    field :region_code_l2, :string
    field :region, :string
    field :area_code_l3, :string
    field :area, :string
    field :introduced, :string
    field :extinct, :string
    field :location_doubtful, :string
  end
end
