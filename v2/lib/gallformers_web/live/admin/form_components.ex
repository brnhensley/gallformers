defmodule GallformersWeb.Admin.FormComponents do
  @moduledoc """
  Shared form components for admin forms.
  """

  use Phoenix.Component

  import GallformersWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders the Cancel/Save button pair used by admin forms.

  ## Attributes

  * `:form_dirty` - Required. Whether the form has unsaved changes.
  * `:mode` - Required. Either `:new` or `:edit`.
  * `:save_label` - Optional. Label for the Save button when in edit mode. Defaults to "Save".
  * `:create_label` - Optional. Label for the Save button when in new mode. Defaults to "Create".

  ## Examples

      <.form_actions form_dirty={@form_dirty} mode={@mode} />
      <.form_actions form_dirty={@form_dirty} mode={@mode} save_label="Save Changes" create_label="Create Place" />
  """
  attr :form_dirty, :boolean, required: true
  attr :mode, :atom, required: true, values: [:new, :edit]
  attr :save_label, :string, default: "Save"
  attr :create_label, :string, default: "Create"

  def form_actions(assigns) do
    ~H"""
    <div class="flex gap-2">
      <button
        type="button"
        phx-click="request_cancel"
        class="px-4 py-2 text-sm text-gray-600 hover:text-gray-800"
      >
        Cancel
      </button>
      <button
        type="submit"
        disabled={not @form_dirty}
        class={[
          "px-4 py-2 text-sm rounded",
          if(@form_dirty,
            do: "bg-gf-maroon text-white hover:bg-gf-maroon/90",
            else: "bg-gray-300 text-gray-500 cursor-not-allowed"
          )
        ]}
      >
        {if @mode == :new, do: @create_label, else: @save_label}
      </button>
    </div>
    """
  end

  @doc """
  Renders an alias editor table for editing species/host aliases.

  ## Attributes

  * `:aliases` - Required. List of alias maps with :id, :name, :type keys.
  * `:new_alias_name` - Required. Current value of the new alias name input.
  * `:new_alias_type` - Required. Currently selected alias type.

  ## Events

  The parent LiveView must handle these events:
  * `"update_new_alias"` - When name or type input changes
  * `"add_alias"` - When plus button clicked
  * `"remove_alias"` - When X button clicked (with `alias-id` value)

  ## Examples

      <.alias_editor
        aliases={@aliases}
        new_alias_name={@new_alias_name}
        new_alias_type={@new_alias_type}
      />
  """
  attr :aliases, :list, required: true
  attr :new_alias_name, :string, required: true
  attr :new_alias_type, :string, required: true

  def alias_editor(assigns) do
    ~H"""
    <div class="mb-3">
      <label class="block text-sm font-medium text-gray-700 mb-1">Aliases:</label>
      <div class="border border-gray-300 rounded">
        <table class="w-full text-sm">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-3 py-1.5 text-left font-medium text-gray-700">Name</th>
              <th class="px-3 py-1.5 text-left font-medium text-gray-700">Type</th>
              <th class="px-3 py-1.5 w-10"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr :for={a <- @aliases} class="hover:bg-gray-50">
              <td class="px-3 py-1.5 italic">{a.name}</td>
              <td class="px-3 py-1.5">{a.type}</td>
              <td class="px-3 py-1.5">
                <button
                  type="button"
                  phx-click="remove_alias"
                  phx-value-alias-id={a.id}
                  class="text-red-600 hover:text-red-800"
                >
                  <.icon name="ph-x" class="h-4 w-4" />
                </button>
              </td>
            </tr>
            <tr>
              <td class="px-3 py-1.5">
                <input
                  type="text"
                  value={@new_alias_name}
                  placeholder="New alias..."
                  phx-keyup="update_new_alias"
                  phx-value-type={@new_alias_type}
                  class="w-full px-2 py-1 border border-gray-300 rounded text-sm"
                />
              </td>
              <td class="px-3 py-1.5">
                <select
                  phx-change="update_new_alias"
                  phx-value-name={@new_alias_name}
                  class="w-full px-2 py-1 border border-gray-300 rounded text-sm"
                >
                  <%= for {label, value} <- alias_type_options() do %>
                    <option value={value} selected={@new_alias_type == value}>
                      {label}
                    </option>
                  <% end %>
                </select>
              </td>
              <td class="px-3 py-1.5">
                <button
                  type="button"
                  phx-click="add_alias"
                  class="text-green-600 hover:text-green-800"
                >
                  <.icon name="ph-plus" class="h-4 w-4" />
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp alias_type_options do
    [
      {"Common Name", "common name"},
      {"Scientific Synonym", "scientific synonym"},
      {"Other", "other"}
    ]
  end

  @doc """
  Renders a modal dialog for renaming a species or host.

  Used by gall_live/form.ex and host_live/form.ex for renaming entities.
  The modal handles the name input, add alias checkbox, and emits events
  to the parent LiveView.

  ## Attributes

  * `:show` - Required. Whether the modal is visible.
  * `:value` - Required. Current value in the rename input.
  * `:add_alias_checked` - Required. Whether the "add alias" checkbox is checked.
  * `:entity_type` - Required. Entity type for display (e.g., "Gall" or "Host").

  ## Events

  The parent LiveView must handle these events:
  * `"close_rename_modal"` - When backdrop clicked, Cancel clicked, or Escape pressed
  * `"update_rename_value"` - When the input value changes (receives `value` param)
  * `"toggle_add_alias_on_rename"` - When the checkbox is toggled
  * `"do_rename"` - When Save Changes is clicked

  ## Examples

      <.rename_modal
        show={@show_rename_modal}
        value={@rename_value}
        add_alias_checked={@add_alias_on_rename}
        entity_type="Gall"
      />
  """
  attr :show, :boolean, required: true, doc: "whether to show the modal"
  attr :value, :string, required: true, doc: "current value in the rename input"

  attr :add_alias_checked, :boolean,
    required: true,
    doc: "whether the add alias checkbox is checked"

  attr :entity_type, :string,
    default: "Species",
    doc: "entity type for display (e.g., 'Gall' or 'Host')"

  def rename_modal(assigns) do
    ~H"""
    <%= if @show do %>
      <div
        class="fixed inset-0 z-50 overflow-y-auto"
        phx-window-keydown="close_rename_modal"
        phx-key="Escape"
      >
        <div class="flex min-h-full items-center justify-center p-4">
          <%!-- Backdrop --%>
          <div
            class="fixed inset-0 bg-black/50 transition-opacity"
            phx-click="close_rename_modal"
          >
          </div>

          <%!-- Modal --%>
          <div class="relative bg-white rounded-lg shadow-xl w-full max-w-2xl">
            <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
              <h3 class="text-xl font-semibold text-gray-900">Edit {@entity_type} Name</h3>
              <button
                type="button"
                phx-click="close_rename_modal"
                class="text-gray-400 hover:text-gray-600"
              >
                <.icon name="ph-x" class="h-6 w-6" />
              </button>
            </div>

            <div class="p-6">
              <input
                type="text"
                value={@value}
                phx-keyup="update_rename_value"
                phx-key="Enter"
                class="w-full px-4 py-3 border border-gray-300 rounded text-lg focus:ring-gf-maroon focus:border-gf-maroon"
                autofocus
              />

              <div class="mt-5">
                <label class="flex items-center gap-3 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@add_alias_checked}
                    phx-click="toggle_add_alias_on_rename"
                    class="w-5 h-5 rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
                  />
                  <span class="text-base text-gray-700">Add Alias for old name?</span>
                </label>
              </div>

              <div class="mt-4 text-sm text-gray-500">
                If you want to reassign the species to a different genus, enter the new name
                with the new genus. If the genus doesn't exist, it will be created under the same family.
                If it exists, the species will be reassigned to that genus.
              </div>
            </div>

            <div class="px-6 py-4 border-t border-gray-200 flex justify-end gap-3">
              <button
                type="button"
                phx-click="close_rename_modal"
                class="px-5 py-2.5 text-base text-gray-600 hover:text-gray-800"
              >
                Cancel
              </button>
              <button
                type="button"
                phx-click="do_rename"
                class="px-5 py-2.5 bg-gf-maroon text-white text-base rounded hover:bg-gf-maroon/90"
              >
                Save Changes
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
