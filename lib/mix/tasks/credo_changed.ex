defmodule Mix.Tasks.Credo.Changed do
  @moduledoc """
  Runs Credo only on files changed since the last commit.

  Falls back to full Credo if git is unavailable or no files changed.

  ## Usage

      mix credo.changed --strict
  """
  use Mix.Task
  use Boundary, check: [in: false, out: false]

  @shortdoc "Run Credo on changed files only"

  @impl Mix.Task
  def run(args) do
    case changed_files() do
      {:ok, []} ->
        Mix.shell().info("No changed Elixir files — skipping Credo.")

      {:ok, files} ->
        Mix.shell().info("Running Credo on #{length(files)} changed file(s)...")
        Mix.Task.run("credo", args ++ files)

      :error ->
        Mix.shell().info("Could not detect changed files — running full Credo.")
        Mix.Task.run("credo", args)
    end
  end

  defp changed_files do
    # Staged + unstaged changes relative to HEAD
    case System.cmd("git", ["diff", "--name-only", "HEAD"], stderr_to_stdout: true) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.filter(&(String.ends_with?(&1, ".ex") || String.ends_with?(&1, ".exs")))

        {:ok, files}

      _ ->
        :error
    end
  end
end
