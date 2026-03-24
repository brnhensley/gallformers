defmodule Gallformers.Credo.Checks.TestQuality.NoHardcodedIdsTest do
  use Credo.Test.Case

  alias Gallformers.Credo.Checks.TestQuality.NoHardcodedIds

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags Repo.get with hardcoded integer" do
    """
    defmodule SomeTest do
      test "fetches species" do
        species = Repo.get(Species, 1)
        assert species.name == "test"
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(NoHardcodedIds)
    |> assert_issue()
  end

  test "flags Repo.get! with hardcoded integer" do
    """
    defmodule SomeTest do
      test "fetches species" do
        species = Repo.get!(Species, 42)
        assert species.name == "test"
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(NoHardcodedIds)
    |> assert_issue()
  end

  test "allows Repo.get with variable" do
    """
    defmodule SomeTest do
      test "fetches species" do
        species = Repo.get(Species, species_id)
        assert species.name == "test"
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(NoHardcodedIds)
    |> refute_issues()
  end

  test "allows Repo.get with function result" do
    """
    defmodule SomeTest do
      test "fetches species" do
        species = Repo.get(Species, hd(ids))
        assert species.name == "test"
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(NoHardcodedIds)
    |> refute_issues()
  end
end
