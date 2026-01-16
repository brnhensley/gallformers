defmodule GallformersWeb.Admin.TaxonomyLive.Form do
  @moduledoc """
  Admin form for creating and editing taxonomy entries.

  Includes a hierarchical parent selector for setting up the taxonomy tree.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers

  alias Gallformers.Taxonomy
  alias Gallformers.Taxonomy.Taxonomy, as: TaxonomySchema

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Taxonomy")
      |> init_form_state()

    {:ok, socket}
  end

  def close_form(socket) do
    push_navigate(socket, to: ~p"/admin/taxonomy")
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    taxonomy = %TaxonomySchema{}
    changeset = Taxonomy.change_taxonomy(taxonomy)
    parent_options = load_parent_options(nil)

    socket
    |> assign(:page_title, "New Taxonomy Entry")
    |> assign(:taxonomy, taxonomy)
    |> assign(:form, to_form(changeset))
    |> assign(:parent_options, parent_options)
    |> assign(:mode, :new)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    taxonomy = Taxonomy.get_taxonomy!(String.to_integer(id))
    changeset = Taxonomy.change_taxonomy(taxonomy)
    parent_options = load_parent_options(taxonomy.type)

    socket
    |> assign(:page_title, "Edit #{taxonomy.name}")
    |> assign(:taxonomy, taxonomy)
    |> assign(:form, to_form(changeset))
    |> assign(:parent_options, parent_options)
    |> assign(:mode, :edit)
  end

  defp load_parent_options(nil) do
    # For new entries, load all families and sections
    Taxonomy.list_parents_for_genus()
    |> Enum.map(fn p -> {"#{p.name} (#{p.type})", p.id} end)
  end

  defp load_parent_options("family") do
    # Families don't have parents
    []
  end

  defp load_parent_options("genus") do
    # Genera can have family or section parents
    Taxonomy.list_parents_for_genus()
    |> Enum.map(fn p -> {"#{p.name} (#{p.type})", p.id} end)
  end

  defp load_parent_options("section") do
    # Sections have family parents
    Taxonomy.list_families_for_select()
  end

  @impl true
  def handle_event("validate", %{"taxonomy" => params}, socket) do
    changeset =
      socket.assigns.taxonomy
      |> Taxonomy.change_taxonomy(params)
      |> Map.put(:action, :validate)

    # Update parent options when type changes
    parent_options = load_parent_options(params["type"])

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:parent_options, parent_options)
     |> mark_dirty()}
  end

  @impl true
  def handle_event("save", %{"taxonomy" => params}, socket) do
    save_taxonomy(socket, socket.assigns.mode, params)
  end

  @impl true
  def handle_event(event, params, socket)
      when event in ~w(request_cancel cancel_discard confirm_discard) do
    handle_form_event(event, params, socket)
  end

  defp save_taxonomy(socket, :new, params) do
    case Taxonomy.create_taxonomy(params) do
      {:ok, _taxonomy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxonomy created successfully")
         |> push_navigate(to: ~p"/admin/taxonomy")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_taxonomy(socket, :edit, params) do
    case Taxonomy.update_taxonomy(socket.assigns.taxonomy, params) do
      {:ok, _taxonomy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxonomy updated successfully")
         |> push_navigate(to: ~p"/admin/taxonomy")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <Layouts.admin_edit_layout
        back_path={~p"/admin/taxonomy"}
        back_label="Back to Taxonomy"
        title={if @mode == :new, do: "Create New Taxonomy Entry", else: "Edit Taxonomy Entry"}
      >
        <:intro>
          Taxonomy entries define the hierarchical classification of species:
          Family → Section (optional) → Genus. Species are linked to genera.
        </:intro>

        <.form for={@form} id="taxonomy-form" phx-change="validate" phx-submit="save">
          <div class="mb-3">
            <label class="block text-sm font-medium text-gray-700 mb-1">Name:</label>
            <input
              type="text"
              name={@form[:name].name}
              value={Phoenix.HTML.Form.input_value(@form, :name)}
              placeholder="Enter taxonomy name"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
            />
          </div>

          <div class="grid grid-cols-2 gap-4 mb-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Type:</label>
              <select
                name={@form[:type].name}
                required
                class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              >
                <option value="">Select type</option>
                <option
                  value="family"
                  selected={Phoenix.HTML.Form.input_value(@form, :type) == "family"}
                >
                  Family
                </option>
                <option
                  value="genus"
                  selected={Phoenix.HTML.Form.input_value(@form, :type) == "genus"}
                >
                  Genus
                </option>
                <option
                  value="section"
                  selected={Phoenix.HTML.Form.input_value(@form, :type) == "section"}
                >
                  Section
                </option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Description:</label>
              <input
                type="text"
                name={@form[:description].name}
                value={Phoenix.HTML.Form.input_value(@form, :description)}
                placeholder="e.g., 'gall' or 'plant'"
                class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              />
              <p class="mt-1 text-xs text-gray-500">For families: "gall" or "plant"</p>
            </div>
          </div>

          <div class="mb-3">
            <%= if @parent_options != [] do %>
              <label class="block text-sm font-medium text-gray-700 mb-1">Parent:</label>
              <select
                name={@form[:parent_id].name}
                class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              >
                <option value="">Select parent (optional for families)</option>
                <option
                  :for={{label, id} <- @parent_options}
                  value={id}
                  selected={Phoenix.HTML.Form.input_value(@form, :parent_id) == id}
                >
                  {label}
                </option>
              </select>
              <p class="mt-1 text-xs text-gray-500">
                Genera belong to families or sections. Sections belong to families.
              </p>
            <% else %>
              <label class="block text-sm font-medium text-gray-700 mb-1">Parent:</label>
              <p class="text-sm text-gray-500 italic px-3 py-2">
                <%= if Phoenix.HTML.Form.input_value(@form, :type) == "family" do %>
                  Families are top-level entries and have no parent.
                <% else %>
                  Select a type to see available parent options.
                <% end %>
              </p>
            <% end %>
          </div>

          <div class="flex justify-end gap-2 pt-4 border-t border-gray-200">
            <button
              type="button"
              phx-click="request_cancel"
              class="px-4 py-2 text-sm bg-gray-200 hover:bg-gray-300 border border-gray-300 rounded"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={not @form_dirty}
              class={[
                "px-4 py-2 text-sm rounded",
                if(@form_dirty,
                  do: "text-white bg-gf-maroon hover:bg-gf-maroon/90",
                  else: "bg-gray-300 text-gray-500 cursor-not-allowed"
                )
              ]}
            >
              {if @mode == :new, do: "Create", else: "Save Changes"}
            </button>
          </div>
        </.form>

        <.discard_confirm_modal show={@show_discard_confirm} />

        <%!-- Help Card --%>
        <div class="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h3 class="text-sm font-medium text-blue-800 mb-2">
            <.icon name="ph-info" class="h-4 w-4 inline mr-1" /> About Taxonomy Hierarchy
          </h3>
          <ul class="text-sm text-blue-700 space-y-1">
            <li>
              <strong>Families</strong> are the top-level groupings (e.g., Cynipidae, Fagaceae)
            </li>
            <li>
              <strong>Sections</strong>
              are optional sub-groupings within families (used primarily for Quercus oaks)
            </li>
            <li><strong>Genera</strong> belong to families or sections (e.g., Andricus, Quercus)</li>
          </ul>
        </div>
      </Layouts.admin_edit_layout>
    </Layouts.admin>
    """
  end
end
