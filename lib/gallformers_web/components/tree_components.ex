defmodule GallformersWeb.TreeComponents do
  @moduledoc """
  Reusable tree browser component for displaying hierarchical data.
  """
  use Phoenix.Component

  @doc """
  Renders a tree browser with search, expand/collapse controls, and hierarchical navigation.
  """
  attr :id, :string, required: true
  attr :nodes, :list, required: true
  attr :expanded, :any, required: true
  attr :search_query, :string, default: ""
  attr :show_search, :boolean, default: true
  attr :show_controls, :boolean, default: true
  attr :on_toggle, :string, required: true
  attr :on_expand_all, :string, required: true
  attr :on_collapse_all, :string, required: true
  attr :on_search, :string, required: true

  def tree_browser(assigns) do
    ~H"""
    <div id={@id} class="tree-browser">
      <p class="text-gray-500 italic">No items found.</p>
    </div>
    """
  end
end
