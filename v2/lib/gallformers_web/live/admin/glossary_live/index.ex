defmodule GallformersWeb.Admin.GlossaryLive.Index do
  @moduledoc """
  Admin page for listing and managing glossary entries.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Glossary

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    if connected?(socket), do: Glossary.subscribe()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Glossary")
      |> assign(:search_query, "")
      |> load_glossary()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Glossary")
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> load_glossary()

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    entry = Glossary.get_glossary!(String.to_integer(id))

    case Glossary.delete_glossary(entry) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Glossary entry deleted successfully")
         |> load_glossary()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete glossary entry")}
    end
  end

  @impl true
  def handle_info({event, _entry}, socket)
      when event in [:glossary_created, :glossary_updated, :glossary_deleted] do
    {:noreply, load_glossary(socket)}
  end

  defp load_glossary(socket) do
    entries =
      case socket.assigns.search_query do
        "" -> Glossary.list_glossary()
        query -> Glossary.search_glossary(query)
      end

    assign(socket, :entries, entries)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Glossary">
      <div class="space-y-6">
        <%!-- Header with search and new button --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex-1 max-w-lg">
            <form phx-change="search" phx-submit="search" id="glossary-search-form">
              <.input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Filter glossary terms..."
                phx-debounce="300"
              />
            </form>
          </div>
          <.link
            navigate={~p"/admin/glossary/new"}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm !text-white !no-underline bg-gf-maroon hover:bg-gf-maroon/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon"
          >
            <.icon name="hero-plus" class="h-5 w-5 mr-2" /> New Entry
          </.link>
        </div>

        <%!-- Glossary list table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-cadet-blue">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Word
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                  Definition
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-white uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={entry <- @entries} class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <.link
                    navigate={~p"/admin/glossary/#{entry.id}"}
                    class="text-gf-maroon hover:underline font-medium"
                  >
                    {entry.word}
                  </.link>
                </td>
                <td class="px-6 py-4 text-sm text-gray-500">
                  {truncate(entry.definition, 80)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <.link
                    navigate={~p"/admin/glossary/#{entry.id}"}
                    class="text-gf-maroon hover:text-gf-autumn mr-4"
                  >
                    Edit
                  </.link>
                  <button
                    phx-click="delete"
                    phx-value-id={entry.id}
                    data-confirm="Are you sure you want to delete this glossary entry?"
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
                </td>
              </tr>
              <tr :if={@entries == []}>
                <td colspan="3" class="px-6 py-8 text-center text-gray-500">
                  No glossary entries found. Try a different search term.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-sm text-gray-500">
          Showing {@entries |> length()} entries
        </p>
      </div>
    </Layouts.admin>
    """
  end

  defp truncate(nil, _), do: ""

  defp truncate(string, max_length) do
    if String.length(string) > max_length do
      String.slice(string, 0, max_length) <> "..."
    else
      string
    end
  end
end
