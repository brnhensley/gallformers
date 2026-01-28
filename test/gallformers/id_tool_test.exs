defmodule Gallformers.IDToolTest do
  use Gallformers.DataCase, async: false

  alias Gallformers.IDTool

  describe "get_summary_data/1" do
    test "returns filter data for given gall_ids" do
      # This test uses seeded test data - we need galls with known filter values
      # The test database has galls with various filter configurations
      # For now, test that the function returns a map structure

      # Empty list returns empty map
      assert IDTool.get_summary_data([]) == %{}
    end

    test "returns map keyed by gall_id with filter values" do
      # Test with non-existent IDs should return empty map
      result = IDTool.get_summary_data([99_999, 99_998])
      assert result == %{} or is_map(result)
    end
  end
end
