defmodule Gallformers.ChangesetHelpers do
  @moduledoc """
  Shared changeset validation and normalization functions.
  """
  import Ecto.Changeset

  @doc """
  Trims leading and trailing whitespace from all string field changes.

  Introspects the changeset's schema to find string fields, then trims any
  changed values. Place this in the changeset pipeline right after `cast/3`
  and before any `validate_*` calls.
  """
  def trim_strings(changeset) do
    schema = changeset.data.__struct__

    schema.__schema__(:fields)
    |> Enum.filter(fn field -> schema.__schema__(:type, field) == :string end)
    |> Enum.reduce(changeset, &maybe_trim_field/2)
  end

  defp maybe_trim_field(field, changeset) do
    case get_change(changeset, field) do
      value when is_binary(value) ->
        trimmed = String.trim(value)
        if trimmed == value, do: changeset, else: put_change(changeset, field, trimmed)

      _ ->
        changeset
    end
  end

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
