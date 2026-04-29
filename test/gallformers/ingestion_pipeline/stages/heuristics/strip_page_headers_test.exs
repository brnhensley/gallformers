defmodule Gallformers.IngestionPipeline.Heuristics.StripPageHeadersTest do
  use ExUnit.Case, async: true

  alias Gallformers.IngestionPipeline.Heuristics.StripPageHeaders

  describe "apply/1" do
    test "removes journal headers and standalone page numbers" do
      text = """
      end of previous text.

      528 Philippine Journal of Science
      1919

      527

      Start of next text.
      """

      result = StripPageHeaders.apply(text)

      refute result =~ "Philippine Journal of Science"
      refute result =~ "\n527\n"
      assert result =~ "Start of next text."
    end
  end
end
