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
end
