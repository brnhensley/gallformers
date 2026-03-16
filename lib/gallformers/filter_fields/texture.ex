defmodule Gallformers.FilterFields.Texture do
  @moduledoc """
  Ecto schema for the texture table.

  Textures that describe the surface of galls (e.g., "hairy", "smooth").
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Gallformers.ChangesetHelpers, only: [trim_strings: 1]

  @type t :: %__MODULE__{
          id: integer() | nil,
          texture: String.t() | nil,
          description: String.t() | nil
        }

  schema "texture" do
    field :texture, :string
    field :description, :string
  end

  @doc false
  def changeset(texture, attrs) do
    texture
    |> cast(attrs, [:texture, :description])
    |> trim_strings()
    |> validate_required([:texture])
    |> unique_constraint(:texture)
  end
end
