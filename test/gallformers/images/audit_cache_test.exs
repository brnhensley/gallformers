defmodule Gallformers.Images.AuditCacheTest do
  @moduledoc """
  Unit tests for the Images.AuditCache GenServer.
  """
  use ExUnit.Case, async: false

  alias Gallformers.Images.AuditCache

  # Use a unique name for test instances to avoid conflicts with the application's cache
  defp start_test_cache(opts \\ []) do
    name = :"test_cache_#{System.unique_integer([:positive])}"
    opts = Keyword.put(opts, :name, name)
    {:ok, pid} = AuditCache.start_link(opts)
    {pid, name}
  end

  describe "start_link/1" do
    test "starts the GenServer" do
      {pid, _name} = start_test_cache()
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "status/0" do
    test "returns initial status with empty cache" do
      {pid, name} = start_test_cache()

      status = GenServer.call(name, :status)

      assert status.count == 0
      assert status.last_scanned == nil
      assert status.stale? == true
      assert status.scanning? == false
      assert status.error == nil

      GenServer.stop(pid)
    end
  end

  describe "get_count/0" do
    test "returns count and stale flag" do
      {pid, name} = start_test_cache()

      {count, stale?} = GenServer.call(name, :get_count)

      assert count == 0
      assert stale? == true

      GenServer.stop(pid)
    end
  end

  describe "get_orphans/1" do
    test "returns empty list initially with stale flag" do
      {pid, name} = start_test_cache()

      {orphans, total, stale?} = GenServer.call(name, {:get_orphans, []})

      assert orphans == []
      assert total == 0
      assert stale? == true

      GenServer.stop(pid)
    end

    test "respects pagination options" do
      {pid, name} = start_test_cache()

      # First request
      {orphans, _total, _stale?} =
        GenServer.call(name, {:get_orphans, [page: 1, per_page: 10]})

      assert is_list(orphans)

      GenServer.stop(pid)
    end
  end

  describe "refresh/0" do
    test "triggers a scan" do
      {pid, name} = start_test_cache()

      # Check initial state
      status_before = GenServer.call(name, :status)
      assert status_before.last_scanned == nil

      # Trigger refresh
      GenServer.cast(name, :refresh)

      # Give the async task a moment to start
      Process.sleep(50)

      # Status should show scanning or complete
      status_after = GenServer.call(name, :status)
      # Either scanning started or already completed
      assert status_after.scanning? == true or status_after.last_scanned != nil

      GenServer.stop(pid)
    end
  end

  describe "TTL behavior" do
    test "marks cache as stale after TTL expires" do
      # Use a very short TTL for testing
      {pid, name} = start_test_cache(ttl_ms: 10)

      # Simulate a completed scan by sending the message directly
      send(pid, {:scan_complete, []})

      # Give it a moment to process
      Process.sleep(5)

      # Should not be stale yet
      status1 = GenServer.call(name, :status)
      assert status1.stale? == false

      # Wait for TTL to expire
      Process.sleep(20)

      # Should be stale now
      status2 = GenServer.call(name, :status)
      assert status2.stale? == true

      GenServer.stop(pid)
    end
  end
end
