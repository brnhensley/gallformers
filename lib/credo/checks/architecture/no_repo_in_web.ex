defmodule Gallformers.Credo.Checks.Architecture.NoRepoInWeb do
  use Credo.Check,
    base_priority: :high,
    exit_status: 0,
    category: :design,
    explanations: [
      check: """
      Repo should not be referenced directly in web modules (GallformersWeb.*).

      LiveViews and controllers should call context functions instead of
      accessing the database directly. This keeps the web layer thin and
      ensures domain logic lives in context modules.
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

  # Detect alias of a module ending in Repo (e.g., alias Gallformers.Repo)
  defp traverse(
         {:alias, meta, [{:__aliases__, _, module_parts}]} = ast,
         {true, issues},
         issue_meta
       ) do
    if List.last(module_parts) == :Repo do
      issue = issue_for(issue_meta, meta[:line], "alias #{Enum.join(module_parts, ".")}")
      {ast, {true, [issue | issues]}}
    else
      {ast, {true, issues}}
    end
  end

  # Detect Repo.function_call (e.g., Repo.all, Repo.get, etc.)
  defp traverse(
         {{:., _dot_meta, [{:__aliases__, meta, module_parts}, _function]}, _, _args} = ast,
         {true, issues},
         issue_meta
       ) do
    if List.last(module_parts) == :Repo do
      issue = issue_for(issue_meta, meta[:line], "Repo")
      {ast, {true, [issue | issues]}}
    else
      {ast, {true, issues}}
    end
  end

  defp traverse(ast, acc, _issue_meta) do
    {ast, acc}
  end

  defp issue_for(issue_meta, line_no, trigger) do
    format_issue(
      issue_meta,
      message: "Repo should not be used directly in web modules — use context functions instead.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
