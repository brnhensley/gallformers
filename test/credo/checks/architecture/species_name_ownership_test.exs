defmodule Gallformers.Credo.Checks.Architecture.SpeciesNameOwnershipTest do
  use Credo.Test.Case

  alias Gallformers.Credo.Checks.Architecture.SpeciesNameOwnership

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags cast with :name in a Species module" do
    """
    defmodule Gallformers.Species do
      def changeset(species, attrs) do
        species
        |> cast(attrs, [:name, :taxoncode])
      end
    end
    """
    |> to_source_file()
    |> run_check(SpeciesNameOwnership)
    |> assert_issue()
  end

  test "allows cast with :name in a Taxonomy module" do
    """
    defmodule Gallformers.Taxonomy.Reclassification do
      def changeset(species, attrs) do
        species
        |> cast(attrs, [:name, :taxoncode])
      end
    end
    """
    |> to_source_file()
    |> run_check(SpeciesNameOwnership)
    |> refute_issues()
  end

  test "flags change with name key in a non-Taxonomy module" do
    """
    defmodule Gallformers.Galls do
      def rename(species, new_name) do
        change(species, %{name: new_name})
      end
    end
    """
    |> to_source_file()
    |> run_check(SpeciesNameOwnership)
    |> assert_issue()
  end

  test "ignores cast without :name" do
    """
    defmodule Gallformers.Species do
      def changeset(species, attrs) do
        species
        |> cast(attrs, [:taxoncode, :abundance_id])
      end
    end
    """
    |> to_source_file()
    |> run_check(SpeciesNameOwnership)
    |> refute_issues()
  end

  test "flags put_change with :name in a non-Taxonomy module" do
    """
    defmodule Gallformers.Galls do
      def rename(changeset, new_name) do
        put_change(changeset, :name, new_name)
      end
    end
    """
    |> to_source_file()
    |> run_check(SpeciesNameOwnership)
    |> assert_issue()
  end

  test "allows put_change with :name in a Taxonomy module" do
    """
    defmodule Gallformers.Taxonomy.Species do
      def rename(changeset, new_name) do
        put_change(changeset, :name, new_name)
      end
    end
    """
    |> to_source_file()
    |> run_check(SpeciesNameOwnership)
    |> refute_issues()
  end
end
