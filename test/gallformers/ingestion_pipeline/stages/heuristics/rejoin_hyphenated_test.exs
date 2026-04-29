defmodule Gallformers.IngestionPipeline.Heuristics.RejoinHyphenatedTest do
  use ExUnit.Case, async: true

  alias Gallformers.IngestionPipeline.Heuristics.RejoinHyphenated

  describe "apply/1" do
    test "rejoins words hyphenated across line breaks" do
      assert RejoinHyphenated.apply("This is an ex-\nplanation.") ==
               "This is an explanation."
    end
  end
end
