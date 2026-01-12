defmodule Gallformers.Species do
  @moduledoc """
  The Species context.

  Provides functions for working with species, including galls and hosts.
  """

  import Ecto.Query
  alias Gallformers.Repo
  alias Gallformers.Species.{Gall, GallSpecies, Image, Species}

  @doc """
  Returns a random gall that has a default image.

  Used on the home page to show a featured gall. Returns a map with:
    - id: species ID
    - name: species name
    - undescribed: whether the gall is undescribed
    - image_url: full CloudFront URL
    - image_creator: photographer credit
    - image_license: license name

  Returns `nil` if no galls with images are found.

  ## Examples

      iex> random_gall()
      %{
        id: 123,
        name: "Andricus quercuscalifornicus",
        undescribed: false,
        image_url: "https://dhz6u1p7t6okk.cloudfront.net/path/to/image.jpg",
        image_creator: "John Doe",
        image_license: "CC BY-NC"
      }

  """
  @spec random_gall() :: map() | nil
  def random_gall do
    query =
      from g in Gall,
        join: gs in GallSpecies,
        on: gs.gall_id == g.id,
        join: s in Species,
        on: gs.species_id == s.id,
        join: i in Image,
        on: i.species_id == s.id,
        where: i.default == true,
        order_by: fragment("RANDOM()"),
        limit: 1,
        select: %{
          id: s.id,
          name: s.name,
          undescribed: g.undescribed,
          image_path: i.path,
          image_creator: i.creator,
          image_license: i.license
        }

    case Repo.one(query) do
      nil ->
        nil

      result ->
        Map.put(result, :image_url, Image.base_url() <> "/" <> result.image_path)
    end
  end
end
