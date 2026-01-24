defmodule Gallformers.Glossaries.Glossary do
  @moduledoc """
  Ecto schema for the glossary table.

  Contains definitions of terms used throughout the site.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @behaviour Gallformers.SchemaFields

  @required_fields [:word, :definition, :urls]

  @type t :: %__MODULE__{
          id: integer() | nil,
          word: String.t() | nil,
          definition: String.t() | nil,
          urls: String.t() | nil
        }

  schema "glossary" do
    field :word, :string
    field :definition, :string
    field :urls, :string
  end

  @impl Gallformers.SchemaFields
  def required_fields, do: @required_fields

  @doc """
  Creates a changeset for a glossary entry.
  """
  def changeset(glossary, attrs) do
    glossary
    |> cast(attrs, [:word, :definition, :urls])
    |> validate_required(@required_fields)
    |> validate_length(:word, min: 1, max: 100)
    |> validate_length(:definition, min: 1)
    |> unique_constraint(:word)
  end
end
