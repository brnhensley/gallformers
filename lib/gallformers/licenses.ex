defmodule Gallformers.Licenses do
  @moduledoc """
  Shared license types for sources and images.

  Provides a consistent set of Creative Commons and other license options
  used throughout the application.
  """
  use Boundary, deps: [], exports: :all

  # License definitions with canonical URLs (nil for licenses without standard URLs)
  @license_data %{
    "Public Domain / CC0" => "https://creativecommons.org/publicdomain/zero/1.0/",
    "CC-BY" => "https://creativecommons.org/licenses/by/4.0/",
    "CC-BY-SA" => "https://creativecommons.org/licenses/by-sa/4.0/",
    "CC-BY-NC" => "https://creativecommons.org/licenses/by-nc/4.0/",
    "CC-BY-NC-SA" => "https://creativecommons.org/licenses/by-nc-sa/4.0/",
    "CC-BY-ND" => "https://creativecommons.org/licenses/by-nd/4.0/",
    "CC-BY-NC-ND" => "https://creativecommons.org/licenses/by-nc-nd/4.0/",
    "All Rights Reserved" => nil
  }

  # Ordered list of licenses for display
  @licenses [
    "Public Domain / CC0",
    "CC-BY",
    "CC-BY-SA",
    "CC-BY-NC",
    "CC-BY-NC-SA",
    "CC-BY-ND",
    "CC-BY-NC-ND",
    "All Rights Reserved"
  ]

  @doc """
  Returns the list of valid license types.

  ## License Descriptions

  - `Public Domain / CC0` - No rights reserved, free to use without attribution
  - `CC-BY` - Attribution required
  - `CC-BY-SA` - Attribution required, share-alike (derivatives must use same license)
  - `CC-BY-NC` - Attribution required, non-commercial use only
  - `CC-BY-NC-SA` - Attribution required, non-commercial, share-alike
  - `CC-BY-ND` - Attribution required, no derivatives allowed
  - `CC-BY-NC-ND` - Attribution required, non-commercial, no derivatives
  - `All Rights Reserved` - Traditional copyright, permission required for any use
  """
  @spec all() :: [String.t()]
  def all, do: @licenses

  @doc """
  Returns license options formatted for use in HTML select elements.

  Each option is a tuple of `{display_label, value}`.
  """
  @spec options() :: [{String.t(), String.t()}]
  def options do
    Enum.map(@licenses, fn license -> {license, license} end)
  end

  @doc """
  Checks if a given string is a valid license type.
  """
  @spec valid?(String.t() | nil) :: boolean()
  def valid?(nil), do: false
  def valid?(license), do: license in @licenses

  @doc """
  Returns the canonical URL for a license, or nil if no standard URL exists.

  ## Examples

      iex> Gallformers.Licenses.url("CC-BY")
      "https://creativecommons.org/licenses/by/4.0/"

      iex> Gallformers.Licenses.url("All Rights Reserved")
      nil
  """
  @spec url(String.t() | nil) :: String.t() | nil
  def url(nil), do: nil
  def url(license), do: Map.get(@license_data, license)

  @doc """
  Returns true if the license has a canonical URL that should be auto-filled.
  """
  @spec has_canonical_url?(String.t() | nil) :: boolean()
  def has_canonical_url?(nil), do: false
  def has_canonical_url?(license), do: url(license) != nil

  @doc """
  Returns true if the license URL should be read-only (not user-editable).

  Most CC licenses have fixed URLs, but Public Domain / CC0 allows editing
  since public domain works may reference different sources.
  """
  @spec url_readonly?(String.t() | nil) :: boolean()
  def url_readonly?(nil), do: false
  def url_readonly?("Public Domain / CC0"), do: false
  def url_readonly?("All Rights Reserved"), do: false
  def url_readonly?(license), do: has_canonical_url?(license)

  @doc """
  Returns a map of all licenses to their canonical URLs.
  Useful for JavaScript to look up URLs client-side.
  """
  @spec url_map() :: %{String.t() => String.t() | nil}
  def url_map, do: @license_data
end
