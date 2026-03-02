defmodule GallformersWeb.BrowseHelpers do
  @moduledoc """
  Shared helper functions for tree-browse LiveViews (galls, hosts, places).

  Provides tree filtering, smart expand logic, and branch key collection
  used by all browse pages.
  """

  # Smart expand thresholds
  @max_families_to_auto_expand 3
  @max_children_per_node 5

  @doc """
  Filters a tree of nodes by a search query string.
  Returns only nodes whose labels match or have matching descendants.
  """
  @spec filter_tree([map()], String.t()) :: [map()]
  def filter_tree(nodes, ""), do: nodes

  def filter_tree(nodes, query) do
    do_filter_tree(nodes, String.downcase(query))
  end

  @doc """
  Computes the smart-expand set for a search query.

  When a search produces few matching families (<= 3), auto-expands nodes
  that have <= 5 children. Otherwise keeps the current expanded set.
  """
  @spec smart_expand([map()], String.t(), MapSet.t()) :: MapSet.t()
  def smart_expand(filtered_tree, query, current_expanded) do
    if String.trim(query) != "" do
      matching_families = length(filtered_tree)

      if matching_families <= @max_families_to_auto_expand do
        filtered_tree
        |> collect_branch_keys_with_limit(@max_children_per_node)
        |> MapSet.new()
      else
        current_expanded
      end
    else
      current_expanded
    end
  end

  @doc """
  Collects all branch node keys from a tree (nodes that have children).
  """
  @spec collect_branch_keys([map()]) :: [String.t()]
  def collect_branch_keys(nodes) do
    Enum.flat_map(nodes, fn node ->
      if Map.has_key?(node, :nodes) and node.nodes != [] do
        [node.key | collect_branch_keys(node.nodes)]
      else
        []
      end
    end)
  end

  # --- Private helpers ---

  defp do_filter_tree(nodes, query_lower) do
    nodes
    |> Enum.map(&filter_node(&1, query_lower))
    |> Enum.reject(&is_nil/1)
  end

  defp filter_node(node, query_lower) do
    if branch_node?(node) do
      filter_branch_node(node, query_lower)
    else
      if label_matches?(node.label, query_lower), do: node, else: nil
    end
  end

  defp filter_branch_node(node, query_lower) do
    filtered_children = do_filter_tree(node.nodes, query_lower)

    if filtered_children != [] or label_matches?(node.label, query_lower) do
      %{node | nodes: filtered_children}
    else
      nil
    end
  end

  defp branch_node?(node), do: Map.has_key?(node, :nodes) and node.nodes != []

  defp label_matches?(label, query_lower),
    do: String.contains?(String.downcase(label), query_lower)

  defp collect_branch_keys_with_limit(nodes, max_children) do
    Enum.flat_map(nodes, &collect_node_keys_with_limit(&1, max_children))
  end

  defp collect_node_keys_with_limit(%{nodes: children} = node, max_children)
       when is_list(children) and children != [] do
    child_keys = collect_branch_keys_with_limit(children, max_children)

    if length(children) <= max_children do
      [node.key | child_keys]
    else
      child_keys
    end
  end

  defp collect_node_keys_with_limit(_node, _max_children), do: []
end
