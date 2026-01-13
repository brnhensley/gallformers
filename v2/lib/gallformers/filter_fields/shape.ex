defmodule Gallformers.FilterFields.Shape do
  @moduledoc """
  Ecto schema for the shape table.

  Shapes that describe gall morphology (e.g., "spherical", "conical").
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          shape: String.t() | nil,
          description: String.t() | nil
        }

  schema "shape" do
    field :shape, :string
    field :description, :string

    many_to_many :galls, Gallformers.Species.Gall,
      join_through: "gallshape",
      join_keys: [shape_id: :id, gall_id: :id]
  end

  @doc false
  def changeset(shape, attrs) do
    shape
    |> cast(attrs, [:shape, :description])
    |> validate_required([:shape])
    |> unique_constraint(:shape)
  end
end
