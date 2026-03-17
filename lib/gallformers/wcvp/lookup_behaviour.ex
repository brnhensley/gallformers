defmodule Gallformers.Wcvp.LookupBehaviour do
  @moduledoc """
  Behaviour for WCVP lookup functions.

  Allows swapping the real Postgres-backed implementation for a test stub.
  """

  alias Gallformers.Wcvp.WcvpName

  @callback available?() :: boolean()
  @callback built_at() :: DateTime.t() | nil
  @callback search(String.t(), keyword()) :: [WcvpName.t()]
  @callback search_contains(String.t(), keyword()) :: [WcvpName.t()]
  @callback match_by_name(String.t(), keyword()) :: WcvpName.t() | nil
  @callback get(String.t()) :: WcvpName.t() | nil
  @callback get_accepted_name(String.t()) :: WcvpName.t() | nil
end
