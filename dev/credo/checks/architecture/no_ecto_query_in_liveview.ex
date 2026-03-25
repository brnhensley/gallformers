defmodule Gallformers.Credo.Checks.Architecture.NoEctoQueryInLiveView do
  use Credo.Check,
    base_priority: :high,
    exit_status: 0,
    category: :design,
    explanations: [
      check: """
      import Ecto.Query should not appear in web modules (GallformersWeb.*).

      Query construction belongs in context modules. LiveViews and controllers
      should call context functions rather than building queries directly.
      """
    ]

  alias Credo.IssueMeta

  @impl Credo.Check
  def run(%Credo.SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    {_, issues} =
      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta), {false, []})

    issues
  end

  # Track whether we're inside a GallformersWeb module
  defp traverse(
         {:defmodule, _meta, [{:__aliases__, _, module_parts} | _]} = ast,
         {_in_web, issues},
         _issue_meta
       ) do
    in_web = List.first(module_parts) == :GallformersWeb
    {ast, {in_web, issues}}
  end

  # Detect import Ecto.Query
  defp traverse(
         {:import, meta, [{:__aliases__, _, [:Ecto, :Query]} | _]} = ast,
         {true, issues},
         issue_meta
       ) do
    issue =
      format_issue(
        issue_meta,
        message:
          "import Ecto.Query should not be used in web modules — query logic belongs in contexts.",
        trigger: "Ecto.Query",
        line_no: meta[:line]
      )

    {ast, {true, [issue | issues]}}
  end

  defp traverse(ast, acc, _issue_meta) do
    {ast, acc}
  end
end
