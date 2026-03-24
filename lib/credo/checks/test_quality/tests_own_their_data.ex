defmodule Gallformers.Credo.Checks.TestQuality.TestsOwnTheirData do
  use Credo.Check,
    base_priority: :low,
    exit_status: 0,
    category: :design,
    explanations: [
      check: """
      Tests that read from the database should also create their own data.

      Tests that rely on seed data are fragile and opaque. They should create
      their own records via `Repo.insert!`, `Repo.insert`, or fixture functions
      (any function ending in `_fixture`).
      """
    ]

  alias Credo.IssueMeta

  @impl Credo.Check
  def run(%Credo.SourceFile{} = source_file, params) do
    if String.contains?(source_file.filename, "test/") do
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> Credo.Code.ast()
      |> find_test_blocks()
      |> Enum.flat_map(&check_test_block(&1, issue_meta))
    else
      []
    end
  end

  defp find_test_blocks(ast) do
    {_, blocks} = Macro.prewalk(ast, [], &collect_test_blocks/2)
    blocks
  end

  defp collect_test_blocks({:test, meta, [_name | _]} = node, acc) do
    {node, [{node, meta} | acc]}
  end

  defp collect_test_blocks(node, acc), do: {node, acc}

  defp check_test_block({test_ast, meta}, issue_meta) do
    has_reads = has_db_reads?(test_ast)
    has_writes = has_db_writes?(test_ast)

    if has_reads and not has_writes do
      [issue_for(issue_meta, meta[:line])]
    else
      []
    end
  end

  defp has_db_reads?(ast) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        {{:., _, [{:__aliases__, _, module_parts}, func]}, _, _} = node, acc
        when func in [:get, :get!, :one, :one!, :all] ->
          if List.last(module_parts) == :Repo, do: {node, true}, else: {node, acc}

        node, acc ->
          {node, acc}
      end)

    found
  end

  defp has_db_writes?(ast) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        # Repo.insert, Repo.insert!
        {{:., _, [{:__aliases__, _, module_parts}, func]}, _, _} = node, acc
        when func in [:insert, :insert!] ->
          if List.last(module_parts) == :Repo, do: {node, true}, else: {node, acc}

        # fixture functions: anything ending in _fixture
        {func_name, _, args} = node, acc when is_atom(func_name) and is_list(args) ->
          if String.ends_with?(Atom.to_string(func_name), "_fixture") do
            {node, true}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    found
  end

  defp issue_for(issue_meta, line_no) do
    format_issue(
      issue_meta,
      message:
        "Test reads from the database but doesn't create its own data — use fixtures or Repo.insert!.",
      trigger: "Repo.get",
      line_no: line_no
    )
  end
end
