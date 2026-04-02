defmodule Gallformers.Taxonomy.Lineage do
  @moduledoc """
  The taxonomic placement of a species: Family → Genus → Section (optional).

  This is the "address" of a species in the taxonomy tree. Unlike the Taxonomy
  Ecto schema (which models a single tree node), a Lineage models the *path*
  from family down to genus, composed of proper domain types.

  Includes species_id and species_name because a lineage is always for a
  specific species (or a species being created). These fields are nil during
  creation before the species is persisted.

  Companion to TaxonName: TaxonName parses species name strings (bootstrapping).
  Lineage models where the species sits in the tree (structured data with IDs).
  """

  alias Gallformers.TaxonName
  alias Gallformers.Taxonomy.{Family, Genus, Intermediate, Section}
  alias Gallformers.Taxonomy.Taxonomy, as: TaxonomySchema

  defstruct [:species_id, :species_name, :family, :genus, :section, intermediates: []]

  @type t :: %__MODULE__{
          species_id: integer() | nil,
          species_name: String.t() | nil,
          family: Family.t() | nil,
          intermediates: [Intermediate.t()],
          genus: Genus.t(),
          section: Section.t() | nil
        }

  @type family_candidate :: %{
          genus_id: integer(),
          section: Section.t() | nil,
          family: Family.t()
        }

  @type lookup_result ::
          {:ok, t()}
          | {:new_genus, t()}
          | {:ambiguous, String.t(), [family_candidate()]}
          | {:genus_reference, String.t(), integer() | nil}

  # -------------------------------------------------------------------
  # Constructors
  # -------------------------------------------------------------------

  @doc """
  Build a Lineage for a new genus that doesn't exist in the DB yet.
  """
  @spec new_genus(String.t()) :: t()
  def new_genus(genus_name) do
    %__MODULE__{
      genus: %Genus{name: genus_name}
    }
  end

  @doc """
  Build a Lineage from the result maps returned by SpeciesLink queries.

  Used by `get_taxonomy_for_species` and similar query functions to convert
  their raw query results into a Lineage.
  """
  @spec from_query_result(map(), map() | nil) :: t()
  def from_query_result(genus_result, section_result \\ nil) do
    family =
      if genus_result[:family_id] do
        %Family{
          id: genus_result.family_id,
          name: genus_result.family,
          description: genus_result[:family_description]
        }
      end

    section =
      if section_result && section_result[:section_id] do
        %Section{
          id: section_result.section_id,
          name: section_result.section,
          description: section_result[:section_description]
        }
      end

    %__MODULE__{
      genus: %Genus{
        id: genus_result.genus_id,
        name: genus_result.genus,
        description: genus_result[:genus_description]
      },
      family: family,
      section: section
    }
  end

  @doc """
  Build a Lineage from a list of taxonomy path nodes (as returned by
  `Tree.get_taxonomy_path/1`), ordered root-to-leaf.

  Partitions nodes by type: family, intermediates (sorted by path order),
  genus, section.
  """
  @spec from_path([TaxonomySchema.t()]) :: t()
  def from_path(path_nodes) do
    family_node = Enum.find(path_nodes, &(&1.type == "family"))
    genus_node = Enum.find(path_nodes, &(&1.type == "genus"))
    section_node = Enum.find(path_nodes, &(&1.type == "section"))

    intermediates =
      path_nodes
      |> Enum.filter(&(&1.type == "intermediate"))
      |> Enum.map(fn t ->
        %Intermediate{id: t.id, name: t.name, rank: t.rank, description: t.description}
      end)

    family =
      if family_node,
        do: %Family{
          id: family_node.id,
          name: family_node.name,
          description: family_node.description
        }

    genus =
      if genus_node,
        do: %Genus{id: genus_node.id, name: genus_node.name, description: genus_node.description}

    section =
      if section_node,
        do: %Section{
          id: section_node.id,
          name: section_node.name,
          description: section_node.description
        }

    %__MODULE__{
      family: family,
      intermediates: intermediates,
      genus: genus,
      section: section
    }
  end

  # -------------------------------------------------------------------
  # Behavior
  # -------------------------------------------------------------------

  @doc "Is the genus resolved (has a DB id)? False for new genera during creation."
  @spec resolved?(t()) :: boolean()
  def resolved?(%__MODULE__{genus: %Genus{id: nil}}), do: false
  def resolved?(%__MODULE__{}), do: true

  @doc "Is the genus a placeholder 'Unknown (Family)' name?"
  @spec placeholder_genus?(t()) :: boolean()
  def placeholder_genus?(%__MODULE__{genus: %Genus{name: name}}),
    do: TaxonName.unknown_genus?(name)

  @doc "Does this lineage include a section?"
  @spec has_section?(t()) :: boolean()
  def has_section?(%__MODULE__{section: nil}), do: false
  def has_section?(%__MODULE__{}), do: true

  @doc "Parse the species_name into a TaxonName struct."
  @spec parsed_name(t()) :: TaxonName.t() | nil
  def parsed_name(%__MODULE__{species_name: nil}), do: nil
  def parsed_name(%__MODULE__{species_name: name}), do: TaxonName.parse(name)
end
