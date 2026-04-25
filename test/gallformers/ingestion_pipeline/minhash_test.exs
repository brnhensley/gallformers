defmodule Gallformers.IngestionPipeline.MinHashTest do
  use ExUnit.Case, async: true

  alias Gallformers.IngestionPipeline.MinHash

  test "compute_signature/1 returns a deterministic 128-element signature" do
    text = "oak gall wasp larva inside spherical gall on stem with thick walls and many cells"

    first = MinHash.compute_signature(text)
    second = MinHash.compute_signature(text)

    assert length(first) == 128
    assert first == second
    assert Enum.all?(first, &is_integer/1) == true
  end

  test "similar texts produce high similarity" do
    repeated =
      Enum.map_join(1..8, " ", fn _ ->
        "oak gall wasp larva inside spherical gall on stem with thick walls and many cells"
      end)

    text_a = repeated
    text_b = repeated <> " oak gall wasp larva inside spherical gall on stem with thick walls"

    similarity =
      text_a
      |> MinHash.compute_signature()
      |> MinHash.similarity(MinHash.compute_signature(text_b))

    assert similarity > 0.9
  end

  test "dissimilar texts produce low similarity" do
    text_a = "oak gall wasp larva stem spherical walls cells thick green plant tissue"
    text_b = "marine whale ocean current saltwater coral reef tide fish pelagic habitat"

    similarity =
      text_a
      |> MinHash.compute_signature()
      |> MinHash.similarity(MinHash.compute_signature(text_b))

    assert similarity < 0.5
  end

  test "similarity/2 returns expected edge values" do
    assert MinHash.similarity([1, 2, 3], [1, 2, 3]) == 1.0
    assert MinHash.similarity([1, 1, 1], [2, 2, 2]) == 0.0
  end
end
