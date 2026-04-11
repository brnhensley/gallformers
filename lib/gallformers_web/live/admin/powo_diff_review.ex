defmodule GallformersWeb.Admin.PowoDiffReview do
  @moduledoc """
  LiveComponent that owns the POWO diff review UI lifecycle.

  Renders a selectable tree for each non-empty diff bucket, allowing the user
  to cherry-pick which POWO-WCVP changes to apply to a host's range.

  ## Props

  - `diff` — from `Plants.compute_powo_diff/3`
  - `place_by_code` — `%{code => %{name: _, ...}}`

  ## Messages sent to parent

  - `{PowoDiffReview, {:apply, selections}}` — map of MapSets per bucket
  - `{PowoDiffReview, :cancel}` — dismiss the diff
  """
  use GallformersWeb, :live_component

  import GallformersWeb.BrowseHelpers, only: [toggle_set: 2, toggle_group_selection: 3]

  @buckets ~w(add_native add_introduced remove reclassify_to_introduced reclassify_to_native)a

  @bucket_config %{
    add_native: %{
      label: "+ Native places in WCVP but not in current range",
      container_class: "bg-green-50 border border-green-200 rounded p-3",
      text_class: "text-green-700",
      heading_class: "text-green-800",
      checkbox_class: "text-green-600 focus:ring-green-500"
    },
    add_introduced: %{
      label: "+ Introduced places in WCVP but not in current range",
      container_class: "border border-green-200 rounded p-3",
      container_style:
        "background: repeating-linear-gradient(-45deg, #dcfce7, #dcfce7 3px, #bbf7d0 3px, #bbf7d0 6px)",
      text_class: "text-green-700",
      heading_class: "text-green-800",
      checkbox_class: "text-green-600 focus:ring-green-500"
    },
    remove: %{
      label: "- Places in current range but not in WCVP",
      container_class: "bg-red-50 border border-red-200 rounded p-3",
      text_class: "text-red-700",
      heading_class: "text-red-800",
      checkbox_class: "text-red-600 focus:ring-red-500"
    },
    reclassify_to_introduced: %{
      label: "Reclassify: WCVP says introduced (currently native)",
      container_class: "border border-green-200 rounded p-3",
      container_style:
        "background: repeating-linear-gradient(-45deg, #dcfce7, #dcfce7 3px, #bbf7d0 3px, #bbf7d0 6px)",
      text_class: "text-green-700",
      heading_class: "text-green-800",
      checkbox_class: "text-green-600 focus:ring-green-500"
    },
    reclassify_to_native: %{
      label: "Reclassify: WCVP says native (currently introduced)",
      container_class: "bg-green-50 border border-green-200 rounded p-3",
      text_class: "text-green-700",
      heading_class: "text-green-800",
      checkbox_class: "text-green-600 focus:ring-green-500"
    }
  }

  @impl true
  def update(%{diff: diff, place_by_code: place_by_code} = assigns, socket) do
    if socket.assigns[:diff] != diff do
      {:ok,
       socket
       |> assign(:id, assigns.id)
       |> assign(:diff, diff)
       |> assign(:place_by_code, place_by_code)
       |> init_selections(diff)
       |> init_groups(diff, place_by_code)}
    else
      {:ok, assign(socket, assigns)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="border border-blue-200 rounded-lg p-4 bg-blue-50">
      <h4 class="font-medium mb-2">POWO-WCVP Data Comparison</h4>

      <div :if={!@diff.has_changes} class="text-sm text-gray-600">
        No differences found. Host data matches WCVP.
      </div>

      <div :if={@diff.has_changes} class="text-sm space-y-3">
        <.bucket_tree
          :for={bucket <- Enum.reject(@active_buckets, &(&1 == :remove))}
          bucket={bucket}
          groups={Map.get(assigns, groups_field(bucket))}
          selected={Map.get(assigns, selected_field(bucket))}
          expanded={section_expanded(@expanded_countries, Atom.to_string(bucket))}
          myself={@myself}
        />
        <.remove_bucket
          :if={@diff.remove != []}
          groups={@groups_remove}
          selected={@selected_remove}
          introduced={@remove_as_introduced}
          expanded={section_expanded(@expanded_countries, "remove")}
          myself={@myself}
        />
      </div>

      <p :if={@diff.agree_count > 0} class="text-sm text-gray-500 mt-2">
        {@diff.agree_count} places match — no changes needed
      </p>

      <div class="mt-3 flex gap-2">
        <.button
          :if={@diff.has_changes}
          phx-click="apply"
          phx-target={@myself}
          type="button"
          size="sm"
          disabled={!has_any_selections?(assigns)}
        >
          Apply Selected Changes
        </.button>
        <.button
          phx-click="cancel"
          phx-target={@myself}
          type="button"
          variant="secondary"
          size="sm"
        >
          Cancel
        </.button>
      </div>
    </div>
    """
  end

  defp bucket_tree(assigns) do
    config = Map.get(@bucket_config, assigns.bucket)
    bid = bucket_id(assigns.bucket)
    has_style = Map.has_key?(config, :container_style)

    assigns =
      assigns
      |> assign(:config, config)
      |> assign(:tree_id, "powo-#{bid}")
      |> assign(:has_style, has_style)
      |> assign(:toggle_item_event, "toggle_item_#{bid}")
      |> assign(:toggle_group_event, "toggle_group_#{bid}")
      |> assign(:expand_group_event, "expand_group_#{bid}")
      |> assign(:select_all_event, "select_all_#{bid}")
      |> assign(:deselect_all_event, "deselect_all_#{bid}")

    ~H"""
    <div :if={@has_style} style={@config.container_style} class={@config.container_class}>
      <.selectable_tree
        id={@tree_id}
        label={@config.label}
        groups={@groups}
        selected={@selected}
        expanded={@expanded}
        toggle_item_event={@toggle_item_event}
        toggle_group_event={@toggle_group_event}
        expand_group_event={@expand_group_event}
        select_all_event={@select_all_event}
        deselect_all_event={@deselect_all_event}
        target={@myself}
        container_class=""
        text_class={@config.text_class}
        heading_class={@config.heading_class}
        checkbox_class={@config.checkbox_class}
      />
    </div>
    <.selectable_tree
      :if={!@has_style}
      id={@tree_id}
      label={@config.label}
      groups={@groups}
      selected={@selected}
      expanded={@expanded}
      toggle_item_event={@toggle_item_event}
      toggle_group_event={@toggle_group_event}
      expand_group_event={@expand_group_event}
      select_all_event={@select_all_event}
      deselect_all_event={@deselect_all_event}
      target={@myself}
      container_class={@config.container_class}
      text_class={@config.text_class}
      heading_class={@config.heading_class}
      checkbox_class={@config.checkbox_class}
    />
    """
  end

  defp remove_bucket(assigns) do
    total_items = Enum.reduce(assigns.groups, 0, fn g, acc -> acc + length(g.items) end)

    kept_count =
      Enum.reduce(assigns.groups, 0, fn g, acc ->
        acc + Enum.count(g.items, &MapSet.member?(assigns.selected, &1.id))
      end)

    introduced_count = MapSet.size(MapSet.intersection(assigns.introduced, assigns.selected))
    removed_count = total_items - kept_count
    all_selected = total_items > 0 and kept_count == total_items

    assigns =
      assigns
      |> assign(:total_items, total_items)
      |> assign(:kept_count, kept_count)
      |> assign(:introduced_count, introduced_count)
      |> assign(:removed_count, removed_count)
      |> assign(:all_selected, all_selected)

    ~H"""
    <div id="powo-remove" class="bg-red-50 border border-red-200 rounded p-3">
      <div class="flex items-center justify-between">
        <span class="font-medium text-red-800">
          Places in current range but not in WCVP ({@kept_count}/{@total_items} kept)
        </span>
        <button
          type="button"
          phx-click={if @all_selected, do: "deselect_all_remove", else: "select_all_remove"}
          phx-target={@myself}
          class="text-xs text-red-700 hover:underline"
        >
          {if @all_selected, do: "Exclude all", else: "Include all"}
        </button>
      </div>

      <p class="text-xs text-red-700 mt-1 mb-2">
        <.icon name="ph-warning" class="h-3.5 w-3.5 inline-block align-text-bottom" />
        These places were added before this WCVP sync. Review each for correct
        native/introduced status. Use the badge to toggle classification.
      </p>

      <p :if={@introduced_count > 0 or @removed_count > 0} class="text-xs text-gray-600 mb-2">
        {@kept_count} kept<span :if={@introduced_count > 0}>
          ({@introduced_count} as introduced)</span>, {@removed_count} excluded
      </p>

      <div class="mt-2 max-h-96 overflow-y-auto space-y-1">
        <div :for={group <- @groups}>
          <% gs = remove_group_state(group, @selected, @expanded) %>
          <div class="flex items-center gap-1.5">
            <input
              id={"powo-remove-group-#{group.id}"}
              type="checkbox"
              checked={gs.all_selected}
              data-indeterminate={to_string(!gs.all_selected and !gs.none_selected)}
              phx-hook="IndeterminateCheckbox"
              phx-click="toggle_group_remove"
              phx-target={@myself}
              phx-value-group={to_string(group.id)}
              class="rounded border-gray-300 text-red-600 focus:ring-red-500"
            />
            <button
              type="button"
              phx-click="expand_group_remove"
              phx-target={@myself}
              phx-value-group={to_string(group.id)}
              class="flex items-center gap-1 text-xs font-medium text-red-800 hover:underline"
            >
              <span class="w-3 text-center">{if gs.expanded, do: "▾", else: "▸"}</span>
              {group.label}
              <span class="font-normal text-gray-500">
                ({gs.selected_count}/{gs.total_count})
              </span>
            </button>
          </div>
          <div :if={gs.expanded} class="ml-6 space-y-0.5 mt-0.5">
            <div :for={item <- group.items} class="flex items-center gap-2">
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={MapSet.member?(@selected, item.id)}
                  phx-click="toggle_item_remove"
                  phx-target={@myself}
                  phx-value-id={to_string(item.id)}
                  class="rounded border-gray-300 text-red-600 focus:ring-red-500"
                />
                <span class="text-xs">{item.label}</span>
              </label>
              <button
                :if={MapSet.member?(@selected, item.id)}
                type="button"
                phx-click="toggle_remove_introduced"
                phx-target={@myself}
                phx-value-id={to_string(item.id)}
                class={[
                  "text-[10px] px-1.5 py-0.5 rounded-full font-medium cursor-pointer",
                  if(MapSet.member?(@introduced, item.id),
                    do: "bg-amber-100 text-amber-700 hover:bg-amber-200",
                    else: "bg-green-100 text-green-700 hover:bg-green-200"
                  )
                ]}
              >
                {if MapSet.member?(@introduced, item.id), do: "Introduced", else: "Native"}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp remove_group_state(group, selected, expanded) do
    selected_count = Enum.count(group.items, &MapSet.member?(selected, &1.id))
    total_count = length(group.items)

    %{
      selected_count: selected_count,
      total_count: total_count,
      all_selected: selected_count == total_count,
      none_selected: selected_count == 0,
      expanded: MapSet.member?(expanded, group.id)
    }
  end

  # --- Event handlers ---

  # Per-bucket event handlers generated from bucket config.
  # Each bucket gets toggle_item, toggle_group, expand_group, select_all, deselect_all.

  for bucket <- @buckets do
    bid =
      case bucket do
        :add_native -> "add-native"
        :add_introduced -> "add-introduced"
        :remove -> "remove"
        :reclassify_to_introduced -> "reclassify-to-introduced"
        :reclassify_to_native -> "reclassify-to-native"
      end

    sel_field = :"selected_#{bucket}"
    grp_field = :"groups_#{bucket}"

    @impl true
    def handle_event(unquote("toggle_item_#{bid}"), %{"id" => code}, socket) do
      current = Map.get(socket.assigns, unquote(sel_field))
      {:noreply, assign(socket, unquote(sel_field), toggle_set(current, code))}
    end

    @impl true
    def handle_event(unquote("toggle_group_#{bid}"), %{"group" => country_code}, socket) do
      groups = Map.get(socket.assigns, unquote(grp_field))
      selected = Map.get(socket.assigns, unquote(sel_field))
      updated = toggle_group_selection(groups, selected, country_code)
      {:noreply, assign(socket, unquote(sel_field), updated)}
    end

    @impl true
    def handle_event(unquote("expand_group_#{bid}"), %{"group" => country_code}, socket) do
      expanded =
        toggle_set(socket.assigns.expanded_countries, {unquote(to_string(bucket)), country_code})

      {:noreply, assign(socket, :expanded_countries, expanded)}
    end

    @impl true
    def handle_event(unquote("select_all_#{bid}"), _params, socket) do
      groups = Map.get(socket.assigns, unquote(grp_field))
      all_ids = groups |> Enum.flat_map(& &1.items) |> MapSet.new(& &1.id)
      {:noreply, assign(socket, unquote(sel_field), all_ids)}
    end

    @impl true
    def handle_event(unquote("deselect_all_#{bid}"), _params, socket) do
      {:noreply, assign(socket, unquote(sel_field), MapSet.new())}
    end
  end

  @impl true
  def handle_event("toggle_remove_introduced", %{"id" => code}, socket) do
    {:noreply,
     assign(
       socket,
       :remove_as_introduced,
       toggle_set(socket.assigns.remove_as_introduced, code)
     )}
  end

  @impl true
  def handle_event("apply", _params, socket) do
    # Intersect remove_as_introduced with selected_remove to discard stale entries
    # (items the user unchecked after marking as introduced)
    remove_as_introduced =
      MapSet.intersection(socket.assigns.remove_as_introduced, socket.assigns.selected_remove)

    selections = %{
      add_native: socket.assigns.selected_add_native,
      add_introduced: socket.assigns.selected_add_introduced,
      remove: socket.assigns.selected_remove,
      remove_as_introduced: remove_as_introduced,
      reclassify_to_introduced: socket.assigns.selected_reclassify_to_introduced,
      reclassify_to_native: socket.assigns.selected_reclassify_to_native
    }

    send(self(), {__MODULE__, {:apply, selections}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    send(self(), {__MODULE__, :cancel})
    {:noreply, socket}
  end

  # --- Private helpers ---

  defp init_selections(socket, diff) do
    socket =
      Enum.reduce(@buckets, socket, fn bucket, sock ->
        codes = Map.get(diff, bucket, [])
        assign(sock, selected_field(bucket), MapSet.new(codes))
      end)

    # Items in the remove bucket start as native (not introduced).
    # The user can toggle individual items to introduced via the secondary control.
    assign(socket, :remove_as_introduced, MapSet.new())
  end

  defp init_groups(socket, diff, place_by_code) do
    active_buckets =
      Enum.filter(@buckets, fn bucket ->
        Map.get(diff, bucket, []) != []
      end)

    socket =
      Enum.reduce(@buckets, socket, fn bucket, sock ->
        codes = Map.get(diff, bucket, [])
        assign(sock, groups_field(bucket), group_places_by_country(codes, place_by_code))
      end)

    socket
    |> assign(:active_buckets, active_buckets)
    |> assign(:expanded_countries, MapSet.new())
  end

  defp selected_field(:add_native), do: :selected_add_native
  defp selected_field(:add_introduced), do: :selected_add_introduced
  defp selected_field(:remove), do: :selected_remove
  defp selected_field(:reclassify_to_introduced), do: :selected_reclassify_to_introduced
  defp selected_field(:reclassify_to_native), do: :selected_reclassify_to_native

  defp groups_field(:add_native), do: :groups_add_native
  defp groups_field(:add_introduced), do: :groups_add_introduced
  defp groups_field(:remove), do: :groups_remove
  defp groups_field(:reclassify_to_introduced), do: :groups_reclassify_to_introduced
  defp groups_field(:reclassify_to_native), do: :groups_reclassify_to_native

  defp bucket_id(:add_native), do: "add-native"
  defp bucket_id(:add_introduced), do: "add-introduced"
  defp bucket_id(:remove), do: "remove"
  defp bucket_id(:reclassify_to_introduced), do: "reclassify-to-introduced"
  defp bucket_id(:reclassify_to_native), do: "reclassify-to-native"

  defp section_expanded(expanded_countries, section) do
    expanded_countries
    |> Enum.filter(fn {s, _} -> s == section end)
    |> MapSet.new(fn {_, country} -> country end)
  end

  defp has_any_selections?(assigns) do
    Enum.any?(@buckets, fn bucket ->
      MapSet.size(Map.get(assigns, selected_field(bucket))) > 0
    end)
  end

  defp place_display(code, place_by_code) do
    case Map.get(place_by_code, code) do
      %{name: name} -> "#{name} (#{code})"
      nil -> code
    end
  end

  defp group_places_by_country(codes, place_by_code) do
    codes
    |> Enum.group_by(fn code ->
      case String.split(code, "-", parts: 2) do
        [country, _region] -> country
        [bare] -> bare
      end
    end)
    |> Enum.map(fn {country_code, group_codes} ->
      country_name =
        case Map.get(place_by_code, country_code) do
          %{name: name} -> name
          nil -> country_code
        end

      items =
        group_codes
        |> Enum.sort()
        |> Enum.map(fn code -> %{id: code, label: place_display(code, place_by_code)} end)

      %{id: country_code, label: country_name, items: items}
    end)
    |> Enum.sort_by(& &1.label)
  end
end
