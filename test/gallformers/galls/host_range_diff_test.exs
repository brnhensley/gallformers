defmodule Gallformers.Galls.HostRangeDiffTest do
  use Gallformers.DataCase, async: true

  import Ecto.Query

  alias Gallformers.Galls
  alias Gallformers.Places.Place
  alias Gallformers.Ranges.HostRange
  alias Gallformers.Repo
  alias Gallformers.Species.Species

  defp create_species(name, taxoncode) do
    Repo.insert!(%Species{name: name, taxoncode: taxoncode})
  end

  defp place_id!(code) do
    Repo.one!(from(p in Place, where: p.code == ^code, select: p.id))
  end

  defp create_host_range(host, place_code, opts) do
    Repo.insert!(%HostRange{
      species_id: host.id,
      place_id: place_id!(place_code),
      precision: Keyword.get(opts, :precision, "exact"),
      distribution_type: Keyword.get(opts, :distribution_type, "native")
    })
  end

  describe "compute_host_range_diff/3" do
    test "splits empty gall range into native and introduced add buckets" do
      diff =
        Galls.compute_host_range_diff(
          [],
          ["US-CA", "US-NY"],
          ["MX-JAL"]
        )

      assert diff.add_native == ["US-CA", "US-NY"]
      assert diff.add_introduced == ["MX-JAL"]
      assert diff.orphaned == []
      assert diff.agree_count == 0
      assert diff.has_changes == true
    end

    test "counts agreement when gall range matches host native union" do
      codes = ["CA-AB", "US-CA"]
      diff = Galls.compute_host_range_diff(codes, codes, [])

      assert diff.add_native == []
      assert diff.add_introduced == []
      assert diff.orphaned == []
      assert diff.agree_count == 2
      refute diff.has_changes
    end

    test "marks places outside the host union as orphaned" do
      diff =
        Galls.compute_host_range_diff(
          ["US-CA", "US-TX"],
          ["US-CA"],
          []
        )

      assert diff.orphaned == ["US-TX"]
      assert diff.agree_count == 1
      assert diff.has_changes == true
    end

    test "prefers native when the same place appears in both host unions" do
      diff =
        Galls.compute_host_range_diff(
          [],
          ["US-CA"],
          []
        )

      assert diff.add_native == ["US-CA"]
      assert diff.add_introduced == []
    end

    test "handles a mixed scenario across all buckets" do
      diff =
        Galls.compute_host_range_diff(
          ["BR", "US-CA"],
          ["BR", "CA-AB"],
          ["MX-JAL"]
        )

      assert diff.add_native == ["CA-AB"]
      assert diff.add_introduced == ["MX-JAL"]
      assert diff.orphaned == ["US-CA"]
      assert diff.agree_count == 1
      assert diff.has_changes == true
    end
  end

  describe "compute_host_union_for_gall/1" do
    test "unions host ranges and removes introduced/native overlap from introduced bucket" do
      gall = create_species("Test gall", "gall")
      host_a = create_species("Host alpha", "plant")
      host_b = create_species("Host beta", "plant")

      {:ok, _} = Galls.create_gall_host(%{gall_species_id: gall.id, host_species_id: host_a.id})
      {:ok, _} = Galls.create_gall_host(%{gall_species_id: gall.id, host_species_id: host_b.id})

      create_host_range(host_a, "US-CA", distribution_type: "native")
      create_host_range(host_a, "MX-JAL", distribution_type: "introduced")
      create_host_range(host_b, "US-CA", distribution_type: "introduced")
      create_host_range(host_b, "CA-AB", distribution_type: "native")

      {native_codes, introduced_codes} = Galls.compute_host_union_for_gall(gall.id)

      assert native_codes == ["CA-AB", "US-CA"]
      assert introduced_codes == ["MX-JAL"]
    end
  end
end
