Code.require_file(
  Path.expand("../../../../dev/credo/checks/test_quality/tests_own_their_data.ex", __DIR__)
)

defmodule Gallformers.Credo.Checks.TestQuality.TestsOwnTheirDataTest do
  use Credo.Test.Case

  alias Gallformers.Credo.Checks.TestQuality.TestsOwnTheirData

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags test that reads but doesn't write" do
    """
    defmodule SomeTest do
      test "fetches species" do
        species = Repo.get(Species, id)
        assert species.name == "test"
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(TestsOwnTheirData)
    |> assert_issue()
  end

  test "allows test that reads and writes" do
    """
    defmodule SomeTest do
      test "creates and fetches species" do
        {:ok, species} = Repo.insert!(%Species{name: "test"})
        fetched = Repo.get(Species, species.id)
        assert fetched.name == "test"
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(TestsOwnTheirData)
    |> refute_issues()
  end

  test "allows test that uses fixtures" do
    """
    defmodule SomeTest do
      test "fetches species" do
        species = species_fixture()
        fetched = Repo.get(Species, species.id)
        assert fetched.name == "test"
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(TestsOwnTheirData)
    |> refute_issues()
  end

  test "ignores test without DB reads" do
    """
    defmodule SomeTest do
      test "does math" do
        assert 1 + 1 == 2
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(TestsOwnTheirData)
    |> refute_issues()
  end
end
