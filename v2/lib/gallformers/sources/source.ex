defmodule Gallformers.Sources.Source do
  @moduledoc """
  Ecto schema for the source table.

  Represents a scientific reference, publication, or citation.
  """
  use Ecto.Schema
  import Ecto.Changeset

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

  @license_types ~w(Public\ Domain CC\ BY All\ Rights\ Reserved)

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

  @doc """
  Creates a changeset for a source.
  """
  def changeset(source, attrs) do
    source
    |> cast(attrs, [
      :title,
      :author,
      :pubyear,
      :link,
      :citation,
      :datacomplete,
      :license,
      :licenselink
    ])
    |> validate_required([:title, :author, :pubyear, :link, :citation, :license])
    |> validate_length(:title, min: 1, max: 500)
    |> validate_format(:pubyear, ~r/^[12][0-9]{3}$/, message: "must be a valid 4-digit year")
    |> validate_license_link()
    |> unique_constraint(:title)
  end

  defp validate_license_link(changeset) do
    license = get_field(changeset, :license)
    licenselink = get_field(changeset, :licenselink)

    if license == "CC BY" && (is_nil(licenselink) || licenselink == "") do
      add_error(changeset, :licenselink, "is required when using CC BY license")
    else
      changeset
    end
  end

  @doc """
  Returns the list of valid license types.
  """
  def license_types, do: @license_types
end
