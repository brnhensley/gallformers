defmodule Gallformers.FilterFields.Shape do
  @moduledoc """
  Ecto schema for the shape table.

  Shapes that describe gall morphology (e.g., "spherical", "conical").
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Gallformers.ChangesetHelpers, only: [trim_strings: 1]

  @type t :: %__MODULE__{
          id: integer() | nil,
          shape: String.t() | nil,
          description: String.t() | nil
        }

  schema "shape" do
    field :shape, :string
    field :description, :string
  end

  @doc false
  def changeset(shape, attrs) do
    shape
    |> cast(attrs, [:shape, :description])
    |> trim_strings()
    |> validate_required([:shape])
    |> unique_constraint(:shape)
  end
end
