defmodule GallformersWeb.Admin.FilterTermsLive.Index do
  @moduledoc """
  Admin page for listing and managing filter terms (colors, shapes, textures, etc.).
  """
  use GallformersWeb, :live_view

  alias Gallformers.FilterFields

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Filter Terms")
      |> assign(:filter_type, :alignment)
      |> load_items()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter_type =
      case params["type"] do
        nil -> :alignment
        type -> String.to_existing_atom(type)
      end

    if filter_type in FilterFields.filter_types() do
      {:noreply,
       socket
       |> assign(:filter_type, filter_type)
       |> load_items()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_type", %{"type" => type}, socket) do
    filter_type = String.to_existing_atom(type)

    {:noreply,
     socket
     |> assign(:filter_type, filter_type)
     |> load_items()
     |> push_patch(to: ~p"/admin/filter-terms?type=#{type}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    filter_type = socket.assigns.filter_type
    item = FilterFields.get!(filter_type, String.to_integer(id))

    case FilterFields.delete(filter_type, item) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{FilterFields.singular_label(filter_type)} deleted successfully")
         |> load_items()}

      {:error, _changeset} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Failed to delete. This term may be in use by existing galls."
         )}
    end
  end

  defp load_items(socket) do
    items = FilterFields.list_all(socket.assigns.filter_type)
    counts = FilterFields.all_counts()

    socket
    |> assign(:items, items)
    |> assign(:counts, counts)
  end

  defp get_field_value(item, filter_type) do
    field = FilterFields.field_name_for(filter_type)
    Map.get(item, field)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Filter Terms">
      <div class="space-y-6">
        <%!-- Info banner --%>
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div class="flex">
            <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400 mr-2 flex-shrink-0" />
            <div class="text-sm text-blue-700">
              <p>
                Filter terms are used in the ID tool to help users narrow down gall matches.
                Each type represents a different characteristic (shape, color, texture, etc.).
                Changes here affect all galls that use these terms.
              </p>
            </div>
          </div>
        </div>

        <%!-- Type selector and New button --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-4">
            <label for="filter-type" class="text-sm font-medium text-gray-700">
              Filter Type:
            </label>
            <select
              id="filter-type"
              name="type"
              phx-change="change_type"
              class="rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon"
            >
              <option
                :for={type <- FilterFields.filter_types()}
                value={type}
                selected={type == @filter_type}
              >
                {FilterFields.type_label(type)} ({@counts[type]})
              </option>
            </select>
          </div>
          <.link
            navigate={~p"/admin/filter-terms/new?type=#{@filter_type}"}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm !text-white !no-underline bg-gf-maroon hover:bg-gf-maroon/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon"
          >
            <.icon name="hero-plus" class="h-5 w-5 mr-2" />
            New {FilterFields.singular_label(@filter_type)}
          </.link>
        </div>

        <%!-- Items table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-cadet-blue">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Term
                </th>
                <%= if FilterFields.has_description?(@filter_type) do %>
                  <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                    Description
                  </th>
                <% end %>
                <th class="px-6 py-3 text-right text-xs font-medium text-white uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={item <- @items} class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <.link
                    navigate={~p"/admin/filter-terms/#{item.id}?type=#{@filter_type}"}
                    class="text-gf-maroon hover:underline font-medium"
                  >
                    {get_field_value(item, @filter_type)}
                  </.link>
                </td>
                <%= if FilterFields.has_description?(@filter_type) do %>
                  <td class="px-6 py-4 text-sm text-gray-500 max-w-md truncate">
                    {item.description || "-"}
                  </td>
                <% end %>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <.link
                    navigate={~p"/admin/filter-terms/#{item.id}?type=#{@filter_type}"}
                    class="text-gf-maroon hover:text-gf-autumn mr-4"
                  >
                    Edit
                  </.link>
                  <button
                    phx-click="delete"
                    phx-value-id={item.id}
                    data-confirm="Are you sure? This may affect galls that use this term."
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
                </td>
              </tr>
              <tr :if={@items == []}>
                <td
                  colspan={if FilterFields.has_description?(@filter_type), do: 3, else: 2}
                  class="px-6 py-8 text-center text-gray-500"
                >
                  No {FilterFields.type_label(@filter_type) |> String.downcase()} found.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-sm text-gray-500">
          Showing {@items |> length()} {FilterFields.type_label(@filter_type) |> String.downcase()}
        </p>
      </div>
    </Layouts.admin>
    """
  end
end
