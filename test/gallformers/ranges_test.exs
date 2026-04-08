defmodule Gallformers.RangesTest do
  use Gallformers.DataCase, async: true

  alias Gallformers.Galls.GallHost
  alias Gallformers.Places
  alias Gallformers.Places.Place
  alias Gallformers.Ranges
  alias Gallformers.Ranges.HostRange
  alias Gallformers.Repo
  alias Gallformers.Species.Species

  describe "precision-aware range queries" do
    test "get_places_for_host/1 returns both exact and country-level codes" do
      # M. arvensis (id=8) has exact ranges in CA-AB and US-CA,
      # plus a country-level range for US
      codes = Ranges.get_places_for_host(8)
      assert "CA-AB" in codes
      assert "US-CA" in codes
      assert "US" in codes
    end

    test "get_places_for_host_with_precision/1 includes precision metadata" do
      results = Ranges.get_places_for_host_with_precision(8)
      us_entry = Enum.find(results, &(&1.code == "US"))
      ca_entry = Enum.find(results, &(&1.code == "US-CA"))
      assert us_entry.precision == "country"
      assert ca_entry.precision == "exact"
    end

    test "host_covers_place?/2 returns true for exact match" do
      # M. arvensis (8) has exact range in California (US-CA)
      california = Places.get_place_by_code("US-CA")
      assert Ranges.host_covers_place?(8, california.id) == true
    end

    test "host_covers_place?/2 returns true when ancestor has range" do
      # M. arvensis (8) has country-level range for US
      # So any US state should be covered
      california = Places.get_place_by_code("US-CA")
      assert Ranges.host_covers_place?(8, california.id) == true
    end

    test "host_covers_place?/2 returns false for unrelated place" do
      # T. alpinus (6) only has exact range in California
      alberta = Places.get_place_by_code("CA-AB")
      refute Ranges.host_covers_place?(6, alberta.id)
    end
  end

  describe "precision validation" do
    test "rejects continent precision" do
      alias Gallformers.Ranges.HostRange

      changeset =
        HostRange.changeset(%HostRange{}, %{
          species_id: 1,
          place_id: 1,
          precision: "continent"
        })

      assert %{precision: ["is invalid"]} = errors_on(changeset)
    end

    test "rejects continent precision for gall range" do
      alias Gallformers.Ranges.GallRange

      changeset =
        GallRange.changeset(%GallRange{}, %{
          species_id: 1,
          place_id: 1,
          precision: "continent"
        })

      assert %{precision: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "precision-aware range management" do
    test "add_place_to_host/3 accepts precision parameter" do
      bahamas = Places.get_place_by_code("BS")
      {:ok, _} = Ranges.add_place_to_host(6, bahamas.id, "exact")
      codes = Ranges.get_places_for_host(6)
      assert "BS" in codes
    end

    test "add_place_to_host/3 stores country precision" do
      mexico = Places.get_place_by_code("MX")
      {:ok, _} = Ranges.add_place_to_host(6, mexico.id, "country")
      results = Ranges.get_places_for_host_with_precision(6)
      mx = Enum.find(results, &(&1.code == "MX"))
      assert mx.precision == "country"
    end

    test "add_place_to_host/2 defaults to exact precision" do
      bahamas = Places.get_place_by_code("BS")
      {:ok, _} = Ranges.add_place_to_host(6, bahamas.id)
      results = Ranges.get_places_for_host_with_precision(6)
      bs = Enum.find(results, &(&1.code == "BS"))
      assert bs.precision == "exact"
    end

    test "update_host_places/2 accepts {place_id, precision} tuples" do
      california = Places.get_place_by_code("US-CA")
      mexico = Places.get_place_by_code("MX")
      {:ok, _} = Ranges.update_host_places(6, [{california.id, "exact"}, {mexico.id, "country"}])
      results = Ranges.get_places_for_host_with_precision(6)
      ca = Enum.find(results, &(&1.code == "US-CA"))
      mx = Enum.find(results, &(&1.code == "MX"))
      assert ca.precision == "exact"
      assert mx.precision == "country"
    end

    test "update_host_places/2 remains backwards-compatible with plain IDs" do
      california = Places.get_place_by_code("US-CA")
      {:ok, _} = Ranges.update_host_places(6, [california.id])
      results = Ranges.get_places_for_host_with_precision(6)
      ca = Enum.find(results, &(&1.code == "US-CA"))
      assert ca.precision == "exact"
    end
  end

  describe "display range computation" do
    test "get_display_range_for_gall returns DisplayRange struct" do
      result = Ranges.get_display_range_for_gall(100)
      assert %Ranges.DisplayRange{} = result
    end

    test "get_display_range_for_gall reads from gall_range table" do
      # Gall 100 has gall_range entries: US-CA (exact), CA-AB (exact), US (country)
      # MX-JAL is NOT in gall_range (exclusion is implicit)
      result = Ranges.get_display_range_for_gall(100)

      exact_set = MapSet.new(result.in_range)
      inherited_set = MapSet.new(result.inherited_range)

      # No overlap between exact and inherited
      assert MapSet.disjoint?(exact_set, inherited_set) == true

      # MX-JAL is NOT in range (not in gall_range table)
      refute "MX-JAL" in result.in_range
      refute "MX-JAL" in result.inherited_range

      # Exact entries from gall_range
      assert "US-CA" in result.in_range
      assert "CA-AB" in result.in_range
    end

    test "get_display_range_for_host returns DisplayRange" do
      result = Ranges.get_display_range_for_host(8)
      assert %Ranges.DisplayRange{} = result
      # Host 8 has exact entries for CA-AB and US-CA
      assert "CA-AB" in result.in_range
      assert "US-CA" in result.in_range
    end

    test "compute_display_range passes through all codes" do
      # Host 6 only has US-CA exact
      ranges = Ranges.get_places_for_host_with_precision(6)
      result = Ranges.compute_display_range(ranges)
      assert "US-CA" in result.in_range
    end

    test "compute_display_range with with_introduced partitions by distribution_type" do
      california = Places.get_place_by_code("US-CA")
      alberta = Places.get_place_by_code("CA-AB")

      entries = [
        %{
          code: "US-CA",
          precision: "exact",
          place_id: california.id,
          distribution_type: "native"
        },
        %{
          code: "CA-AB",
          precision: "exact",
          place_id: alberta.id,
          distribution_type: "introduced"
        }
      ]

      result = Ranges.compute_display_range(entries, with_introduced: true)
      assert %Ranges.DisplayRange{} = result
      assert "US-CA" in result.in_range
      assert "CA-AB" in result.in_range
      # CA-AB is introduced
      assert "CA-AB" in result.introduced_range
      # US-CA is native, not introduced
      refute "US-CA" in result.introduced_range
    end

    test "compute_display_range without with_introduced returns empty introduced_range" do
      california = Places.get_place_by_code("US-CA")
      entries = [%{code: "US-CA", precision: "exact", place_id: california.id}]
      result = Ranges.compute_display_range(entries)
      assert result.introduced_range == []
    end

    test "get_display_range_for_host returns introduced_range" do
      # Host 7 (T. serpyllum) has US-CA native + BS introduced
      result = Ranges.get_display_range_for_host(7)
      assert %Ranges.DisplayRange{} = result
      assert is_list(result.introduced_range)
      # BS (Bahamas) is introduced for host 7
      assert "BS" in result.introduced_range
      # US-CA is native, should not be in introduced_range
      refute "US-CA" in result.introduced_range
    end

    test "get_host_ranges_with_precision_for_species_ids includes distribution_type" do
      results = Ranges.get_host_ranges_with_precision_for_species_ids([7])
      assert length(results) > 0

      for entry <- results do
        assert Map.has_key?(entry, :distribution_type) == true
        assert entry.distribution_type in ["native", "introduced"]
      end
    end
  end

  describe "gall range queries" do
    test "get_places_for_gall returns curated gall range" do
      # Gall 100 gall_range: US-CA, CA-AB, US (country)
      places = Ranges.get_places_for_gall(100)
      assert is_list(places)
      assert "US-CA" in places
      assert "CA-AB" in places
      assert "US" in places
    end

    test "get_places_for_galls returns grouped results" do
      result = Ranges.get_places_for_galls([100, 101])
      assert is_map(result)
      assert is_list(result[100])
      assert "US-CA" in result[100]
      assert is_list(result[101])
      assert "US-CA" in result[101]
    end

    test "get_places_for_gall with no gall_range returns empty list" do
      # Gall 102 has no gall_range entries
      places = Ranges.get_places_for_gall(102)
      assert places == []
    end
  end

  describe "distribution_type" do
    test "HostRange changeset accepts valid distribution_type values" do
      alias Gallformers.Ranges.HostRange

      for dt <- ~w(native introduced) do
        changeset =
          HostRange.changeset(%HostRange{}, %{species_id: 1, place_id: 1, distribution_type: dt})

        assert changeset.valid? == true
      end
    end

    test "HostRange changeset rejects invalid distribution_type" do
      alias Gallformers.Ranges.HostRange

      changeset =
        HostRange.changeset(%HostRange{}, %{
          species_id: 1,
          place_id: 1,
          distribution_type: "cultivated"
        })

      assert %{distribution_type: ["is invalid"]} = errors_on(changeset)
    end

    test "HostRange changeset defaults distribution_type to native" do
      alias Gallformers.Ranges.HostRange
      changeset = HostRange.changeset(%HostRange{}, %{species_id: 1, place_id: 1})
      assert Ecto.Changeset.get_field(changeset, :distribution_type) == "native"
    end
  end

  describe "distribution_type in insert paths" do
    test "add_place_to_host/4 stores distribution_type" do
      mexico = Places.get_place_by_code("MX")
      {:ok, _} = Ranges.add_place_to_host(6, mexico.id, "country", "introduced")

      import Ecto.Query

      row =
        Gallformers.Repo.one(
          from(hr in Gallformers.Ranges.HostRange,
            where: hr.species_id == 6 and hr.place_id == ^mexico.id,
            select: hr.distribution_type
          )
        )

      assert row == "introduced"
    end

    test "add_place_to_host/3 defaults distribution_type to native" do
      bahamas = Places.get_place_by_code("BS")
      {:ok, _} = Ranges.add_place_to_host(6, bahamas.id, "exact")

      import Ecto.Query

      row =
        Gallformers.Repo.one(
          from(hr in Gallformers.Ranges.HostRange,
            where: hr.species_id == 6 and hr.place_id == ^bahamas.id,
            select: hr.distribution_type
          )
        )

      assert row == "native"
    end

    test "update_host_places/2 accepts {place_id, precision, distribution_type} triples" do
      california = Places.get_place_by_code("US-CA")
      mexico = Places.get_place_by_code("MX")

      {:ok, _} =
        Ranges.update_host_places(6, [
          {california.id, "exact", "native"},
          {mexico.id, "country", "introduced"}
        ])

      import Ecto.Query

      rows =
        Gallformers.Repo.all(
          from(hr in Gallformers.Ranges.HostRange,
            join: p in Gallformers.Places.Place,
            on: hr.place_id == p.id,
            where: hr.species_id == 6,
            select: %{code: p.code, distribution_type: hr.distribution_type}
          )
        )

      ca = Enum.find(rows, &(&1.code == "US-CA"))
      mx = Enum.find(rows, &(&1.code == "MX"))
      assert ca.distribution_type == "native"
      assert mx.distribution_type == "introduced"
    end

    test "update_host_places/2 deduplicates entries for the same place_id" do
      # This is the WCVP sync bug: a place can appear in both native and introduced
      # distributions. Native should win since the PK is (species_id, place_id).
      host =
        Repo.insert!(%Species{
          name: "Dedup Test Host",
          taxoncode: "plant",
          datacomplete: false
        })

      california = Repo.get_by!(Place, code: "US-CA")

      # Same place_id with different distribution_type — should not crash
      {:ok, _} =
        Ranges.update_host_places(host.id, [
          {california.id, "exact", "native"},
          {california.id, "exact", "introduced"}
        ])

      import Ecto.Query

      rows =
        Repo.all(
          from(hr in HostRange,
            where: hr.species_id == ^host.id,
            select: %{place_id: hr.place_id, distribution_type: hr.distribution_type}
          )
        )

      # Should have exactly one row, and native wins
      assert length(rows) == 1
      assert hd(rows).distribution_type == "native"
    end

    test "normalize_entries backwards compatible with plain IDs defaults to native" do
      california = Places.get_place_by_code("US-CA")

      {:ok, _} = Ranges.update_host_places(6, [california.id])

      import Ecto.Query

      row =
        Gallformers.Repo.one(
          from(hr in Gallformers.Ranges.HostRange,
            where: hr.species_id == 6 and hr.place_id == ^california.id,
            select: hr.distribution_type
          )
        )

      assert row == "native"
    end

    test "normalize_entries backwards compatible with pairs defaults to native" do
      california = Places.get_place_by_code("US-CA")

      {:ok, _} = Ranges.update_host_places(6, [{california.id, "exact"}])

      import Ecto.Query

      row =
        Gallformers.Repo.one(
          from(hr in Gallformers.Ranges.HostRange,
            where: hr.species_id == 6 and hr.place_id == ^california.id,
            select: hr.distribution_type
          )
        )

      assert row == "native"
    end
  end

  describe "toggle operations" do
    test "toggle_place_for_host adds then removes" do
      # Host 6 does not have place 3 (MX-JAL)
      result = Ranges.toggle_place_for_host(6, 3)
      assert {:added, 3} = result

      # Verify it was added
      codes = Ranges.get_places_for_host(6)
      assert "MX-JAL" in codes

      # Toggle off
      result = Ranges.toggle_place_for_host(6, 3)
      assert {:removed, 3} = result

      # Verify it was removed
      codes = Ranges.get_places_for_host(6)
      refute "MX-JAL" in codes
    end
  end

  describe "GallRange schema" do
    test "changeset accepts valid precision values" do
      alias Gallformers.Ranges.GallRange

      for p <- ~w(exact country) do
        changeset = GallRange.changeset(%GallRange{}, %{species_id: 1, place_id: 1, precision: p})
        assert changeset.valid? == true
      end
    end

    test "changeset rejects invalid precision" do
      alias Gallformers.Ranges.GallRange

      changeset =
        GallRange.changeset(%GallRange{}, %{
          species_id: 1,
          place_id: 1,
          precision: "continent"
        })

      assert %{precision: ["is invalid"]} = errors_on(changeset)
    end

    test "changeset defaults precision to exact" do
      alias Gallformers.Ranges.GallRange
      changeset = GallRange.changeset(%GallRange{}, %{species_id: 1, place_id: 1})
      assert Ecto.Changeset.get_field(changeset, :precision) == "exact"
    end
  end

  describe "set_gall_range/2" do
    test "replaces all gall_range entries for a species" do
      california = Places.get_place_by_code("US-CA")
      alberta = Places.get_place_by_code("CA-AB")

      # Gall 100 has 3 entries: US-CA, CA-AB, US (country)
      assert length(Ranges.get_gall_range_place_ids(100)) == 3

      # Replace with just US-CA
      {:ok, :ok} = Ranges.set_gall_range(100, [{california.id, "exact"}])

      ids = Ranges.get_gall_range_place_ids(100)
      assert ids == [california.id]

      # Replace with both US-CA and CA-AB
      {:ok, :ok} = Ranges.set_gall_range(100, [{california.id, "exact"}, {alberta.id, "exact"}])

      ids = Ranges.get_gall_range_place_ids(100)
      assert length(ids) == 2
      assert california.id in ids
      assert alberta.id in ids
    end

    test "accepts plain place_ids (defaults to exact precision)" do
      california = Places.get_place_by_code("US-CA")
      {:ok, :ok} = Ranges.set_gall_range(100, [california.id])

      results = Ranges.get_gall_range_with_precision(100)
      assert length(results) == 1
      assert hd(results).precision == "exact"
    end

    test "clears all entries when given empty list" do
      {:ok, :ok} = Ranges.set_gall_range(100, [])
      assert Ranges.get_gall_range_place_ids(100) == []
    end
  end

  describe "gall range query functions" do
    test "get_gall_range_codes returns codes from gall_range table" do
      codes = Ranges.get_gall_range_codes(100)
      assert "US-CA" in codes
      assert "CA-AB" in codes
      # MX-JAL is NOT in gall_range (was excluded in old system)
      refute "MX-JAL" in codes
    end

    test "get_gall_range_place_ids returns place IDs" do
      ids = Ranges.get_gall_range_place_ids(100)
      assert is_list(ids)
      # US-CA
      assert 2 in ids
      # CA-AB
      assert 1 in ids
    end

    test "get_gall_range_with_precision returns precision metadata" do
      results = Ranges.get_gall_range_with_precision(100)
      us_ca = Enum.find(results, &(&1.code == "US-CA"))
      us = Enum.find(results, &(&1.code == "US"))
      assert us_ca.precision == "exact"
      assert us.precision == "country"
    end

    test "get_gall_range_codes returns empty for gall without range" do
      # Gall 102 has no hosts, so no gall_range entries
      assert Ranges.get_gall_range_codes(102) == []
    end
  end

  describe "gall range host fallback" do
    setup do
      # Create a gall with hosts but NO curated gall_range entries.
      # Host A has native range in US-CA and introduced range in CA-AB.
      # Host B has native range in MX-JAL.
      # Expected fallback: union of native ranges only = US-CA + MX-JAL.
      california = Repo.get_by!(Place, code: "US-CA")
      alberta = Repo.get_by!(Place, code: "CA-AB")
      jalisco = Repo.get_by!(Place, code: "MX-JAL")

      gall =
        Repo.insert!(%Species{
          name: "Fallback Test Gall",
          taxoncode: "gall",
          datacomplete: false
        })

      host_a =
        Repo.insert!(%Species{
          name: "Fallback Host A",
          taxoncode: "plant",
          datacomplete: false
        })

      host_b =
        Repo.insert!(%Species{
          name: "Fallback Host B",
          taxoncode: "plant",
          datacomplete: false
        })

      # Link hosts to gall
      Repo.insert!(%GallHost{host_species_id: host_a.id, gall_species_id: gall.id})
      Repo.insert!(%GallHost{host_species_id: host_b.id, gall_species_id: gall.id})

      # Host A: native in US-CA, introduced in CA-AB
      Repo.insert!(%HostRange{
        species_id: host_a.id,
        place_id: california.id,
        precision: "exact",
        distribution_type: "native"
      })

      Repo.insert!(%HostRange{
        species_id: host_a.id,
        place_id: alberta.id,
        precision: "exact",
        distribution_type: "introduced"
      })

      # Host B: native in MX-JAL
      Repo.insert!(%HostRange{
        species_id: host_b.id,
        place_id: jalisco.id,
        precision: "exact",
        distribution_type: "native"
      })

      %{gall: gall, host_a: host_a, host_b: host_b}
    end

    test "falls back to union of hosts' native ranges when gall has no curated range", %{
      gall: gall
    } do
      result = Ranges.get_display_range_for_gall(gall.id)
      assert %Ranges.DisplayRange{} = result

      all_codes = result.in_range ++ result.inherited_range

      # Native ranges from both hosts
      assert "US-CA" in all_codes
      assert "MX-JAL" in all_codes

      # Introduced range (CA-AB) must NOT appear
      refute "CA-AB" in all_codes
    end

    test "uses curated gall_range when it exists, ignoring host fallback", %{gall: gall} do
      # Add a curated gall_range entry for just CA-AB
      alberta = Repo.get_by!(Place, code: "CA-AB")
      Ranges.set_gall_range(gall.id, [{alberta.id, "exact"}])

      result = Ranges.get_display_range_for_gall(gall.id)

      # Should use curated range, not host fallback
      assert "CA-AB" in result.in_range
      refute "US-CA" in result.in_range
      refute "MX-JAL" in result.in_range
    end

    test "returns empty range for gall with no hosts and no curated range" do
      gall =
        Repo.insert!(%Species{
          name: "Lonely Gall",
          taxoncode: "gall",
          datacomplete: false
        })

      result = Ranges.get_display_range_for_gall(gall.id)
      assert result.in_range == []
      assert result.inherited_range == []
    end
  end
end
