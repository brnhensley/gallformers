defmodule Gallformers.Credo.Checks.TestQuality.NoBareTruthinessAssertTest do
  use Credo.Test.Case

  alias Gallformers.Credo.Checks.TestQuality.NoBareTruthinessAssert

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags assert with bare variable" do
    """
    defmodule SomeTest do
      test "checks result" do
        result = do_something()
        assert result
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(NoBareTruthinessAssert)
    |> assert_issue()
  end

  test "flags assert with field access" do
    """
    defmodule SomeTest do
      test "checks socket" do
        assert socket.assigns.valid
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(NoBareTruthinessAssert)
    |> assert_issue()
  end

  test "allows assert with comparison" do
    """
    defmodule SomeTest do
      test "checks result" do
        result = do_something()
        assert result == :ok
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(NoBareTruthinessAssert)
    |> refute_issues()
  end

  test "allows assert with pattern match" do
    """
    defmodule SomeTest do
      test "checks result" do
        result = do_something()
        assert {:ok, _} = result
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(NoBareTruthinessAssert)
    |> refute_issues()
  end

  test "allows assert with =~" do
    """
    defmodule SomeTest do
      test "checks html" do
        assert html =~ "success"
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(NoBareTruthinessAssert)
    |> refute_issues()
  end

  test "allows assert_raise" do
    """
    defmodule SomeTest do
      test "raises error" do
        assert_raise RuntimeError, fn -> raise "boom" end
      end
    end
    """
    |> to_source_file("test/some_test.exs")
    |> run_check(NoBareTruthinessAssert)
    |> refute_issues()
  end
end
