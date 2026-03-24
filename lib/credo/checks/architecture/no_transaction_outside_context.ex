defmodule Gallformers.Credo.Checks.Architecture.NoTransactionOutsideContext do
  use Credo.Check,
    base_priority: :high,
    exit_status: 0,
    category: :design,
    explanations: [
      check: """
      Repo.transaction should not be called in web modules (GallformersWeb.*).

      Transactions represent atomic domain operations and belong in context
      modules. The web layer should call a single context function that
      internally manages its own transaction.
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

  # Detect Repo.transaction call
  defp traverse(
         {{:., _dot_meta, [{:__aliases__, meta, module_parts}, :transaction]}, _, _args} = ast,
         {true, issues},
         issue_meta
       ) do
    if List.last(module_parts) == :Repo do
      issue =
        format_issue(
          issue_meta,
          message:
            "Repo.transaction should not be used in web modules — wrap in a context function.",
          trigger: "Repo",
          line_no: meta[:line]
        )

      {ast, {true, [issue | issues]}}
    else
      {ast, {true, issues}}
    end
  end

  defp traverse(ast, acc, _issue_meta) do
    {ast, acc}
  end
end
