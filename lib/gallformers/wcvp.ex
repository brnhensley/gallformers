defmodule Gallformers.Wcvp do
  @moduledoc """
  WCVP (World Checklist of Vascular Plants) integration.

  External reference data for plant taxonomy. Operates against a separate
  Postgres database (`wcvp`) on the same cluster.
  """
  use Boundary, deps: [Gallformers.Repo, Gallformers.Places], exports: :all
end
