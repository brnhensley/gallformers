defmodule Gallformers.Taxonomy.Intermediate do
  @moduledoc "An intermediate taxonomic rank between family and genus (e.g., Subfamily, Tribe)."

  defstruct [:id, :name, :rank, :description]

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          rank: String.t(),
          description: String.t() | nil
        }
end
