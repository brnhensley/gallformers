defmodule Gallformers.IngestionPipeline.Heuristics.StripBHLBoilerplateTest do
  use ExUnit.Case, async: true

  alias Gallformers.IngestionPipeline.Heuristics.StripBHLBoilerplate

  describe "apply/1" do
    test "removes the BHL header block" do
      text = """
      https://www.biodiversitylibrary.org/

      Holding Institution: Missouri Botanical Garden
      Sponsored by: Missouri Botanical Garden

      Generated 3 March 2026 6:28 PM
      This page intentionally left blank.

      A biological and systematic study
      """

      result = StripBHLBoilerplate.apply(text)

      refute result =~ "biodiversitylibrary.org"
      refute result =~ "Holding Institution"
      assert result =~ "A biological and systematic study"
    end
  end
end
