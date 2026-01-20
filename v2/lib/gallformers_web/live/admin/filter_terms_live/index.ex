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
        <div class="gf-admin-info">
          <.icon name="ph-info" class="h-5 w-5 text-blue-400 mr-2 flex-shrink-0" />
          <p>
            Filter terms are used in the ID tool to help users narrow down gall matches.
            Each type represents a different characteristic (shape, color, texture, etc.).
            Changes here affect all galls that use these terms.
          </p>
        </div>

        <%!-- Type selector and New button --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <form phx-change="change_type" class="flex items-center gap-4">
            <.input
              type="select"
              name="type"
              label="Filter Type:"
              options={
                Enum.map(
                  FilterFields.filter_types(),
                  &{FilterFields.type_label(&1) <> " (#{@counts[&1]})", &1}
                )
              }
              value={@filter_type}
            />
          </form>
          <.link
            navigate={~p"/admin/filter-terms/new?type=#{@filter_type}"}
            class="gf-btn gf-btn-primary"
          >
            New {FilterFields.singular_label(@filter_type)}
          </.link>
        </div>

        <%!-- Items table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="gf-table gf-table-dark">
            <thead>
              <tr>
                <th>Term</th>
                <%= if FilterFields.has_description?(@filter_type) do %>
                  <th>Description</th>
                <% end %>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={item <- @items}>
                <td>
                  <.link
                    navigate={~p"/admin/filter-terms/#{item.id}?type=#{@filter_type}"}
                    class="hover:underline font-medium"
                  >
                    {get_field_value(item, @filter_type)}
                  </.link>
                </td>
                <%= if FilterFields.has_description?(@filter_type) do %>
                  <td class="text-gray-500 max-w-md truncate">
                    {item.description || "-"}
                  </td>
                <% end %>
                <td class="text-right">
                  <.table_actions>
                    <.action_button
                      icon="ph-pencil-simple"
                      label="Edit"
                      navigate={~p"/admin/filter-terms/#{item.id}?type=#{@filter_type}"}
                      variant="primary"
                    />
                    <.action_button
                      icon="ph-trash"
                      label="Delete"
                      variant="danger"
                      phx-click="delete"
                      phx-value-id={item.id}
                      confirm="Are you sure? This may affect galls that use this term."
                    />
                  </.table_actions>
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
