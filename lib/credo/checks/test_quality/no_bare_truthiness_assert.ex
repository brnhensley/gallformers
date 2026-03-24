defmodule Gallformers.Credo.Checks.TestQuality.NoBareTruthinessAssert do
  use Credo.Check,
    base_priority: :low,
    exit_status: 0,
    category: :design,
    explanations: [
      check: """
      Bare `assert variable` only checks truthiness, not actual behavior.

      Use specific assertions like `assert result == :ok`, `assert {:ok, _} = result`,
      or `assert html =~ "text"` to verify the expected value.
      """
    ]

  alias Credo.IssueMeta

  @impl Credo.Check
  def run(%Credo.SourceFile{} = source_file, params) do
    if String.contains?(source_file.filename, "test/") do
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> Credo.Code.ast()
      |> find_bare_asserts(issue_meta)
    else
      []
    end
  end

  defp find_bare_asserts(ast, issue_meta) do
    {_, issues} = Macro.prewalk(ast, [], &traverse(&1, &2, issue_meta))
    issues
  end

  # assert with a bare variable: assert result
  defp traverse(
         {:assert, meta, [{var_name, _, context}]} = node,
         acc,
         issue_meta
       )
       when is_atom(var_name) and is_atom(context) and var_name != true and
              var_name != false do
    issue = issue_for(issue_meta, meta[:line], Atom.to_string(var_name))
    {node, [issue | acc]}
  end

  # assert with field access: assert socket.assigns.valid
  defp traverse(
         {:assert, meta, [{{:., _, _}, _, _}]} = node,
         acc,
         issue_meta
       ) do
    issue = issue_for(issue_meta, meta[:line], "field access")
    {node, [issue | acc]}
  end

  defp traverse(node, acc, _issue_meta), do: {node, acc}

  defp issue_for(issue_meta, line_no, trigger) do
    format_issue(
      issue_meta,
      message:
        "Bare `assert #{trigger}` only checks truthiness — use a specific comparison or pattern match.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
