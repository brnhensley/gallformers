defmodule Gallformers.SearchTest do
  use Gallformers.DataCase, async: true

  alias Gallformers.Search

  describe "global_search/2 multi-term matching" do
    test "multi-word query matches species with each term independently" do
      # "q alba" should match "Quercus alba" — "q" in "Quercus", "alba" in "alba"
      results = Search.global_search("q alba")
      host_names = Enum.map(results.hosts, & &1.name)
      assert "Quercus alba" in host_names
    end

    test "multi-word query matches galls with each term independently" do
      # "And crystal" should match "Andricus crystallinus"
      results = Search.global_search("And crystal")
      gall_names = Enum.map(results.galls, & &1.name)
      assert "Andricus crystallinus" in gall_names
    end

    test "multi-word query does not match when a term is absent" do
      # "quercus zzz" should not match anything — "zzz" isn't in any name
      results = Search.global_search("quercus zzz")
      assert results.hosts == []
      assert results.galls == []
    end
  end

  describe "global_search/2 with continent scoping" do
    test "galls with NA hosts appear in XN search" do
      results = Search.global_search("Andricus", "XN")
      gall_names = Enum.map(results.galls, & &1.name)
      assert "Andricus quercuscalifornicus" in gall_names
    end

    test "galls with only NA hosts excluded from XE search" do
      results = Search.global_search("Andricus", "XE")
      gall_names = Enum.map(results.galls, & &1.name)
      refute "Andricus quercuscalifornicus" in gall_names
    end

    test "European gall appears in XE search" do
      results = Search.global_search("Cynips", "XE")
      gall_names = Enum.map(results.galls, & &1.name)
      assert "Cynips quercusfolii" in gall_names
    end

    test "European gall excluded from XN search" do
      results = Search.global_search("Cynips", "XN")
      gall_names = Enum.map(results.galls, & &1.name)
      refute "Cynips quercusfolii" in gall_names
    end

    test "hosts with NA ranges appear in XN search" do
      results = Search.global_search("Thymus", "XN")
      host_names = Enum.map(results.hosts, & &1.name)
      assert "Thymus alpinus" in host_names
    end

    test "hosts with only NA ranges excluded from XE search" do
      results = Search.global_search("Thymus", "XE")
      host_names = Enum.map(results.hosts, & &1.name)
      refute "Thymus alpinus" in host_names
    end

    test "European host appears in XE search" do
      results = Search.global_search("Quercus robur", "XE")
      host_names = Enum.map(results.hosts, & &1.name)
      assert "Quercus robur" in host_names
    end

    test "glossary/taxonomy/source results unaffected by continent" do
      # These should be identical regardless of continent
      all_results = Search.global_search("test", nil)
      na_results = Search.global_search("test", "XN")

      assert all_results.glossary == na_results.glossary
      assert all_results.sources == na_results.sources
      assert all_results.taxonomy == na_results.taxonomy
    end

    test "nil continent returns all results" do
      all_results = Search.global_search("Andricus", nil)
      gall_names = Enum.map(all_results.galls, & &1.name)
      assert "Andricus quercuscalifornicus" in gall_names
    end
  end
end
