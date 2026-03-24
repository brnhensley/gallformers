defmodule Gallformers.Credo.Checks.Architecture.NoTransactionOutsideContextTest do
  use Credo.Test.Case

  alias Gallformers.Credo.Checks.Architecture.NoTransactionOutsideContext

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags Repo.transaction in a LiveView module" do
    """
    defmodule GallformersWeb.GallLive.Form do
      def save(socket) do
        Repo.transaction(fn ->
          :ok
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(NoTransactionOutsideContext)
    |> assert_issue()
  end

  test "allows Repo.transaction in a context module" do
    """
    defmodule Gallformers.Galls do
      alias Gallformers.Repo

      def create_gall(params) do
        Repo.transaction(fn ->
          :ok
        end)
      end
    end
    """
    |> to_source_file()
    |> run_check(NoTransactionOutsideContext)
    |> refute_issues()
  end
end
