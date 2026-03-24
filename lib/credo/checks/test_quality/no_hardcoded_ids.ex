defmodule Gallformers.Credo.Checks.TestQuality.NoHardcodedIds do
  use Credo.Check,
    base_priority: :low,
    exit_status: 0,
    category: :design,
    explanations: [
      check: """
      Tests should not use hardcoded integer IDs in `Repo.get` or `Repo.get!` calls.

      Hardcoded IDs couple tests to specific seed data, making them fragile and
      hard to understand. Tests should use IDs from fixtures they created.
      """
    ]

  alias Credo.IssueMeta

  @impl Credo.Check
  def run(%Credo.SourceFile{} = source_file, params) do
    if String.contains?(source_file.filename, "test/") do
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> Credo.Code.ast()
      |> find_hardcoded_ids(issue_meta)
    else
      []
    end
  end

  defp find_hardcoded_ids(ast, issue_meta) do
    {_, issues} = Macro.prewalk(ast, [], &traverse(&1, &2, issue_meta))
    issues
  end

  defp traverse(
         {{:., _, [{:__aliases__, _, module_parts}, func]}, meta, [_schema, id_arg]} = node,
         acc,
         issue_meta
       )
       when func in [:get, :get!] do
    if List.last(module_parts) == :Repo and is_integer(id_arg) do
      issue = issue_for(issue_meta, meta[:line], "Repo.#{func}")
      {node, [issue | acc]}
    else
      {node, acc}
    end
  end

  defp traverse(node, acc, _issue_meta), do: {node, acc}

  defp issue_for(issue_meta, line_no, trigger) do
    format_issue(
      issue_meta,
      message:
        "Hardcoded integer ID in #{trigger} — use an ID from a fixture or factory instead.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
