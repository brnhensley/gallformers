defmodule Mix.Tasks.Gallformers.Wcvp.RestoreTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Gallformers.Wcvp.Restore

  describe "parse_args/1" do
    test "returns defaults with no args" do
      opts = Restore.parse_args([])
      assert opts[:database] == "wcvp"
      assert opts[:url] == Restore.default_url()
    end

    test "overrides database with --database flag" do
      opts = Restore.parse_args(["--database", "wcvp_custom"])
      assert opts[:database] == "wcvp_custom"
    end

    test "overrides url with --url flag" do
      opts = Restore.parse_args(["--url", "https://example.com/dump.dump"])
      assert opts[:url] == "https://example.com/dump.dump"
    end
  end

  describe "default_url/0" do
    test "points to S3 bucket" do
      url = Restore.default_url()
      assert url =~ "gallformers-backups"
      assert url =~ "wcvp.dump"
    end
  end
end
