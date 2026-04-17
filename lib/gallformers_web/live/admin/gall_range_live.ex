defmodule GallformersWeb.Admin.GallRangeLive do
  @moduledoc """
  Admin triage page for gall range confirmation and host-union resets.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Galls

  @page_size 50

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:current_user, session["current_user"])
      |> assign(:page_title, "Gall Range Review")
      |> assign(:selected_ids, MapSet.new())
      |> assign(:confirm_action, nil)
      |> assign(:recomputing, nil)
      |> assign(:recompute_results, nil)
      |> assign(:page_size, @page_size)
      |> assign(:total_count, 0)
      |> assign(:galls, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(
        :filter,
        parse_atom_param(params["filter"], ~w(all confirmed unconfirmed), :unconfirmed)
      )
      |> assign(:range_filter, parse_atom_param(params["range"], ~w(yes no all), :all))
      |> assign(:search, params["search"] || "")
      |> assign(:current_page, parse_int_param(params["page"], 1))
      |> assign(:selected_ids, MapSet.new())
      |> load_galls()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"value" => value}, socket) do
    {:noreply, push_filter_patch(socket, filter: value, page: nil)}
  end

  @impl true
  def handle_event("range_filter", %{"value" => value}, socket) do
    {:noreply, push_filter_patch(socket, range: value, page: nil)}
  end

  @impl true
  def handle_event("search", %{"value" => value}, socket) do
    {:noreply, push_filter_patch(socket, search: value, page: nil)}
  end

  @impl true
  def handle_event("page", %{"page" => page}, socket) do
    {:noreply, push_filter_patch(socket, page: page)}
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id_str}, socket) do
    case Integer.parse(id_str) do
      {id, ""} ->
        selected =
          if MapSet.member?(socket.assigns.selected_ids, id) do
            MapSet.delete(socket.assigns.selected_ids, id)
          else
            MapSet.put(socket.assigns.selected_ids, id)
          end

        {:noreply, assign(socket, :selected_ids, selected)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_all", _params, socket) do
    {:noreply, assign(socket, :selected_ids, MapSet.new(socket.assigns.galls, & &1.id))}
  end

  @impl true
  def handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, :selected_ids, MapSet.new())}
  end

  @impl true
  def handle_event("confirm_selected", _params, socket) do
    {:noreply, assign(socket, :confirm_action, :confirm)}
  end

  @impl true
  def handle_event("recompute_selected", _params, socket) do
    {:noreply, assign(socket, :confirm_action, :recompute)}
  end

  @impl true
  def handle_event("cancel_confirm", _params, socket) do
    {:noreply, assign(socket, :confirm_action, nil)}
  end

  @impl true
  def handle_event("do_confirm_selected", _params, socket) do
    ids = MapSet.to_list(socket.assigns.selected_ids)
    {count, _} = Galls.bulk_confirm_gall_ranges(ids)

    {:noreply,
     socket
     |> assign(:confirm_action, nil)
     |> assign(:selected_ids, MapSet.new())
     |> load_galls()
     |> put_flash(:info, "Confirmed range for #{count} gall(s)")}
  end

  @impl true
  def handle_event("do_recompute_selected", _params, socket) do
    selected_ids = socket.assigns.selected_ids

    galls_to_recompute =
      Enum.filter(socket.assigns.galls, fn gall ->
        MapSet.member?(selected_ids, gall.id)
      end)

    send(self(), {:recompute_next, galls_to_recompute, %{recomputed: 0, changed: 0, failed: []}})

    {:noreply,
     socket
     |> assign(:confirm_action, nil)
     |> assign(:recomputing, %{total: length(galls_to_recompute), done: 0})}
  end

  @impl true
  def handle_event("dismiss_recompute_results", _params, socket) do
    {:noreply, assign(socket, :recompute_results, nil)}
  end

  @impl true
  def handle_info({:recompute_next, [], summary}, socket) do
    {:noreply,
     socket
     |> assign(:recomputing, nil)
     |> assign(:selected_ids, MapSet.new())
     |> assign(:recompute_results, %{
       recomputed: summary.recomputed,
       changed: summary.changed,
       failed: Enum.reverse(summary.failed)
     })
     |> load_galls()}
  end

  @impl true
  def handle_info({:recompute_next, [gall | rest], summary}, socket) do
    updated_summary =
      case Galls.recompute_gall_range_from_hosts(gall.id) do
        {:ok, changed?} ->
          %{
            summary
            | recomputed: summary.recomputed + 1,
              changed: summary.changed + if(changed?, do: 1, else: 0)
          }

        {:error, _reason} ->
          %{summary | failed: [gall.name | summary.failed]}
      end

    send(self(), {:recompute_next, rest, updated_summary})

    {:noreply,
     assign(socket, :recomputing, %{
       socket.assigns.recomputing
       | done: socket.assigns.recomputing.done + 1
     })}
  end

  defp load_galls(socket) do
    opts = [
      filter: socket.assigns.filter,
      has_range: socket.assigns.range_filter,
      search: socket.assigns.search,
      limit: socket.assigns.page_size,
      offset: (socket.assigns.current_page - 1) * socket.assigns.page_size
    ]

    socket
    |> assign(:galls, Galls.list_galls_for_range_review(opts))
    |> assign(:total_count, Galls.count_galls_for_range_review(opts))
  end

  @filter_defaults %{filter: "unconfirmed", range: "all", search: "", page: "1"}

  defp push_filter_patch(socket, overrides) do
    current = %{
      filter: to_string(socket.assigns.filter),
      range: to_string(socket.assigns.range_filter),
      search: socket.assigns.search,
      page: to_string(socket.assigns.current_page)
    }

    params =
      current
      |> Map.merge(Map.new(overrides, fn {k, v} -> {k, to_string(v || "")} end))
      |> Enum.reduce(%{}, fn {key, val}, acc ->
        if val != "" and val != Map.get(@filter_defaults, key) do
          Map.put(acc, key, val)
        else
          acc
        end
      end)

    push_patch(socket, to: ~p"/admin/gall-range?#{params}")
  end

  defp parse_atom_param(nil, _valid, default), do: default
  defp parse_atom_param("", _valid, default), do: default

  defp parse_atom_param(value, valid_strings, default) do
    if value in valid_strings, do: String.to_existing_atom(value), else: default
  end

  defp parse_int_param(nil, default), do: default

  defp parse_int_param(value, default) do
    case Integer.parse(value) do
      {n, ""} when n >= 1 -> n
      _ -> default
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <div class="max-w-7xl mx-auto">
        <div class="mb-4 p-3 bg-gray-50 border border-gray-200 rounded flex items-center gap-4">
          <span class="text-sm font-medium text-gray-700">Quick Links:</span>
          <.link navigate={~p"/admin"} class="text-sm hover:underline">← Back to Admin</.link>
          <.link navigate={~p"/admin/gallhost"} class="text-sm hover:underline">
            Gall-Host Mappings
          </.link>
          <.link navigate={~p"/admin/images"} class="text-sm hover:underline">Manage Images</.link>
        </div>

        <div class="bg-white border border-gray-200 rounded shadow-sm">
          <div class="px-4 py-3 border-b border-gray-200 bg-gray-50 flex items-center justify-between">
            <h4 class="text-lg font-semibold text-gf-maroon">Gall Range Review</h4>
            <span class="text-sm text-gray-500">{@total_count} gall(s)</span>
          </div>

          <div class="p-4">
            <p class="text-sm text-gray-600 mb-4">
              Galls needing range attention are listed below. Click a gall name to review it in detail,
              confirm curated ranges in bulk, or reset selected galls back to the host-native baseline.
            </p>

            <div class="mb-4 flex flex-wrap items-center gap-4">
              <div class="flex items-center gap-2">
                <label class="text-sm font-medium text-gray-700">Status:</label>
                <form phx-change="filter" class="w-40">
                  <.input
                    type="select"
                    name="value"
                    options={[
                      {"Unconfirmed", "unconfirmed"},
                      {"Confirmed", "confirmed"},
                      {"All", "all"}
                    ]}
                    value={@filter}
                  />
                </form>
              </div>

              <div class="flex items-center gap-2">
                <label class="text-sm font-medium text-gray-700">Range:</label>
                <form phx-change="range_filter" class="w-35">
                  <.input
                    type="select"
                    name="value"
                    options={[{"All", "all"}, {"Has range", "yes"}, {"No range", "no"}]}
                    value={@range_filter}
                  />
                </form>
              </div>

              <.search_input
                id="gall-range-search"
                name="value"
                value={@search}
                placeholder="Search by gall name..."
                size={:sm}
                phx-keyup="search"
                phx-debounce="300"
              />
            </div>

            <div :if={@recomputing} class="mb-4 p-3 bg-blue-50 border border-blue-200 rounded">
              <div class="flex items-center gap-2 text-sm text-blue-800">
                <.icon name="ph-arrows-clockwise" class="h-4 w-4 animate-spin" />
                Recomputing from hosts: {@recomputing.done} / {@recomputing.total}
              </div>
              <div class="mt-2 w-full bg-blue-200 rounded-full h-2">
                <div
                  class="bg-blue-600 h-2 rounded-full transition-all"
                  style={"width: #{if @recomputing.total > 0, do: @recomputing.done / @recomputing.total * 100, else: 0}%"}
                >
                </div>
              </div>
            </div>

            <div
              :if={MapSet.size(@selected_ids) > 0 and is_nil(@recomputing)}
              class="mb-4 flex items-center gap-3"
            >
              <button type="button" phx-click="confirm_selected" class="gf-btn gf-btn-primary text-sm">
                <.icon name="ph-check" class="h-4 w-4 inline" />
                Confirm Selected ({MapSet.size(@selected_ids)})
              </button>
              <button
                type="button"
                phx-click="recompute_selected"
                class="gf-btn gf-btn-secondary text-sm"
              >
                <.icon name="ph-arrows-clockwise" class="h-4 w-4 inline" /> Recompute from hosts
              </button>
              <button
                type="button"
                phx-click="deselect_all"
                class="text-sm text-gray-600 hover:underline"
              >
                Clear selection
              </button>
            </div>

            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-gray-200 text-left">
                    <th class="pb-2 pr-4 w-8">
                      <input
                        type="checkbox"
                        checked={MapSet.size(@selected_ids) == length(@galls) and length(@galls) > 0}
                        phx-click={
                          if MapSet.size(@selected_ids) == length(@galls),
                            do: "deselect_all",
                            else: "select_all"
                        }
                        class="rounded border-gray-300"
                        disabled={@recomputing != nil}
                      />
                    </th>
                    <th class="pb-2 pr-4">Gall</th>
                    <th class="pb-2 pr-4 text-center">Hosts</th>
                    <th class="pb-2 pr-4 text-center">Range Places</th>
                    <th class="pb-2 pr-4 text-center">Status</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={gall <- @galls} class="border-b border-gray-100 hover:bg-gray-50">
                    <td class="py-2 pr-4">
                      <input
                        type="checkbox"
                        checked={MapSet.member?(@selected_ids, gall.id)}
                        phx-click="toggle_select"
                        phx-value-id={gall.id}
                        class="rounded border-gray-300"
                        disabled={@recomputing != nil}
                      />
                    </td>
                    <td class="py-2 pr-4">
                      <.link navigate={~p"/admin/gallhost?id=#{gall.id}"} class="hover:underline">
                        <.taxon_name name={gall.name} />
                      </.link>
                      <.badge :if={gall.undescribed} variant="warning">undescribed</.badge>
                    </td>
                    <td class="py-2 pr-4 text-center text-gray-600">{gall.host_count}</td>
                    <td class="py-2 pr-4 text-center text-gray-600">{gall.range_count}</td>
                    <td class="py-2 pr-4 text-center">
                      <.badge :if={gall.range_confirmed} variant="success">Confirmed</.badge>
                      <.badge :if={!gall.range_confirmed} variant="warning">Needs Review</.badge>
                    </td>
                  </tr>
                  <tr :if={@galls == []}>
                    <td colspan="5" class="py-8 text-center text-gray-500">
                      {cond do
                        @search != "" -> "No galls match your search"
                        @filter == :unconfirmed -> "All gall ranges confirmed!"
                        true -> "No galls found"
                      end}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <%= if ceil(@total_count / @page_size) > 1 do %>
              <.pagination
                page={@current_page}
                total_pages={ceil(@total_count / @page_size)}
                total_items={@total_count}
                page_size={@page_size}
                on_page_change={fn page -> JS.push("page", value: %{page: page}) end}
              />
            <% else %>
              <p class="text-sm text-gray-500 mt-2">Showing {@total_count} gall(s)</p>
            <% end %>
          </div>
        </div>
      </div>

      <.modal
        :if={@confirm_action == :confirm}
        id="confirm-modal"
        show
        on_cancel={JS.push("cancel_confirm")}
      >
        <:header>Confirm Gall Ranges</:header>
        <:body>
          <p class="text-gray-600">
            Mark range as confirmed for <strong>{MapSet.size(@selected_ids)}</strong> gall(s)?
          </p>
        </:body>
        <:footer>
          <.button type="button" variant="secondary" phx-click="cancel_confirm">Cancel</.button>
          <.button type="button" variant="primary" phx-click="do_confirm_selected">Confirm</.button>
        </:footer>
      </.modal>

      <.modal
        :if={@confirm_action == :recompute}
        id="recompute-confirm-modal"
        show
        on_cancel={JS.push("cancel_confirm")}
      >
        <:header>Recompute from Hosts</:header>
        <:body>
          <p class="text-gray-600">
            Recompute range for <strong>{MapSet.size(@selected_ids)}</strong> gall(s) from host data?
          </p>
          <p class="text-sm text-gray-500 mt-2">
            This replaces the current gall range with the host-native union and marks the result as
            needing review. Use it only when you want to discard manual edits and reset to the
            host-based baseline before an explicit admin confirmation.
          </p>
        </:body>
        <:footer>
          <.button type="button" variant="secondary" phx-click="cancel_confirm">Cancel</.button>
          <.button type="button" variant="primary" phx-click="do_recompute_selected">
            Recompute
          </.button>
        </:footer>
      </.modal>

      <.modal
        :if={@recompute_results}
        id="recompute-results-modal"
        show
        on_cancel={JS.push("dismiss_recompute_results")}
      >
        <:header>Host Recompute Complete</:header>
        <:body>
          <div class="space-y-3">
            <div class="flex items-center gap-2 text-green-700">
              <.icon name="ph-check-circle" class="h-5 w-5" />
              <span><strong>{@recompute_results.recomputed}</strong> gall(s) recomputed</span>
            </div>
            <div class="text-blue-700">
              <div class="flex items-center gap-2">
                <.icon name="ph-info" class="h-5 w-5" />
                <span><strong>{@recompute_results.changed}</strong> gall(s) changed</span>
              </div>
            </div>
            <div :if={@recompute_results.failed != []} class="text-red-700">
              <div class="flex items-center gap-2">
                <.icon name="ph-x-circle" class="h-5 w-5" />
                <span><strong>{length(@recompute_results.failed)}</strong> failed:</span>
              </div>
              <ul class="ml-7 mt-1 text-sm list-disc">
                <li :for={name <- @recompute_results.failed}>
                  <.taxon_name name={name} />
                </li>
              </ul>
            </div>
          </div>
        </:body>
        <:footer>
          <.button type="button" variant="primary" phx-click="dismiss_recompute_results">
            Close
          </.button>
        </:footer>
      </.modal>
    </Layouts.admin>
    """
  end
end
