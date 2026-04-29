defmodule Gallformers.Utilities do
  @doc """
  Tests to see if a string is all uppercase.
  """
  @spec all_caps?(String.t()) :: boolean
  def all_caps?(line) do
    upcased = String.upcase(line)
    downcased = String.downcase(line)
    line == upcased and line != downcased
  end
end
