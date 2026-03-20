defmodule Gallformers.Wcvp.LookupStub do
  @moduledoc """
  Test stub for Wcvp.Lookup that returns canned data without a database.

  Data:
    - "500" / "Zzyzx wcvponly" — no-match species for search tests (no distributions)
    - "600" / "Thymus alpinus" — matches host 6, with NWY native + ALB introduced
  """
  @behaviour Gallformers.Wcvp.LookupBehaviour

  alias Gallformers.Wcvp.WcvpName

  @names %{
    "500" => %WcvpName{
      plant_name_id: "500",
      taxon_name: "Zzyzx wcvponly",
      family: "Testaceae",
      genus: "Zzyzx",
      species: "wcvponly",
      taxon_authors: "Test",
      powo_id: nil,
      taxon_status: "Accepted",
      native_distribution: [],
      introduced_distribution: []
    },
    "600" => %WcvpName{
      plant_name_id: "600",
      taxon_name: "Thymus alpinus",
      family: "Lamiaceae",
      genus: "Thymus",
      species: "alpinus",
      taxon_authors: "L.",
      powo_id: "urn:lsid:ipni.org:names:test",
      taxon_status: "Accepted",
      native_distribution: ["NWY"],
      introduced_distribution: ["ALB"]
    }
  }

  @impl true
  def available?, do: true

  @impl true
  def built_at, do: ~U[2026-01-01 00:00:00Z]

  @impl true
  def search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    pattern = String.downcase(query)

    @names
    |> Map.values()
    |> Enum.filter(&String.starts_with?(String.downcase(&1.taxon_name), pattern))
    |> Enum.sort_by(& &1.taxon_name)
    |> Enum.take(limit)
  end

  @impl true
  def search_contains(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    terms = query |> String.split(~r/\s+/, trim: true) |> Enum.map(&String.downcase/1)

    @names
    |> Map.values()
    |> Enum.filter(fn name ->
      lower = String.downcase(name.taxon_name)
      Enum.all?(terms, &String.contains?(lower, &1))
    end)
    |> Enum.sort_by(& &1.taxon_name)
    |> Enum.take(limit)
  end

  @impl true
  def match_by_name(name, _opts \\ []) do
    @names
    |> Map.values()
    |> Enum.find(&(&1.taxon_name == name))
  end

  @impl true
  def get(plant_name_id) do
    Map.get(@names, plant_name_id)
  end

  @impl true
  def get_accepted_name(_plant_name_id) do
    nil
  end
end
