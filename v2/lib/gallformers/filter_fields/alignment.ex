defmodule Gallformers.FilterFields.Alignment do
  @moduledoc """
  Ecto schema for the alignment table.

  Alignment describes how galls are oriented on the host (e.g., "erect", "integral").
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          alignment: String.t() | nil,
          description: String.t() | nil
        }

  schema "alignment" do
    field :alignment, :string
    field :description, :string

    many_to_many :galls, Gallformers.Species.Gall,
      join_through: "gallalignment",
      join_keys: [alignment_id: :id, gall_id: :id]
  end
end
