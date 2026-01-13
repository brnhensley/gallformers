defmodule GallformersWeb.Admin.TaxonomyLive.Form do
  @moduledoc """
  Admin form for creating and editing taxonomy entries.

  Includes a hierarchical parent selector for setting up the taxonomy tree.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Taxonomy
  alias Gallformers.Taxonomy.Taxonomy, as: TaxonomySchema

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Taxonomy")

    {:ok, socket}
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
     |> assign(:parent_options, parent_options)}
  end

  @impl true
  def handle_event("save", %{"taxonomy" => params}, socket) do
    save_taxonomy(socket, socket.assigns.mode, params)
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
      <Layouts.admin_form_container
        back_path={~p"/admin/taxonomy"}
        back_label="Back to Taxonomy"
        max_width="max-w-2xl"
      >
        <Layouts.form_card title={if @mode == :new, do: "Create New Taxonomy Entry"}>
          <.form for={@form} id="taxonomy-form" phx-change="validate" phx-submit="save" class="p-6">
            <div class="space-y-6">
              <div>
                <.input
                  field={@form[:name]}
                  type="text"
                  label="Name"
                  placeholder="Enter taxonomy name"
                  class="w-full input text-lg py-3"
                  required
                />
              </div>

              <div>
                <.input
                  field={@form[:type]}
                  type="select"
                  label="Type"
                  options={[
                    {"Family", "family"},
                    {"Genus", "genus"},
                    {"Section", "section"}
                  ]}
                  prompt="Select type"
                  class="w-full select text-lg py-3"
                  required
                />
                <p class="mt-1 text-sm text-gray-500">
                  Family &rarr; Section (optional) &rarr; Genus
                </p>
              </div>

              <div>
                <.input
                  field={@form[:description]}
                  type="text"
                  label="Description"
                  placeholder="e.g., 'gall' or 'plant' for families"
                  class="w-full input text-lg py-3"
                />
                <p class="mt-1 text-sm text-gray-500">
                  For families, use "gall" or "plant" to indicate the type of organisms
                </p>
              </div>

              <%= if @parent_options != [] do %>
                <div>
                  <.input
                    field={@form[:parent_id]}
                    type="select"
                    label="Parent"
                    options={@parent_options}
                    prompt="Select parent (optional for families)"
                    class="w-full select text-lg py-3"
                  />
                  <p class="mt-1 text-sm text-gray-500">
                    Genera belong to families (or sections). Sections belong to families.
                  </p>
                </div>
              <% else %>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Parent</label>
                  <p class="text-sm text-gray-500 italic">
                    <%= if @form[:type].value == "family" do %>
                      Families are top-level entries and have no parent.
                    <% else %>
                      Select a type to see available parent options.
                    <% end %>
                  </p>
                </div>
              <% end %>

              <div class="flex justify-end gap-4 pt-4 border-t border-gray-200">
                <.link
                  navigate={~p"/admin/taxonomy"}
                  class="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
                >
                  Cancel
                </.link>
                <button
                  type="submit"
                  class="px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-gf-maroon hover:bg-gf-maroon/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon"
                >
                  {if @mode == :new, do: "Create", else: "Save Changes"}
                </button>
              </div>
            </div>
          </.form>
        </Layouts.form_card>

        <%!-- Help Card --%>
        <div class="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h3 class="text-sm font-medium text-blue-800 mb-2">
            <.icon name="hero-information-circle" class="h-4 w-4 inline mr-1" />
            About Taxonomy Hierarchy
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
            <li>Species are linked to genera through the speciestaxonomy table</li>
          </ul>
        </div>
      </Layouts.admin_form_container>
    </Layouts.admin>
    """
  end
end
