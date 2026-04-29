defmodule Gallformers.IngestionPipeline.Heuristics.StripPlatePagesTest do
  use ExUnit.Case, async: true

  alias Gallformers.IngestionPipeline.Heuristics.StripPlatePages

  describe "apply/1" do
    test "removes plate image pages but preserves descriptions" do
      text = """
      Real content here.

      ILLUSTRATIONS

      PLATE I

      Description of plate one figures.

      PLATE I. PLANT GALLS.

      UICHANCO: PHILIPPINE PLANT GALLS. ] [PHILIP. JouRN. Sct., XIV, No. 5.

      |

      Hq
      """

      result = StripPlatePages.apply(text)

      assert result =~ "Real content here."
      assert result =~ "Description of plate one figures."
      refute result =~ "PLATE I. PLANT GALLS."
      refute result =~ "UICHANCO: PHILIPPINE PLANT GALLS"
      refute result =~ "Hq"
    end
  end
end
