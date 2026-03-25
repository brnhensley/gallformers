defmodule Gallformers.Credo.Checks.Architecture.NoMockingLibraries do
  use Credo.Check,
    base_priority: :high,
    exit_status: 0,
    category: :design,
    explanations: [
      check:
        "Mocking libraries (Mox, Mock, :meck) are not allowed. Use behaviours and test stubs instead."
    ]

  @mock_modules [:Mox, :Mock]

  @impl Credo.Check
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  # use Mox / use Mock
  defp traverse({:use, meta, [{:__aliases__, _, [module]}]} = ast, issues, issue_meta)
       when module in @mock_modules do
    {ast, issues ++ [issue_for(issue_meta, meta[:line], "use #{module}")]}
  end

  # import Mox / import Mock
  defp traverse({:import, meta, [{:__aliases__, _, [module]}]} = ast, issues, issue_meta)
       when module in @mock_modules do
    {ast, issues ++ [issue_for(issue_meta, meta[:line], "import #{module}")]}
  end

  # :meck.something(...)
  defp traverse(
         {{:., meta, [:meck, _function]}, _call_meta, _args} = ast,
         issues,
         issue_meta
       ) do
    {ast, issues ++ [issue_for(issue_meta, meta[:line], ":meck")]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(issue_meta, line_no, trigger) do
    format_issue(
      issue_meta,
      message:
        "Mocking library #{trigger} is not allowed. Use behaviours and test stubs instead.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
