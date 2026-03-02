defmodule GallformersWeb.TaxonomyURL do
  @moduledoc """
  Centralized URL builder for public taxonomy pages.

  Every place that builds a URL for a taxonomy record (family, genus,
  section, intermediate) should call through this module. This ensures
  the URL scheme is defined in one place and is changeable in one place.
  """

  @doc """
  Returns the public URL path for a taxonomy record, or nil if the
  record doesn't map to a public page.

  Accepts any map/struct with `:type` and `:name` fields (and `:rank`
  for intermediates).

  ## Examples

      iex> TaxonomyURL.public_path(%{type: "family", name: "Cynipidae"})
      "/family/Cynipidae"

      iex> TaxonomyURL.public_path(%{type: "intermediate", rank: "Subfamily", name: "Cynipinae"})
      "/subfamily/Cynipinae"
  """
  @spec public_path(map()) :: String.t() | nil
  def public_path(%{type: "family", name: name}), do: "/family/#{name}"
  def public_path(%{type: "genus", name: name}), do: "/genus/#{name}"
  def public_path(%{type: "section", name: name}), do: "/section/#{name}"

  def public_path(%{type: "intermediate", rank: rank, name: name})
      when rank not in [nil, ""],
      do: "/#{String.downcase(rank)}/#{name}"

  def public_path(_), do: nil

  @doc """
  Returns true if the string looks like a numeric ID (digits only).
  Used by taxonomy LiveViews to detect old ID-based URLs and redirect.
  """
  @spec numeric?(String.t()) :: boolean()
  def numeric?(s), do: Regex.match?(~r/^\d+$/, s)
end
