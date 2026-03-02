defmodule Gallformers.Images.Attribution do
  @moduledoc """
  Attribution validation for images.

  Shared logic used by both species images (`Gallformers.Images`) and
  content images (`Gallformers.ContentImages`). Accepts any map or struct
  with the standard attribution fields.
  """

  alias Gallformers.Licenses

  @attribution_fields [:creator, :license, :licenselink, :sourcelink, :attribution, :caption]

  @doc """
  Returns the list of attribution field names that can be copied between images.
  """
  @spec attribution_fields() :: [atom()]
  def attribution_fields, do: @attribution_fields

  @doc """
  Checks if a license requires attribution (creator must be specified).

  Public Domain / CC0 does not require attribution.
  All other valid licenses require attribution.
  """
  @spec requires_attribution?(String.t() | nil) :: boolean()
  def requires_attribution?(nil), do: false
  def requires_attribution?("Public Domain / CC0"), do: false
  def requires_attribution?(license), do: Licenses.valid?(license)

  @doc """
  Checks if an image is properly attributed.

  Accepts any map or struct with the fields: `source_id`, `source`, `license`,
  and `creator`. Works with `%Image{}`, `%ContentImage{}`, or plain maps.

  An image is attributed if:
  1. It has a source with a license, OR
  2. It has a license + creator (when attribution is required), OR
  3. Its license is Public Domain / CC0 (no attribution required)
  """
  @spec image_attributed?(map()) :: boolean()
  def image_attributed?(image) do
    source = Map.get(image, :source)
    license = Map.get(image, :license)
    creator = Map.get(image, :creator)
    source_id = Map.get(image, :source_id)

    cond do
      # Has source with license - attributed via source
      source_id != nil && source != nil && Map.get(source, :license) != nil ->
        true

      # Public domain - no attribution needed
      license == "Public Domain / CC0" ->
        true

      # Has license that requires attribution - need creator
      requires_attribution?(license) ->
        has_value?(creator)

      # No license at all - not attributed
      !has_value?(license) ->
        false

      # Fallback - has license, doesn't require attribution
      true ->
        true
    end
  end

  defp has_value?(nil), do: false
  defp has_value?(""), do: false
  defp has_value?(val) when is_binary(val), do: String.trim(val) != ""
  defp has_value?(_), do: false
end
