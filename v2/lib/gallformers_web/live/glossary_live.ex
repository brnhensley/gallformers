defmodule GallformersWeb.GlossaryLive do
  @moduledoc """
  LiveView for the glossary page.

  Displays a sortable table of glossary terms with cross-linking.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Glossary

  @impl true
  def mount(_params, _session, socket) do
    entries = Glossary.list_glossary()

    {:ok,
     assign(socket,
       page_title: "Glossary",
       page_description:
         "A glossary of gall-related terminology - definitions of terms commonly used in cecidiology and gall biology.",
       page_url: "/glossary",
       page_image: nil,
       page_json_ld: nil,
       entries: entries,
       sort_by: :word,
       sort_dir: :asc
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Handle hash navigation for direct term links
    {:noreply, assign(socket, highlight_term: params["term"])}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) do
    column_atom = String.to_existing_atom(column)

    {new_sort_by, new_sort_dir} =
      if socket.assigns.sort_by == column_atom do
        # Toggle direction
        new_dir = if socket.assigns.sort_dir == :asc, do: :desc, else: :asc
        {column_atom, new_dir}
      else
        {column_atom, :asc}
      end

    {:noreply, assign(socket, sort_by: new_sort_by, sort_dir: new_sort_dir)}
  end

  defp sorted_entries(entries, sort_by, sort_dir) do
    sorted =
      Enum.sort_by(entries, fn entry ->
        case sort_by do
          :word -> String.downcase(entry.word || "")
          :definition -> String.downcase(entry.definition || "")
          _ -> String.downcase(entry.word || "")
        end
      end)

    if sort_dir == :desc, do: Enum.reverse(sorted), else: sorted
  end

  defp format_refs(urls) when is_nil(urls), do: []

  defp format_refs(urls) do
    urls
    |> String.split("\n")
    |> Enum.filter(&(String.trim(&1) != ""))
    |> Enum.with_index(1)
    |> Enum.map(fn {url, index} -> %{url: String.trim(url), index: index} end)
  end

  @impl true
  def render(assigns) do
    sorted = sorted_entries(assigns.entries, assigns.sort_by, assigns.sort_dir)
    assigns = assign(assigns, :sorted_entries, sorted)

    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-6xl">
        <h1 class="text-3xl font-bold text-gf-maroon mb-6">
          A Glossary of Gall Related Terminology
        </h1>

        <%= if Enum.empty?(@entries) do %>
          <div class="bg-gray-50 rounded-lg p-8 text-center text-gray-600">
            <p>No glossary entries found.</p>
          </div>
        <% else %>
          <div class="bg-white rounded-lg shadow overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 w-1/4"
                    phx-click="sort"
                    phx-value-column="word"
                  >
                    Word
                    <%= if @sort_by == :word do %>
                      <span class="ml-1">{if @sort_dir == :asc, do: "↑", else: "↓"}</span>
                    <% end %>
                  </th>
                  <th
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                    phx-click="sort"
                    phx-value-column="definition"
                  >
                    Definition
                    <%= if @sort_by == :definition do %>
                      <span class="ml-1">{if @sort_dir == :asc, do: "↑", else: "↓"}</span>
                    <% end %>
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-24">
                    Refs
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for entry <- @sorted_entries do %>
                  <tr class="hover:bg-gray-50 transition-colors" id={String.downcase(entry.word)}>
                    <td class="px-6 py-4 text-sm font-medium text-gray-900 align-top">
                      <span class="font-bold">{entry.word}</span>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-700 align-top">
                      {entry.definition}
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-500 align-top">
                      <%= for ref <- format_refs(entry.urls) do %>
                        <.link
                          href={ref.url}
                          target="_blank"
                          rel="noreferrer"
                          class="text-gf-maroon hover:underline"
                        >
                          {ref.index}
                        </.link>
                        <%= if ref.index < length(format_refs(entry.urls)) do %>
                          <span>, </span>
                        <% end %>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <div class="mt-4 text-sm text-gray-500">
            Showing {length(@entries)} entries
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
