defmodule Gallformers.Wcvp.LookupBehaviour do
  @moduledoc """
  Behaviour for WCVP lookup functions.

  Allows swapping the real SQLite-backed implementation for a test stub.
  """

  @callback available?() :: boolean()
  @callback built_at() :: DateTime.t() | nil
  @callback search(String.t(), keyword()) :: [map()]
  @callback search_contains(String.t(), keyword()) :: [map()]
  @callback match_by_name(String.t(), keyword()) :: map() | nil
  @callback get(String.t()) :: map() | nil
end
