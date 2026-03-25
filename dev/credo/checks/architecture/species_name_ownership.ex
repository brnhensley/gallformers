defmodule Gallformers.Credo.Checks.Architecture.SpeciesNameOwnership do
  @moduledoc false

  use Credo.Check,
    base_priority: :high,
    exit_status: 0,
    category: :design,
    explanations: [
      check: """
      The :name field on Species is owned by Taxonomy.
      Only Taxonomy modules may cast/change/put_change/force_change it.

      This prevents accidental name mutations from contexts that don't own
      the naming rules (e.g., Galls, Species).
      """
    ]

  @impl Credo.Check
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  # When we encounter a defmodule, check if it's a Taxonomy module.
  # If it is, skip the entire module body (return the AST without recursing).
  # If it isn't, recurse into the body looking for :name field mutations.
  defp traverse(
         {:defmodule, _meta, [{:__aliases__, _, module_parts} | _]} = ast,
         issues,
         issue_meta
       ) do
    module_name = Enum.map_join(module_parts, ".", &to_string/1)

    if taxonomy_module?(module_name) do
      # Skip this entire module - don't recurse into it
      {ast, issues}
    else
      # Scan the module body for :name field mutations
      new_issues = Credo.Code.prewalk(ast, &find_name_mutations(&1, &2, issue_meta))
      {ast, issues ++ new_issues}
    end
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  # cast(something, params, [..., :name, ...]) — direct call with 3 args
  defp find_name_mutations(
         {:cast, meta, [_subject, _params, fields_ast]} = ast,
         issues,
         issue_meta
       ) do
    if list_contains_name_atom?(fields_ast) do
      {ast, issues ++ [issue_for(issue_meta, meta[:line], "cast")]}
    else
      {ast, issues}
    end
  end

  # something |> cast(params, [..., :name, ...]) — piped call with 2 args
  defp find_name_mutations({:cast, meta, [_params, fields_ast]} = ast, issues, issue_meta) do
    if list_contains_name_atom?(fields_ast) do
      {ast, issues ++ [issue_for(issue_meta, meta[:line], "cast")]}
    else
      {ast, issues}
    end
  end

  # change(something, %{name: ...}) — direct call with 2 args
  defp find_name_mutations({:change, meta, [_subject, map_ast]} = ast, issues, issue_meta) do
    if map_or_keyword_contains_name?(map_ast) do
      {ast, issues ++ [issue_for(issue_meta, meta[:line], "change")]}
    else
      {ast, issues}
    end
  end

  # something |> change(%{name: ...}) — piped call with 1 arg
  defp find_name_mutations({:change, meta, [map_ast]} = ast, issues, issue_meta) do
    if map_or_keyword_contains_name?(map_ast) do
      {ast, issues ++ [issue_for(issue_meta, meta[:line], "change")]}
    else
      {ast, issues}
    end
  end

  # put_change(changeset, :name, value) — direct call with 3 args
  defp find_name_mutations(
         {:put_change, meta, [_changeset, :name, _value]} = ast,
         issues,
         issue_meta
       ) do
    {ast, issues ++ [issue_for(issue_meta, meta[:line], "put_change")]}
  end

  # changeset |> put_change(:name, value) — piped call with 2 args
  defp find_name_mutations({:put_change, meta, [:name, _value]} = ast, issues, issue_meta) do
    {ast, issues ++ [issue_for(issue_meta, meta[:line], "put_change")]}
  end

  # force_change(changeset, :name, value) — direct call with 3 args
  defp find_name_mutations(
         {:force_change, meta, [_changeset, :name, _value]} = ast,
         issues,
         issue_meta
       ) do
    {ast, issues ++ [issue_for(issue_meta, meta[:line], "force_change")]}
  end

  # changeset |> force_change(:name, value) — piped call with 2 args
  defp find_name_mutations({:force_change, meta, [:name, _value]} = ast, issues, issue_meta) do
    {ast, issues ++ [issue_for(issue_meta, meta[:line], "force_change")]}
  end

  # Also handle qualified forms: Ecto.Changeset.force_change/put_change/cast/change
  defp find_name_mutations(
         {{:., _, [{:__aliases__, _, _}, func_name]}, meta, args} = ast,
         issues,
         issue_meta
       )
       when func_name in [:cast, :change, :put_change, :force_change] do
    find_name_mutations({func_name, meta, args}, issues, issue_meta)
    |> then(fn {_ast, new_issues} -> {ast, new_issues} end)
  end

  defp find_name_mutations(ast, issues, _issue_meta) do
    {ast, issues}
  end

  # Check if an AST list literal contains the :name atom
  defp list_contains_name_atom?(list) when is_list(list) do
    Enum.member?(list, :name)
  end

  defp list_contains_name_atom?(_), do: false

  # Check if a map or keyword list contains a :name key
  defp map_or_keyword_contains_name?({:%{}, _, pairs}) do
    Enum.any?(pairs, fn
      {:name, _} -> true
      _ -> false
    end)
  end

  defp map_or_keyword_contains_name?(pairs) when is_list(pairs) do
    Enum.any?(pairs, fn
      {:name, _} -> true
      _ -> false
    end)
  end

  defp map_or_keyword_contains_name?(_), do: false

  defp taxonomy_module?(module_name) do
    String.starts_with?(module_name, "Gallformers.Taxonomy.")
  end

  defp issue_for(issue_meta, line_no, trigger) do
    format_issue(
      issue_meta,
      message:
        "Only Taxonomy modules may modify the :name field on Species (found in #{trigger} call).",
      trigger: trigger,
      line_no: line_no
    )
  end
end
