Code.require_file(
  Path.expand("../../../../dev/credo/checks/test_quality/flash_only_assertions.ex", __DIR__)
)

defmodule Gallformers.Credo.Checks.TestQuality.FlashOnlyAssertionsTest do
  use Credo.Test.Case

  alias Gallformers.Credo.Checks.TestQuality.FlashOnlyAssertions

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags test with render_submit but no DB verification" do
    """
    defmodule SomeTest do
      test "creates a species" do
        {:ok, view, _html} = live(conn, "/admin/species/new")

        html =
          view
          |> form("#species-form", species: @valid_attrs)
          |> render_submit()

        assert html =~ "Species created successfully"
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(FlashOnlyAssertions)
    |> assert_issue()
  end

  test "allows test with render_submit and Repo.get" do
    """
    defmodule SomeTest do
      test "creates a species" do
        {:ok, view, _html} = live(conn, "/admin/species/new")

        html =
          view
          |> form("#species-form", species: @valid_attrs)
          |> render_submit()

        assert html =~ "Species created successfully"
        assert Repo.get(Species, 1)
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(FlashOnlyAssertions)
    |> refute_issues()
  end

  test "ignores test without render_submit" do
    """
    defmodule SomeTest do
      test "lists species" do
        {:ok, _view, html} = live(conn, "/species")
        assert html =~ "Species"
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(FlashOnlyAssertions)
    |> refute_issues()
  end
end
