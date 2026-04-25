defmodule Gallformers.IngestionPipeline.Heuristics.RejoinLinesTest do
  use ExUnit.Case, async: true

  alias Gallformers.IngestionPipeline.Heuristics.RejoinLines

  describe "apply/1" do
    test "rejoins OCR continuation blocks while preserving paragraphs" do
      text = """
      Galls are abnormal growths on the stems, leaves, roots, or

      other parts of plants, caused by the action of insects.

      New paragraph.
      """

      result = RejoinLines.apply(text)

      assert result =~ "roots, or other parts"
      assert result =~ "\n\nNew paragraph."
    end

    test "preserves headings" do
      assert RejoinLines.apply("# INTRODUCTION\n\nSome text here.") ==
               "# INTRODUCTION\n\nSome text here."
    end
  end
end
