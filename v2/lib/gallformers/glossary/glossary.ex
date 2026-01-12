defmodule Gallformers.Glossary.Glossary do
  @moduledoc """
  Ecto schema for the glossary table.

  Contains definitions of terms used throughout the site.
  """
  use Ecto.Schema

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
end
