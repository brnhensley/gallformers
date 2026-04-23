Code.require_file(
  Path.expand("../../../../dev/credo/checks/architecture/no_ecto_query_in_liveview.ex", __DIR__)
)

defmodule Gallformers.Credo.Checks.Architecture.NoEctoQueryInLiveViewTest do
  use Credo.Test.Case

  alias Gallformers.Credo.Checks.Architecture.NoEctoQueryInLiveView

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags import Ecto.Query in a GallformersWeb module" do
    """
    defmodule GallformersWeb.GallLive.Index do
      import Ecto.Query

      def mount(_, _, socket) do
        {:ok, socket}
      end
    end
    """
    |> to_source_file()
    |> run_check(NoEctoQueryInLiveView)
    |> assert_issue()
  end

  test "allows import Ecto.Query in a context module" do
    """
    defmodule Gallformers.Galls do
      import Ecto.Query

      def list_galls do
        from(g in Gall) |> Repo.all()
      end
    end
    """
    |> to_source_file()
    |> run_check(NoEctoQueryInLiveView)
    |> refute_issues()
  end
end
