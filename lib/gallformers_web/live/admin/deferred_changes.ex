defmodule GallformersWeb.Admin.DeferredChanges do
  @moduledoc """
  Helpers for tracking original vs pending state in admin forms.

  Gall and host forms have related data (aliases, hosts, places, filter values)
  that lives in separate DB tables. Changes should not persist until Save is clicked.
  This module provides helpers for tracking what was loaded vs what the user has changed.

  ## Usage

      # In apply_action when loading edit form:
      socket
      |> assign(DeferredChanges.init(:aliases, loaded_aliases))
      |> assign(DeferredChanges.init(:hosts, loaded_hosts))

      # Adding a new item:
      socket = DeferredChanges.add_pending(socket, :aliases, %{name: "Oak gall", type: "common name"})

      # Removing an item:
      socket = DeferredChanges.remove_pending(socket, :aliases, alias_id)

      # Check for duplicates before adding:
      if DeferredChanges.exists?(socket, :aliases, :name, "Oak gall") do
        put_flash(socket, :error, "Alias already exists")
      end

      # On save, compute what changed:
      {to_add, to_remove} = DeferredChanges.compute_changes(socket, :aliases)

      # After successful save, refresh from DB:
      socket = DeferredChanges.refresh(socket, :aliases, reloaded_aliases)
  """

  import Phoenix.Component, only: [assign: 3]

  @doc """
  Initialize tracking for a collection.

  Returns a map with `original_<name>` and `<name>` keys to be merged into socket assigns.

  ## Examples

      iex> DeferredChanges.init(:aliases, [%{id: 1, name: "foo"}])
      %{original_aliases: [%{id: 1, name: "foo"}], aliases: [%{id: 1, name: "foo"}]}

      iex> DeferredChanges.init(:hosts, [])
      %{original_hosts: [], hosts: []}
  """
  @spec init(atom(), list()) :: map()
  def init(collection_name, items) when is_atom(collection_name) and is_list(items) do
    original_key = String.to_atom("original_#{collection_name}")

    %{
      original_key => items,
      collection_name => items
    }
  end

  @doc """
  Add a pending item to a collection.

  The item is assigned a negative temporary ID and marked with `pending: true`.
  These markers are used by `compute_changes/3` to identify new items.

  ## Options

  - `:id_field` - The field name for the ID (default: `:id`)

  ## Examples

      socket = DeferredChanges.add_pending(socket, :aliases, %{name: "foo", type: "common name"})
      # Adds %{id: -123, name: "foo", type: "common name", pending: true} to :aliases

      socket = DeferredChanges.add_pending(socket, :hosts, %{host_species_id: 5, host_name: "Oak"},
        id_field: :host_relation_id)
  """
  @spec add_pending(Phoenix.LiveView.Socket.t(), atom(), map(), keyword()) ::
          Phoenix.LiveView.Socket.t()
  def add_pending(socket, collection_name, item_attrs, opts \\ []) do
    id_field = Keyword.get(opts, :id_field, :id)
    temp_id = -System.unique_integer([:positive])

    new_item =
      item_attrs
      |> Map.put(id_field, temp_id)
      |> Map.put(:pending, true)

    current_items = Map.get(socket.assigns, collection_name, [])
    updated_items = current_items ++ [new_item]

    assign(socket, collection_name, updated_items)
  end

  @doc """
  Remove an item from a collection by ID.

  ## Options

  - `:id_field` - The field name for the ID (default: `:id`)

  ## Examples

      socket = DeferredChanges.remove_pending(socket, :aliases, 123)
      socket = DeferredChanges.remove_pending(socket, :hosts, -456, id_field: :host_relation_id)
  """
  @spec remove_pending(Phoenix.LiveView.Socket.t(), atom(), integer(), keyword()) ::
          Phoenix.LiveView.Socket.t()
  def remove_pending(socket, collection_name, id, opts \\ []) do
    id_field = Keyword.get(opts, :id_field, :id)
    current_items = Map.get(socket.assigns, collection_name, [])
    updated_items = Enum.reject(current_items, &(Map.get(&1, id_field) == id))

    assign(socket, collection_name, updated_items)
  end

  @doc """
  Check if an item with a given field value exists in the collection.

  Useful for duplicate checking before adding new items.

  ## Examples

      if DeferredChanges.exists?(socket, :aliases, :name, "Oak gall") do
        put_flash(socket, :error, "Alias already exists")
      end

      if DeferredChanges.exists?(socket, :hosts, :host_species_id, 42) do
        put_flash(socket, :error, "Host already associated")
      end
  """
  @spec exists?(Phoenix.LiveView.Socket.t(), atom(), atom(), any()) :: boolean()
  def exists?(socket, collection_name, field, value) do
    items = Map.get(socket.assigns, collection_name, [])
    Enum.any?(items, &(Map.get(&1, field) == value))
  end

  @doc """
  Compute changes between original and current state.

  Returns `{to_add, to_remove}` where:
  - `to_add` - Items with `pending: true` or negative IDs (new items to create)
  - `to_remove` - IDs that were in original but not in current (items to delete)

  ## Options

  - `:id_field` - The field name for the ID (default: `:id`)

  ## Examples

      {to_add, to_remove} = DeferredChanges.compute_changes(socket, :aliases)
      # to_add: [%{id: -1, name: "new", pending: true}]
      # to_remove: MapSet with IDs [5, 7] (removed from original)

      {to_add, to_remove} = DeferredChanges.compute_changes(socket, :hosts,
        id_field: :host_relation_id)
  """
  @spec compute_changes(Phoenix.LiveView.Socket.t(), atom(), keyword()) ::
          {list(), MapSet.t()}
  def compute_changes(socket, collection_name, opts \\ []) do
    id_field = Keyword.get(opts, :id_field, :id)
    original_key = String.to_atom("original_#{collection_name}")

    original_items = Map.get(socket.assigns, original_key, [])
    current_items = Map.get(socket.assigns, collection_name, [])

    original_ids = MapSet.new(Enum.map(original_items, &Map.get(&1, id_field)))

    current_ids =
      current_items
      |> Enum.map(&Map.get(&1, id_field))
      |> Enum.filter(&(&1 > 0))
      |> MapSet.new()

    # Items to remove: in original but not in current
    to_remove = MapSet.difference(original_ids, current_ids)

    # Items to add: have pending: true or negative IDs
    to_add =
      Enum.filter(current_items, fn item ->
        Map.get(item, :pending, false) or Map.get(item, id_field, 0) < 0
      end)

    {to_add, to_remove}
  end

  @doc """
  Refresh both original and current state after successful save.

  Call this after saving to DB and reloading the data to sync the tracking state.

  ## Examples

      # After save succeeds:
      aliases = Species.get_aliases_for_species(species_id)
      socket = DeferredChanges.refresh(socket, :aliases, aliases)
  """
  @spec refresh(Phoenix.LiveView.Socket.t(), atom(), list()) :: Phoenix.LiveView.Socket.t()
  def refresh(socket, collection_name, items) do
    original_key = String.to_atom("original_#{collection_name}")

    socket
    |> assign(original_key, items)
    |> assign(collection_name, items)
  end

  @doc """
  Check if there are any pending changes for a collection.

  Returns `true` if the current state differs from the original state.

  ## Options

  - `:id_field` - The field name for the ID (default: `:id`)

  ## Examples

      if DeferredChanges.has_changes?(socket, :aliases) do
        # Enable save button
      end
  """
  @spec has_changes?(Phoenix.LiveView.Socket.t(), atom(), keyword()) :: boolean()
  def has_changes?(socket, collection_name, opts \\ []) do
    id_field = Keyword.get(opts, :id_field, :id)
    original_key = String.to_atom("original_#{collection_name}")

    original_items = Map.get(socket.assigns, original_key, [])
    current_items = Map.get(socket.assigns, collection_name, [])

    # Quick length check first
    if length(original_items) != length(current_items) do
      true
    else
      # Compare IDs
      original_ids =
        original_items
        |> Enum.map(&Map.get(&1, id_field))
        |> Enum.sort()

      current_ids =
        current_items
        |> Enum.map(&Map.get(&1, id_field))
        |> Enum.sort()

      original_ids != current_ids
    end
  end
end
