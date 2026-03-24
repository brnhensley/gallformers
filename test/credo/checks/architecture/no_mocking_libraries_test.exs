defmodule Gallformers.Credo.Checks.Architecture.NoMockingLibrariesTest do
  use Credo.Test.Case

  alias Gallformers.Credo.Checks.Architecture.NoMockingLibraries

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags use Mox" do
    """
    defmodule MyTest do
      use Mox
    end
    """
    |> to_source_file()
    |> run_check(NoMockingLibraries)
    |> assert_issue()
  end

  test "flags import Mox" do
    """
    defmodule MyTest do
      import Mox
    end
    """
    |> to_source_file()
    |> run_check(NoMockingLibraries)
    |> assert_issue()
  end

  test "flags use Mock" do
    """
    defmodule MyTest do
      use Mock
    end
    """
    |> to_source_file()
    |> run_check(NoMockingLibraries)
    |> assert_issue()
  end

  test "flags :meck.new call" do
    """
    defmodule MyTest do
      def setup do
        :meck.new(MyModule)
      end
    end
    """
    |> to_source_file()
    |> run_check(NoMockingLibraries)
    |> assert_issue()
  end

  test "allows use Gallformers.DataCase" do
    """
    defmodule MyTest do
      use Gallformers.DataCase
    end
    """
    |> to_source_file()
    |> run_check(NoMockingLibraries)
    |> refute_issues()
  end

  test "allows normal module usage" do
    """
    defmodule MyModule do
      use GenServer
      import Ecto.Query

      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts)
      end
    end
    """
    |> to_source_file()
    |> run_check(NoMockingLibraries)
    |> refute_issues()
  end
end
