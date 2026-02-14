defmodule Gallformers.INaturalist.Photo do
  @moduledoc """
  Represents a photo from an iNaturalist observation.
  """

  @enforce_keys [:id, :thumbnail_url, :original_url, :mapped_license]
  defstruct [
    :id,
    :thumbnail_url,
    :original_url,
    :license_code,
    :mapped_license,
    :all_rights_reserved?
  ]

  @type t :: %__MODULE__{
          id: integer(),
          thumbnail_url: String.t(),
          original_url: String.t(),
          license_code: String.t() | nil,
          mapped_license: String.t(),
          all_rights_reserved?: boolean()
        }
end
