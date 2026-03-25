defmodule Gallformers.Credo.Checks.TestQuality.FlashOnlyAssertions do
  use Credo.Check,
    base_priority: :low,
    exit_status: 0,
    category: :design,
    explanations: [
      check: """
      Tests that submit forms via `render_submit` or `render_click` should verify
      the operation actually persisted to the database, not just check flash messages.

      A test that only asserts on HTML content after a form submission may pass even
      if the database operation silently failed.
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
    has_submit = has_form_submission?(test_ast)
    has_db_verify = has_db_verification?(test_ast)

    if has_submit and not has_db_verify do
      [issue_for(issue_meta, meta[:line])]
    else
      []
    end
  end

  defp has_form_submission?(ast) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        {:render_submit, _, _} = node, _acc -> {node, true}
        {:render_click, _, _} = node, _acc -> {node, true}
        node, acc -> {node, acc}
      end)

    found
  end

  defp has_db_verification?(ast) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        # Repo.get, Repo.one, Repo.all
        {{:., _, [{:__aliases__, _, module_parts}, func]}, _, _} = node, acc
        when func in [:get, :get!, :one, :one!, :all] ->
          if List.last(module_parts) == :Repo do
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
        "Test submits a form but only checks flash/HTML — verify the DB operation actually persisted.",
      trigger: "render_submit",
      line_no: line_no
    )
  end
end
