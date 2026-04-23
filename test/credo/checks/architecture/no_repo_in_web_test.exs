Code.require_file(
  Path.expand("../../../../dev/credo/checks/architecture/no_repo_in_web.ex", __DIR__)
)

defmodule Gallformers.Credo.Checks.Architecture.NoRepoInWebTest do
  use Credo.Test.Case

  alias Gallformers.Credo.Checks.Architecture.NoRepoInWeb

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags Repo.all in a GallformersWeb module" do
    """
    defmodule GallformersWeb.SomeLive do
      def handle_event(_, _, socket) do
        Repo.all(query)
      end
    end
    """
    |> to_source_file()
    |> run_check(NoRepoInWeb)
    |> assert_issue()
  end

  test "flags alias Gallformers.Repo in a GallformersWeb module" do
    """
    defmodule GallformersWeb.SomeLive do
      alias Gallformers.Repo

      def handle_event(_, _, socket) do
        :ok
      end
    end
    """
    |> to_source_file()
    |> run_check(NoRepoInWeb)
    |> assert_issue()
  end

  test "allows Repo.all in a context module" do
    """
    defmodule Gallformers.Galls do
      alias Gallformers.Repo

      def list_galls do
        Repo.all(query)
      end
    end
    """
    |> to_source_file()
    |> run_check(NoRepoInWeb)
    |> refute_issues()
  end

  test "ignores non-web modules" do
    """
    defmodule SomeOther do
      def do_stuff do
        Repo.all(query)
      end
    end
    """
    |> to_source_file()
    |> run_check(NoRepoInWeb)
    |> refute_issues()
  end
end
