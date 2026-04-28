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

  @repo_read_funcs [:get, :get!, :one, :one!, :all]
  @repo_write_funcs [
    :insert,
    :insert!,
    :insert_all,
    :update,
    :update!,
    :delete,
    :delete!,
    :delete_all
  ]
  @mutating_prefixes [
    "add_",
    "create_",
    "delete_",
    "find_or_create_",
    "insert_",
    "link_",
    "move_",
    "place_",
    "prune_",
    "reassign_",
    "save_",
    "toggle_",
    "update_"
  ]

  @impl Credo.Check
  def run(%Credo.SourceFile{} = source_file, params) do
    if String.contains?(source_file.filename, "test/") do
      issue_meta = IssueMeta.for(source_file, params)
      {:ok, ast} = Credo.Code.ast(source_file)
      analysis = analyze(ast)

      Enum.flat_map(analysis.tests, &check_test_block(&1, issue_meta, analysis))
    else
      []
    end
  end

  defp analyze(ast) do
    {_ast, acc} =
      Macro.traverse(
        ast,
        %{describe_path: [], function_defs: [], setups: [], tests: []},
        &collect_blocks_pre/2,
        &collect_blocks_post/2
      )

    %{
      tests: Enum.reverse(acc.tests),
      setups: Enum.reverse(acc.setups),
      local_write_functions: local_write_functions(acc.function_defs)
    }
  end

  defp collect_blocks_pre({:describe, meta, [_name | _]} = node, acc) do
    {node, %{acc | describe_path: [meta[:line] | acc.describe_path]}}
  end

  defp collect_blocks_pre({kind, meta, [_name | _]} = node, acc)
       when kind in [:test, :setup, :setup_all] do
    path = Enum.reverse(acc.describe_path)
    block = %{ast: node, line: meta[:line], path: path}

    updated_acc =
      case kind do
        :test -> %{acc | tests: [block | acc.tests]}
        _ -> %{acc | setups: [block | acc.setups]}
      end

    {node, updated_acc}
  end

  defp collect_blocks_pre({kind, _meta, [{name, _, args_ast}, _body]} = node, acc)
       when kind in [:def, :defp] and is_atom(name) do
    arity = length(args_ast || [])
    function_def = %{ast: node, key: {name, arity}}

    {node, %{acc | function_defs: [function_def | acc.function_defs]}}
  end

  defp collect_blocks_pre(node, acc), do: {node, acc}

  defp collect_blocks_post({:describe, _meta, [_name | _]} = node, acc) do
    {node, %{acc | describe_path: tl(acc.describe_path)}}
  end

  defp collect_blocks_post(node, acc), do: {node, acc}

  defp local_write_functions(function_defs) do
    seed =
      function_defs
      |> Enum.filter(&has_db_writes?(&1.ast, MapSet.new()))
      |> Enum.map(& &1.key)
      |> MapSet.new()

    grow_local_write_functions(function_defs, seed)
  end

  defp grow_local_write_functions(function_defs, known_writers) do
    expanded =
      Enum.reduce(function_defs, known_writers, fn function_def, acc ->
        if has_db_writes?(function_def.ast, acc) do
          MapSet.put(acc, function_def.key)
        else
          acc
        end
      end)

    if MapSet.equal?(expanded, known_writers) do
      known_writers
    else
      grow_local_write_functions(function_defs, expanded)
    end
  end

  defp check_test_block(test_block, issue_meta, analysis) do
    has_reads = has_db_reads?(test_block.ast)

    has_writes =
      has_db_writes?(test_block.ast, analysis.local_write_functions) or
        enclosing_setup_writes?(test_block, analysis)

    if has_reads and not has_writes do
      [issue_for(issue_meta, test_block.line)]
    else
      []
    end
  end

  defp enclosing_setup_writes?(test_block, analysis) do
    Enum.any?(analysis.setups, fn setup_block ->
      path_prefix?(setup_block.path, test_block.path) and
        has_db_writes?(setup_block.ast, analysis.local_write_functions)
    end)
  end

  defp path_prefix?([], _path), do: true
  defp path_prefix?(prefix, path), do: Enum.take(path, length(prefix)) == prefix

  defp has_db_reads?(ast) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        {{:., _, [{:__aliases__, _, module_parts}, func]}, _, _} = node, acc
        when func in @repo_read_funcs ->
          if List.last(module_parts) == :Repo, do: {node, true}, else: {node, acc}

        node, acc ->
          {node, acc}
      end)

    found
  end

  defp has_db_writes?(ast, local_write_functions) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        # Repo.insert, Repo.insert!
        {{:., _, [{:__aliases__, _, module_parts}, func]}, _, _} = node, acc
        when func in @repo_write_funcs ->
          if List.last(module_parts) == :Repo, do: {node, true}, else: {node, acc}

        # Context/helper calls like create_taxonomy/update_host_places/save_changes
        {{:., _, [_module_ast, func]}, _, _} = node, acc when is_atom(func) ->
          if mutating_function?(func), do: {node, true}, else: {node, acc}

        # fixture functions: anything ending in _fixture
        {func_name, _, args} = node, acc when is_atom(func_name) and is_list(args) ->
          if String.ends_with?(Atom.to_string(func_name), "_fixture") or
               MapSet.member?(local_write_functions, {func_name, length(args)}) do
            {node, true}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    found
  end

  defp mutating_function?(func) do
    func
    |> Atom.to_string()
    |> then(fn func_name ->
      Enum.any?(@mutating_prefixes, &String.starts_with?(func_name, &1))
    end)
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
