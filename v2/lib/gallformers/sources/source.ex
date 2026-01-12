defmodule Gallformers.Sources.Source do
  @moduledoc """
  Ecto schema for the source table.

  Represents a scientific reference, publication, or citation.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t() | nil,
          author: String.t() | nil,
          pubyear: String.t() | nil,
          link: String.t() | nil,
          citation: String.t() | nil,
          datacomplete: boolean(),
          license: String.t() | nil,
          licenselink: String.t() | nil
        }

  schema "source" do
    field :title, :string
    field :author, :string
    field :pubyear, :string
    field :link, :string
    field :citation, :string
    field :datacomplete, :boolean, default: false
    field :license, :string
    field :licenselink, :string

    has_many :images, Gallformers.Species.Image
    has_many :species_sources, Gallformers.Species.SpeciesSource
  end
end
