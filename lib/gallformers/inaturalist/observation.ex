defmodule Gallformers.INaturalist.Observation do
  @moduledoc """
  Represents a parsed iNaturalist observation with its photos.
  """

  alias Gallformers.INaturalist.Photo

  @enforce_keys [:id, :observer_login, :url, :photos]
  defstruct [:id, :taxon_name, :observer_login, :observer_name, :url, photos: []]

  @type t :: %__MODULE__{
          id: integer(),
          taxon_name: String.t() | nil,
          observer_login: String.t(),
          observer_name: String.t() | nil,
          url: String.t(),
          photos: [Photo.t()]
        }
end
