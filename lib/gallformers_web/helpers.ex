defmodule GallformersWeb.Helpers do
  @moduledoc """
  View helper functions for the Gallformers application.

  These helpers are automatically imported into all views and LiveViews
  via `GallformersWeb.html_helpers/0`.
  """

  @doc """
  Formats an integer with thousand separators (commas).

  ## Examples

      iex> format_number(1234)
      "1,234"

      iex> format_number(1234567)
      "1,234,567"

      iex> format_number(42)
      "42"
  """
  def format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  def format_number(num), do: to_string(num)

  @doc """
  Returns true if the given string is a valid HTTP(S) URL safe for use in `<.link href={}>`.

  Returns false for nil, empty strings, and strings without a valid http/https scheme,
  preventing Phoenix `<.link>` from crashing on malformed URLs.
  """
  def valid_url?(nil), do: false
  def valid_url?(""), do: false

  def valid_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        true

      _ ->
        false
    end
  end

  def valid_url?(_), do: false
end
