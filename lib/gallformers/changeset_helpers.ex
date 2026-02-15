defmodule Gallformers.ChangesetHelpers do
  @moduledoc """
  Shared changeset validation and normalization functions.
  """
  import Ecto.Changeset

  @doc """
  Validates and normalizes a URL field.

  Normalization (applied before validation):
  - Trims whitespace
  - Prepends `https://` if the value starts with `www.`

  Validation (applied to non-empty values):
  - Must have an `http` or `https` scheme
  - Must have a non-empty host
  """
  def validate_url(changeset, field) do
    changeset
    |> normalize_url(field)
    |> validate_change(field, &check_url_format/2)
  end

  defp check_url_format(field, value) do
    value = String.trim(value)

    if value == "" do
      []
    else
      case URI.parse(value) do
        %URI{scheme: scheme, host: host}
        when scheme in ["http", "https"] and is_binary(host) and host != "" ->
          []

        _ ->
          [{field, "must be a valid URL starting with http:// or https://"}]
      end
    end
  end

  defp normalize_url(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      value when is_binary(value) ->
        trimmed = String.trim(value)

        normalized =
          if String.starts_with?(trimmed, "www.") do
            "https://" <> trimmed
          else
            trimmed
          end

        put_change(changeset, field, normalized)

      _ ->
        changeset
    end
  end
end
