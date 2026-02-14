# Admin Images Table View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a table view to admin images with bulk metadata copy functionality.

**Architecture:** Add view_mode and copy_mode assigns to the existing ImagesLive. Table view renders as a sibling to grid view, controlled by toggle buttons. Bulk copy uses a two-phase inline selection (source row highlighted, checkboxes on other rows). New `copy_metadata/3` function in Images context performs batch update.

**Tech Stack:** Phoenix LiveView, Tailwind CSS, Ecto

---

## Task 1: Add `copy_metadata/3` Context Function

**Files:**
- Modify: `lib/gallformers/images.ex`
- Test: `test/gallformers/images_test.exs`

**Step 1: Write the failing test**

Add to `test/gallformers/images_test.exs`:

```elixir
describe "copy_metadata/3" do
  setup do
    # Get a real species from test seeds
    species = Gallformers.Repo.one!(from s in Gallformers.Species.Species, limit: 1)

    # Create source image with full metadata
    {:ok, source} =
      Images.create_image(%{
        species_id: species.id,
        path: "gall/#{species.id}/#{species.id}_source_original.jpg",
        creator: "Source Creator",
        license: "CC-BY",
        licenselink: "https://creativecommons.org/licenses/by/4.0/",
        sourcelink: "https://example.com/source",
        attribution: "Source attribution notes",
        caption: "Source caption",
        uploader: "test",
        lastchangedby: "test"
      })

    # Create target images with no metadata
    {:ok, target1} =
      Images.create_image(%{
        species_id: species.id,
        path: "gall/#{species.id}/#{species.id}_target1_original.jpg",
        uploader: "test",
        lastchangedby: "test"
      })

    {:ok, target2} =
      Images.create_image(%{
        species_id: species.id,
        path: "gall/#{species.id}/#{species.id}_target2_original.jpg",
        uploader: "test",
        lastchangedby: "test"
      })

    %{source: source, target1: target1, target2: target2}
  end

  test "copies metadata from source to targets", %{source: source, target1: target1, target2: target2} do
    assert {:ok, 2} = Images.copy_metadata(source.id, [target1.id, target2.id], "admin")

    # Reload targets
    updated1 = Images.get_image!(target1.id)
    updated2 = Images.get_image!(target2.id)

    # Check metadata was copied
    assert updated1.creator == "Source Creator"
    assert updated1.license == "CC-BY"
    assert updated1.licenselink == "https://creativecommons.org/licenses/by/4.0/"
    assert updated1.sourcelink == "https://example.com/source"
    assert updated1.attribution == "Source attribution notes"
    assert updated1.caption == "Source caption"
    assert updated1.lastchangedby == "admin"

    assert updated2.creator == "Source Creator"
    assert updated2.license == "CC-BY"
  end

  test "returns error when source not found", %{target1: target1} do
    assert {:error, :source_not_found} = Images.copy_metadata(999_999, [target1.id], "admin")
  end

  test "returns ok with 0 count when no targets", %{source: source} do
    assert {:ok, 0} = Images.copy_metadata(source.id, [], "admin")
  end

  test "copies source_id when source has one", %{source: source, target1: target1} do
    # First, we need a source record to link
    {:ok, pub_source} = Gallformers.Sources.create_source(%{
      title: "Test Publication",
      author: "Test Author",
      pubyear: "2024",
      citation: "Test citation",
      link: "https://example.com",
      license: "CC-BY"
    })

    # Update source image to have source_id
    {:ok, source} = Images.update_image(source, %{source_id: pub_source.id})

    assert {:ok, 1} = Images.copy_metadata(source.id, [target1.id], "admin")

    updated = Images.get_image!(target1.id)
    assert updated.source_id == pub_source.id
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/gallformers/images_test.exs --only describe:"copy_metadata/3"`

Expected: Compilation error - `copy_metadata/3` is undefined

**Step 3: Write the implementation**

Add to `lib/gallformers/images.ex` (after the `update_image` function, around line 162):

```elixir
@doc """
Copy metadata from source image to target images.

Copies: creator, license, licenselink, sourcelink, attribution, caption, source_id
Updates: lastchangedby on all targets

Returns {:ok, count} on success, {:error, reason} on failure.
"""
@spec copy_metadata(integer(), [integer()], String.t()) ::
        {:ok, integer()} | {:error, :source_not_found | term()}
def copy_metadata(_source_id, [], _updated_by), do: {:ok, 0}

def copy_metadata(source_id, target_ids, updated_by) when is_list(target_ids) do
  case get_image(source_id) do
    nil ->
      {:error, :source_not_found}

    source ->
      metadata = %{
        creator: source.creator,
        license: source.license,
        licenselink: source.licenselink,
        sourcelink: source.sourcelink,
        attribution: source.attribution,
        caption: source.caption,
        source_id: source.source_id,
        lastchangedby: updated_by
      }

      {count, _} =
        from(i in ImageSchema, where: i.id in ^target_ids)
        |> Repo.update_all(set: Map.to_list(metadata))

      {:ok, count}
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/gallformers/images_test.exs --only describe:"copy_metadata/3"`

Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/gallformers/images.ex test/gallformers/images_test.exs
git commit -m "$(cat <<'EOF'
Add copy_metadata/3 to Images context

Enables bulk copying of metadata (creator, license, sourcelink, etc.)
from one image to multiple target images. Used by admin table view.
EOF
)"
```

---

## Task 2: Add View Mode State to LiveView

**Files:**
- Modify: `lib/gallformers_web/live/admin/images_live.ex`

**Step 1: Add view_mode assign to mount**

In `lib/gallformers_web/live/admin/images_live.ex`, update the `mount/3` function. Add after line 43 (after `form_dirty` assign):

```elixir
# View mode: :grid (default) or :table
|> assign(:view_mode, :grid)
```

**Step 2: Add toggle_view event handler**

Add after the `handle_event("clear_species", ...)` function (around line 606):

```elixir
@impl true
def handle_event("toggle_view", %{"view" => view}, socket) do
  view_mode = if view == "table", do: :table, else: :grid
  {:noreply, assign(socket, :view_mode, view_mode)}
end
```

**Step 3: Run precommit to verify compilation**

Run: `mix compile --warnings-as-errors`

Expected: Compiles without errors (view_mode not used in template yet)

**Step 4: Commit**

```bash
git add lib/gallformers_web/live/admin/images_live.ex
git commit -m "$(cat <<'EOF'
Add view_mode state to admin images LiveView

Prepares for grid/table toggle. Default is :grid.
EOF
)"
```

---

## Task 3: Add View Toggle UI

**Files:**
- Modify: `lib/gallformers_web/live/admin/images_live.ex`

**Step 1: Update the Images header section**

In `lib/gallformers_web/live/admin/images_live.ex`, replace lines 110-125 (the header div) with:

```elixir
<div class="flex items-center justify-between mb-4">
  <div class="flex items-center gap-4">
    <h2 class="text-lg font-medium text-gray-900">
      Images ({length(@images)})
    </h2>
    <.link
      navigate={~p"/gall/#{@selected_species.id}"}
      class="text-sm text-gf-maroon hover:underline"
    >
      View public page
    </.link>
  </div>
  <div class="flex items-center gap-4">
    <p :if={@images != [] && @view_mode == :grid} class="text-sm text-gray-500">
      Drag to reorder. First image is the default.
    </p>
    <%!-- View Toggle --%>
    <div class="flex border border-gray-300 rounded-md overflow-hidden">
      <button
        type="button"
        phx-click="toggle_view"
        phx-value-view="grid"
        class={[
          "px-3 py-1.5 text-sm",
          @view_mode == :grid && "bg-gf-maroon text-white",
          @view_mode != :grid && "bg-white text-gray-600 hover:bg-gray-50"
        ]}
        title="Grid view"
      >
        <.icon name="ph-squares-four" class="h-4 w-4" />
      </button>
      <button
        type="button"
        phx-click="toggle_view"
        phx-value-view="table"
        class={[
          "px-3 py-1.5 text-sm border-l border-gray-300",
          @view_mode == :table && "bg-gf-maroon text-white",
          @view_mode != :table && "bg-white text-gray-600 hover:bg-gray-50"
        ]}
        title="Table view"
      >
        <.icon name="ph-list" class="h-4 w-4" />
      </button>
    </div>
  </div>
</div>
```

**Step 2: Wrap existing grid in view_mode conditional**

Find the div with `id={"images-version-#{@images_version}"}` (around line 149) and wrap its contents:

```elixir
<div :if={@images != []} id={"images-version-#{@images_version}"}>
  <%!-- Grid View --%>
  <div :if={@view_mode == :grid}>
    <div
      id="sortable-images"
      phx-hook="SortableImages"
      phx-update="ignore"
      class="flex flex-wrap gap-6"
    >
      <%!-- ... existing grid content ... --%>
    </div>
  </div>

  <%!-- Table View (placeholder) --%>
  <div :if={@view_mode == :table} class="text-gray-500 text-center py-8">
    Table view coming soon...
  </div>
</div>
```

**Step 3: Verify in browser**

Run: `mix phx.server`

Navigate to `/admin/images`, select a species, and verify:
- Toggle buttons appear in header
- Clicking toggles between views
- Grid view shows existing functionality
- Table view shows placeholder

**Step 4: Commit**

```bash
git add lib/gallformers_web/live/admin/images_live.ex
git commit -m "$(cat <<'EOF'
Add view toggle UI to admin images

Grid/table toggle buttons in header. Table view placeholder for now.
EOF
)"
```

---

## Task 4: Implement Table View Rendering

**Files:**
- Modify: `lib/gallformers_web/live/admin/images_live.ex`

**Step 1: Replace table placeholder with actual table**

Replace the table view placeholder with:

```elixir
<%!-- Table View --%>
<div :if={@view_mode == :table} class="overflow-x-auto">
  <table class="min-w-full divide-y divide-gray-200">
    <thead class="bg-gray-50">
      <tr>
        <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-[120px]">
          Image
        </th>
        <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-[60px]">
          Def
        </th>
        <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
          Creator
        </th>
        <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
          License
        </th>
        <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
          Source
        </th>
        <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
          Source Link
        </th>
        <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
          License Link
        </th>
        <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
          Attribution
        </th>
        <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
          Caption
        </th>
        <th class="px-3 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider w-[100px]">
          Actions
        </th>
      </tr>
    </thead>
    <tbody class="bg-white divide-y divide-gray-200">
      <tr :for={image <- @images} class="hover:bg-gray-50">
        <td class="px-3 py-2">
          <img
            src={Image.sized_url(image.path, :small)}
            alt={image.caption || "Species image"}
            class="w-20 h-20 object-cover rounded"
          />
        </td>
        <td class="px-3 py-2 text-center">
          <span :if={image.sort_order == 0} class="text-gf-maroon">
            <.icon name="ph-check-circle-fill" class="h-5 w-5" />
          </span>
        </td>
        <td class="px-3 py-2 text-sm text-gray-900">
          {image.creator || <span class="text-gray-400">—</span>}
        </td>
        <td class="px-3 py-2 text-sm text-gray-900">
          {image.license || <span class="text-gray-400">—</span>}
        </td>
        <td class="px-3 py-2 text-sm text-gray-900">
          <%= if image.source do %>
            <.link navigate={~p"/source/#{image.source.id}"} class="text-gf-maroon hover:underline">
              {String.slice(image.source.title || "", 0, 30)}{if String.length(image.source.title || "") > 30, do: "..."}
            </.link>
          <% else %>
            <span class="text-gray-400">—</span>
          <% end %>
        </td>
        <td class="px-3 py-2 text-sm">
          <%= if image.sourcelink && image.sourcelink != "" do %>
            <a
              href={image.sourcelink}
              target="_blank"
              rel="noopener"
              class="text-gf-maroon hover:underline"
              title={image.sourcelink}
            >
              {URI.parse(image.sourcelink).host || String.slice(image.sourcelink, 0, 20)}...
            </a>
          <% else %>
            <span class="text-gray-400">—</span>
          <% end %>
        </td>
        <td class="px-3 py-2 text-sm">
          <%= if image.licenselink && image.licenselink != "" do %>
            <a
              href={image.licenselink}
              target="_blank"
              rel="noopener"
              class="text-gf-maroon hover:underline"
              title={image.licenselink}
            >
              {URI.parse(image.licenselink).host || String.slice(image.licenselink, 0, 20)}...
            </a>
          <% else %>
            <span class="text-gray-400">—</span>
          <% end %>
        </td>
        <td class="px-3 py-2 text-sm text-gray-900 max-w-[150px] truncate" title={image.attribution}>
          {image.attribution || <span class="text-gray-400">—</span>}
        </td>
        <td class="px-3 py-2 text-sm text-gray-900 max-w-[150px] truncate" title={image.caption}>
          {image.caption || <span class="text-gray-400">—</span>}
        </td>
        <td class="px-3 py-2 text-right">
          <div class="flex justify-end gap-2">
            <button
              type="button"
              phx-click="edit_image"
              phx-value-id={image.id}
              class="p-1 text-gray-500 hover:text-gf-maroon"
              title="Edit"
            >
              <.icon name="ph-pencil" class="h-4 w-4" />
            </button>
            <button
              type="button"
              phx-click="confirm_delete"
              phx-value-id={image.id}
              class="p-1 text-gray-500 hover:text-red-600"
              title="Delete"
            >
              <.icon name="ph-trash" class="h-4 w-4" />
            </button>
          </div>
        </td>
      </tr>
    </tbody>
  </table>
</div>
```

**Step 2: Verify in browser**

Run: `mix phx.server`

Navigate to `/admin/images`, select a species with images, switch to table view. Verify:
- Table shows all metadata columns
- Thumbnails display correctly
- Default indicator shows for first image
- Links are clickable
- Edit/Delete buttons work

**Step 3: Commit**

```bash
git add lib/gallformers_web/live/admin/images_live.ex
git commit -m "$(cat <<'EOF'
Implement table view for admin images

Shows all metadata in columns: thumbnail, default, creator, license,
source, source link, license link, attribution, caption. Edit and
delete actions work from table view.
EOF
)"
```

---

## Task 5: Add Copy Mode State

**Files:**
- Modify: `lib/gallformers_web/live/admin/images_live.ex`

**Step 1: Add copy_mode assign to mount**

In `mount/3`, add after the `view_mode` assign:

```elixir
# Copy mode state: nil or %{source_id: id, selected_ids: MapSet.t()}
|> assign(:copy_mode, nil)
```

**Step 2: Add copy mode event handlers**

Add these handlers after the `toggle_view` handler:

```elixir
@impl true
def handle_event("start_copy", %{"id" => id}, socket) do
  source_id = String.to_integer(id)
  copy_mode = %{source_id: source_id, selected_ids: MapSet.new()}
  {:noreply, assign(socket, :copy_mode, copy_mode)}
end

@impl true
def handle_event("cancel_copy", _params, socket) do
  {:noreply, assign(socket, :copy_mode, nil)}
end

@impl true
def handle_event("toggle_copy_target", %{"id" => id}, socket) do
  image_id = String.to_integer(id)
  copy_mode = socket.assigns.copy_mode

  selected_ids =
    if MapSet.member?(copy_mode.selected_ids, image_id) do
      MapSet.delete(copy_mode.selected_ids, image_id)
    else
      MapSet.put(copy_mode.selected_ids, image_id)
    end

  {:noreply, assign(socket, :copy_mode, %{copy_mode | selected_ids: selected_ids})}
end

@impl true
def handle_event("select_all_targets", _params, socket) do
  copy_mode = socket.assigns.copy_mode
  all_target_ids =
    socket.assigns.images
    |> Enum.reject(&(&1.id == copy_mode.source_id))
    |> Enum.map(& &1.id)
    |> MapSet.new()

  # Toggle: if all selected, deselect all; otherwise select all
  selected_ids =
    if MapSet.equal?(copy_mode.selected_ids, all_target_ids) do
      MapSet.new()
    else
      all_target_ids
    end

  {:noreply, assign(socket, :copy_mode, %{copy_mode | selected_ids: selected_ids})}
end
```

**Step 3: Add confirm and execute copy handlers**

```elixir
@impl true
def handle_event("confirm_copy", _params, socket) do
  # Show confirmation modal by setting a flag
  {:noreply, assign(socket, :show_copy_confirm, true)}
end

@impl true
def handle_event("cancel_copy_confirm", _params, socket) do
  {:noreply, assign(socket, :show_copy_confirm, false)}
end

@impl true
def handle_event("execute_copy", _params, socket) do
  copy_mode = socket.assigns.copy_mode
  target_ids = MapSet.to_list(copy_mode.selected_ids)

  updated_by =
    socket.assigns.current_user.name || socket.assigns.current_user.email || "admin"

  case Images.copy_metadata(copy_mode.source_id, target_ids, updated_by) do
    {:ok, count} ->
      images = Images.list_images_for_species(socket.assigns.selected_species.id)

      socket =
        socket
        |> assign(:images, images)
        |> assign(:copy_mode, nil)
        |> assign(:show_copy_confirm, false)
        |> put_flash(:info, "Copied metadata to #{count} image(s)")

      {:noreply, socket}

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Failed to copy metadata: #{inspect(reason)}")}
  end
end
```

**Step 4: Add show_copy_confirm to mount**

In `mount/3`, add:

```elixir
|> assign(:show_copy_confirm, false)
```

**Step 5: Disable view toggle during copy mode**

Update the toggle_view handler to check copy_mode:

```elixir
@impl true
def handle_event("toggle_view", %{"view" => view}, socket) do
  # Don't allow view toggle during copy mode
  if socket.assigns.copy_mode do
    {:noreply, socket}
  else
    view_mode = if view == "table", do: :table, else: :grid
    {:noreply, assign(socket, :view_mode, view_mode)}
  end
end
```

**Step 6: Verify compilation**

Run: `mix compile --warnings-as-errors`

Expected: Compiles without errors

**Step 7: Commit**

```bash
git add lib/gallformers_web/live/admin/images_live.ex
git commit -m "$(cat <<'EOF'
Add copy mode state and event handlers

Handlers for start_copy, cancel_copy, toggle_copy_target,
select_all_targets, confirm_copy, execute_copy. View toggle
disabled during copy mode.
EOF
)"
```

---

## Task 6: Add Copy Mode UI to Table

**Files:**
- Modify: `lib/gallformers_web/live/admin/images_live.ex`

**Step 1: Add checkbox column to table header**

Update the table header (add as first `<th>` after `<tr>`):

```elixir
<th :if={@copy_mode} class="px-3 py-3 text-center w-[50px]">
  <input
    type="checkbox"
    phx-click="select_all_targets"
    checked={all_targets_selected?(@copy_mode, @images)}
    class="rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
  />
</th>
```

**Step 2: Add helper function for select-all state**

Add at the bottom of the module (before the final `end`):

```elixir
defp all_targets_selected?(nil, _images), do: false
defp all_targets_selected?(copy_mode, images) do
  target_ids =
    images
    |> Enum.reject(&(&1.id == copy_mode.source_id))
    |> Enum.map(& &1.id)
    |> MapSet.new()

  MapSet.equal?(copy_mode.selected_ids, target_ids) && MapSet.size(target_ids) > 0
end
```

**Step 3: Update table body rows for copy mode**

Replace the `<tr :for={image <- @images}>` row with:

```elixir
<tr
  :for={image <- @images}
  class={[
    "hover:bg-gray-50",
    @copy_mode && image.id == @copy_mode.source_id && "bg-canary",
    @copy_mode && MapSet.member?(@copy_mode.selected_ids, image.id) && "bg-blue-50"
  ]}
>
  <%!-- Checkbox column (copy mode only) --%>
  <td :if={@copy_mode} class="px-3 py-2 text-center">
    <%= if image.id == @copy_mode.source_id do %>
      <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gf-maroon text-white">
        SRC
      </span>
    <% else %>
      <input
        type="checkbox"
        phx-click="toggle_copy_target"
        phx-value-id={image.id}
        checked={MapSet.member?(@copy_mode.selected_ids, image.id)}
        class="rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
      />
    <% end %>
  </td>
  <%!-- ... rest of columns unchanged ... --%>
```

**Step 4: Update actions column for copy mode**

Replace the actions `<td>` with:

```elixir
<td class="px-3 py-2 text-right">
  <%= if @copy_mode && image.id == @copy_mode.source_id do %>
    <%!-- Source row: Apply/Cancel buttons --%>
    <div class="flex justify-end gap-2">
      <button
        type="button"
        phx-click="confirm_copy"
        disabled={MapSet.size(@copy_mode.selected_ids) == 0}
        class={[
          "px-3 py-1 text-sm rounded",
          MapSet.size(@copy_mode.selected_ids) > 0 && "bg-gf-maroon text-white hover:bg-gf-maroon/90",
          MapSet.size(@copy_mode.selected_ids) == 0 && "bg-gray-200 text-gray-400 cursor-not-allowed"
        ]}
      >
        Apply ({MapSet.size(@copy_mode.selected_ids)})
      </button>
      <button
        type="button"
        phx-click="cancel_copy"
        class="px-3 py-1 text-sm rounded border border-gray-300 text-gray-600 hover:bg-gray-50"
      >
        Cancel
      </button>
    </div>
  <% else %>
    <%!-- Normal row actions (hidden during copy mode for non-source rows) --%>
    <div :if={!@copy_mode} class="flex justify-end gap-2">
      <button
        type="button"
        phx-click="start_copy"
        phx-value-id={image.id}
        class="p-1 text-gray-500 hover:text-gf-maroon"
        title="Copy metadata from this image"
      >
        <.icon name="ph-copy" class="h-4 w-4" />
      </button>
      <button
        type="button"
        phx-click="edit_image"
        phx-value-id={image.id}
        class="p-1 text-gray-500 hover:text-gf-maroon"
        title="Edit"
      >
        <.icon name="ph-pencil" class="h-4 w-4" />
      </button>
      <button
        type="button"
        phx-click="confirm_delete"
        phx-value-id={image.id}
        class="p-1 text-gray-500 hover:text-red-600"
        title="Delete"
      >
        <.icon name="ph-trash" class="h-4 w-4" />
      </button>
    </div>
  <% end %>
</td>
```

**Step 5: Disable view toggle visually during copy mode**

Update the toggle buttons to show disabled state:

```elixir
<button
  type="button"
  phx-click="toggle_view"
  phx-value-view="grid"
  disabled={@copy_mode != nil}
  class={[
    "px-3 py-1.5 text-sm",
    @view_mode == :grid && "bg-gf-maroon text-white",
    @view_mode != :grid && !@copy_mode && "bg-white text-gray-600 hover:bg-gray-50",
    @copy_mode && "bg-gray-100 text-gray-400 cursor-not-allowed"
  ]}
  title="Grid view"
>
  <.icon name="ph-squares-four" class="h-4 w-4" />
</button>
```

(Same for the table toggle button)

**Step 6: Verify in browser**

Navigate to `/admin/images`, select a species with multiple images, switch to table view:
- Click "Copy from" icon on a row
- Verify source row turns yellow with "SRC" badge
- Verify checkboxes appear on other rows
- Verify select all checkbox works
- Verify Apply button shows count and is disabled when 0 selected
- Verify Cancel exits copy mode

**Step 7: Commit**

```bash
git add lib/gallformers_web/live/admin/images_live.ex
git commit -m "$(cat <<'EOF'
Add copy mode UI to table view

Source row highlighted yellow with SRC badge. Checkboxes on other rows.
Apply button shows selected count. Select all checkbox in header.
View toggle disabled during copy mode.
EOF
)"
```

---

## Task 7: Add Copy Confirmation Modal

**Files:**
- Modify: `lib/gallformers_web/live/admin/images_live.ex`

**Step 1: Add confirmation modal**

Add after the View Image Modal (before the closing `</div>` of the main content):

```elixir
<%!-- Copy Confirmation Modal --%>
<.modal
  :if={@show_copy_confirm && @copy_mode}
  id="copy-confirm-modal"
  show
  on_cancel={JS.push("cancel_copy_confirm")}
>
  <:header>Copy Image Metadata</:header>
  <:body>
    <div class="space-y-4">
      <p class="text-gray-600">
        Copy metadata from:
      </p>
      <div class="flex items-center gap-4 p-3 bg-gray-50 rounded-lg">
        <% source_image = Enum.find(@images, &(&1.id == @copy_mode.source_id)) %>
        <img
          :if={source_image}
          src={Image.sized_url(source_image.path, :small)}
          alt="Source image"
          class="w-16 h-16 object-cover rounded"
        />
        <div :if={source_image} class="text-sm">
          <p><strong>Creator:</strong> {source_image.creator || "—"}</p>
          <p><strong>License:</strong> {source_image.license || "—"}</p>
        </div>
      </div>
      <p class="text-gray-600">
        To <strong>{MapSet.size(@copy_mode.selected_ids)}</strong> selected image(s)?
      </p>
      <div class="text-sm text-gray-500 bg-gray-50 p-3 rounded">
        <p class="font-medium mb-1">Fields to be copied:</p>
        <p>Creator, License, License Link, Source Link, Attribution, Caption, Source</p>
      </div>
      <%= if source_image && image_incomplete?(source_image) do %>
        <div class="p-3 bg-orange-50 border border-orange-200 rounded-lg flex items-start gap-3">
          <.icon name="ph-warning" class="h-5 w-5 text-orange-500 flex-shrink-0 mt-0.5" />
          <p class="text-sm text-orange-800">
            Source image is missing some metadata. Empty values will overwrite existing data in target images.
          </p>
        </div>
      <% end %>
    </div>
  </:body>
  <:footer>
    <.button type="button" variant="secondary" phx-click="cancel_copy_confirm">
      Cancel
    </.button>
    <.button type="button" variant="primary" phx-click="execute_copy">
      Copy Metadata
    </.button>
  </:footer>
</.modal>
```

**Step 2: Verify in browser**

Test the full copy workflow:
1. Go to table view
2. Click "Copy from" on an image with metadata
3. Select 2+ target images
4. Click "Apply"
5. Verify confirmation modal shows source preview and count
6. Click "Copy Metadata"
7. Verify success flash and metadata copied

**Step 3: Commit**

```bash
git add lib/gallformers_web/live/admin/images_live.ex
git commit -m "$(cat <<'EOF'
Add copy confirmation modal

Shows source image preview, target count, fields being copied.
Warning if source is missing metadata.
EOF
)"
```

---

## Task 8: Add Escape Key Support for Cancel

**Files:**
- Modify: `lib/gallformers_web/live/admin/images_live.ex`

**Step 1: Add phx-window-keydown handler**

In the table view container div, add:

```elixir
<div
  :if={@view_mode == :table}
  class="overflow-x-auto"
  phx-window-keydown={@copy_mode && "cancel_copy"}
  phx-key={@copy_mode && "Escape"}
>
```

**Step 2: Verify Escape key exits copy mode**

In browser, enter copy mode, press Escape, verify it exits.

**Step 3: Commit**

```bash
git add lib/gallformers_web/live/admin/images_live.ex
git commit -m "$(cat <<'EOF'
Add Escape key support to exit copy mode
EOF
)"
```

---

## Task 9: Final Testing and Cleanup

**Step 1: Run full test suite**

```bash
mix precommit
```

Expected: All tests pass, no warnings

**Step 2: Manual testing checklist**

- [ ] Grid view unchanged (reordering, edit, delete, upload)
- [ ] Table view displays all metadata columns
- [ ] Copy mode: source highlighted yellow
- [ ] Copy mode: checkboxes on other rows
- [ ] Copy mode: select all works
- [ ] Copy mode: Apply disabled when 0 selected
- [ ] Copy mode: Cancel exits
- [ ] Copy mode: Escape exits
- [ ] Copy confirmation modal shows source preview
- [ ] Copy executes and shows success flash
- [ ] Metadata actually copied to targets
- [ ] View toggle disabled during copy mode
- [ ] Warning shown when source missing metadata

**Step 3: Close the bead**

```bash
bd close gallformers-quh7 --reason="Table view with bulk copy metadata implemented"
```

**Step 4: Final commit if any cleanup needed**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Complete admin images table view feature

Closes gallformers-quh7
EOF
)"
```

---

## Summary

| Task | Description | Estimated Steps |
|------|-------------|-----------------|
| 1 | Context function `copy_metadata/3` | 5 |
| 2 | View mode state | 4 |
| 3 | View toggle UI | 4 |
| 4 | Table view rendering | 3 |
| 5 | Copy mode state & handlers | 7 |
| 6 | Copy mode UI in table | 7 |
| 7 | Confirmation modal | 3 |
| 8 | Escape key support | 3 |
| 9 | Final testing | 4 |

Total: ~40 discrete steps
