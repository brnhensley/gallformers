defmodule Mix.Tasks.FormatCheck do
  @shortdoc "Runs formatter and errors if files were changed"
  @moduledoc """
  Runs `mix format` and then checks if any files were modified.

  This ensures code is formatted while alerting you if changes need to be staged.

  ## Usage

      mix format_check

  If the formatter modifies any files, this task will exit with an error
  and list the files that were changed. You should then stage these files
  before committing.
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    # Get hash of all .ex/.exs files before formatting
    before_hashes = get_file_hashes()

    # Run the formatter
    Mix.Task.run("format")

    # Get hash of all .ex/.exs files after formatting
    after_hashes = get_file_hashes()

    # Find files that changed
    changed_files =
      Map.keys(after_hashes)
      |> Enum.filter(fn file ->
        Map.get(before_hashes, file) != Map.get(after_hashes, file)
      end)
      |> Enum.sort()

    if changed_files != [] do
      Mix.shell().error("\nFormatter modified the following files:\n")

      Enum.each(changed_files, fn file ->
        Mix.shell().error("  - #{file}")
      end)

      Mix.shell().error("\nPlease stage these changes before committing.\n")
      Mix.raise("Files were modified by formatter")
    end

    Mix.shell().info("Format check passed - no changes needed")
  end

  defp get_file_hashes do
    Path.wildcard("lib/**/*.ex")
    |> Enum.concat(Path.wildcard("lib/**/*.exs"))
    |> Enum.concat(Path.wildcard("test/**/*.ex"))
    |> Enum.concat(Path.wildcard("test/**/*.exs"))
    |> Enum.map(fn path ->
      case File.read(path) do
        {:ok, content} -> {path, :erlang.md5(content)}
        _ -> {path, nil}
      end
    end)
    |> Map.new()
  end
end
