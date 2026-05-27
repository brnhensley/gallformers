defmodule GallformersWeb.Admin.AliasHandlers do
  @moduledoc """
  Shared alias management handlers for admin forms.

  Both gall and host forms have identical alias add/remove/update logic
  that operates on DeferredChanges. This module extracts that shared behavior.

  ## Usage

  In your LiveView:

      alias GallformersWeb.Admin.AliasHandlers

      def handle_event("update_new_alias_name", params, socket),
        do: {:noreply, AliasHandlers.handle_update_new_alias_name(socket, params)}

      def handle_event("update_new_alias_type", params, socket),
        do: {:noreply, AliasHandlers.handle_update_new_alias_type(socket, params)}

      def handle_event("add_alias", _params, socket),
        do: {:noreply, AliasHandlers.handle_add_alias(socket)}

      def handle_event("remove_alias", %{"alias-id" => alias_id}, socket),
        do: {:noreply, AliasHandlers.handle_remove_alias(socket, alias_id)}
  """

  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3]

  alias GallformersWeb.Admin.DeferredChanges

  @doc """
  Handles the alias name text input changing (InputEvent hook fires on each keystroke).
  """
  def handle_update_new_alias_name(socket, %{"value" => name}) do
    assign(socket, new_alias_name: name)
  end

  @doc """
  Handles the alias type select changing. The select uses `name="alias_type"` (not
  `name="value"`) to avoid colliding with other `name="value"` selects in the same
  parent form when Phoenix LV serializes the full form on phx-change.
  """
  def handle_update_new_alias_type(socket, %{"alias_type" => type}) do
    assign(socket, new_alias_type: type)
  end

  @doc """
  Validates and adds a new alias via DeferredChanges.

  Requires `:new_alias_name` and `:new_alias_type` assigns on the socket.
  Marks the form dirty on success.
  """
  def handle_add_alias(socket) do
    name = String.trim(socket.assigns.new_alias_name)
    type = socket.assigns.new_alias_type

    cond do
      name == "" ->
        put_flash(socket, :error, "Alias name cannot be empty")

      DeferredChanges.exists?(socket, :aliases, :name, name) ->
        put_flash(socket, :error, "Alias already exists")

      true ->
        # LiveView intentionally won't overwrite the value of a focused input
        # on diff, so when the user adds via Enter (input keeps focus) the
        # cleared assign doesn't reach the DOM. Push an explicit clear that the
        # InputEvent hook listens for.
        socket
        |> DeferredChanges.add_pending(:aliases, %{name: name, type: type})
        |> assign(:new_alias_name, "")
        |> push_event("clear_input", %{id: "new-alias-input"})
        |> mark_dirty()
    end
  end

  @doc """
  Removes an alias by ID via DeferredChanges. Marks the form dirty.
  """
  def handle_remove_alias(socket, alias_id) do
    alias_id = if is_binary(alias_id), do: String.to_integer(alias_id), else: alias_id

    socket
    |> DeferredChanges.remove_pending(:aliases, alias_id)
    |> mark_dirty()
  end

  @doc """
  Returns the trimmed pending alias-input value, or `nil` if the field is empty.

  Use from a parent LiveView's save handler to detect when the user typed an
  alias but never clicked Add / pressed Enter, so we can block the save and
  warn rather than silently dropping their input.
  """
  def pending_alias_input(socket) do
    case socket.assigns[:new_alias_name] do
      nil ->
        nil

      name ->
        case String.trim(name) do
          "" -> nil
          trimmed -> trimmed
        end
    end
  end

  @doc """
  Persists alias changes to the database.

  Both gall and host alias operations delegate to `Species.create_alias_for_species/2`
  and `Species.remove_alias_from_species/2`, so this is shared.
  """
  def save_alias_changes(species_id, to_add, to_remove) do
    for alias_id <- to_remove do
      Gallformers.Species.remove_alias_from_species(species_id, alias_id)
    end

    for a <- to_add do
      Gallformers.Species.create_alias_for_species(species_id, %{name: a.name, type: a.type})
    end
  end

  defp mark_dirty(socket) do
    assign(socket, :form_dirty, true)
  end
end
