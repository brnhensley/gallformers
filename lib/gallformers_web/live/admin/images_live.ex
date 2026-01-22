defmodule GallformersWeb.Admin.ImagesLive do
  @moduledoc """
  Admin LiveView for managing species images.

  Features:
  - Species search and selection
  - Image upload with drag-drop and progress
  - Image grid with reordering
  - Image metadata editing
  - Image deletion with confirmation
  """

  use GallformersWeb, :live_view

  alias Gallformers.Images
  alias Gallformers.Licenses
  alias Gallformers.Species.Image

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Image Management")
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:selected_species, nil)
      |> assign(:images, [])
      |> assign(:editing_image, nil)
      |> assign(:delete_image, nil)
      |> assign(:viewing_image, nil)

    {:ok, socket}
  end

  # License options removed - directly in template now

  @impl true
  def handle_params(params, _uri, socket) do
    case Map.get(params, "species_id") do
      nil ->
        {:noreply, socket}

      species_id ->
        species_id = String.to_integer(species_id)
        images = Images.list_images_for_species(species_id)

        # Get species name
        species_name =
          case Gallformers.Species.get_species(species_id) do
            nil -> "Unknown Species"
            s -> s.name
          end

        socket =
          socket
          |> assign(:selected_species, %{id: species_id, name: species_name})
          |> assign(:images, images)

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Image Management">
      <div class="space-y-6">
        <%!-- Species Search --%>
        <div class="bg-white rounded-lg border border-gray-200 p-6">
          <h2 class="text-lg font-medium text-gray-900 mb-4">Select Species</h2>
          <.typeahead
            id="species-picker"
            label=""
            placeholder="Search for a species..."
            query={@search_query}
            results={@search_results}
            selected={@selected_species}
            search_event="search_species"
            select_event="select_species"
            clear_event="clear_species"
            display_fn={& &1.name}
          >
            <:result :let={species}>
              <div class="flex justify-between items-center w-full">
                <span class="text-gray-900">{species.name}</span>
                <span class="text-sm text-gray-500">{species.image_count} images</span>
              </div>
            </:result>
          </.typeahead>
        </div>

        <%!-- Image Management Section --%>
        <div :if={@selected_species} class="space-y-6">
          <%!-- Image Grid --%>
          <div class="bg-white rounded-lg border border-gray-200 p-6">
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
              <p :if={@images != []} class="text-sm text-gray-500">
                Drag to reorder. First image is the default.
              </p>
            </div>

            <div
              :if={@images == []}
              class="text-center py-8 text-gray-500"
            >
              No images uploaded yet.
            </div>

            <div
              :if={@images != []}
              id="sortable-images"
              phx-hook="SortableImages"
              phx-update="ignore"
              class="flex flex-wrap gap-6"
            >
              <div
                :for={image <- @images}
                data-image-id={image.id}
                class={[
                  "relative group cursor-move",
                  image.sort_order == 0 && "ring-2 ring-gf-maroon ring-offset-2"
                ]}
              >
                <img
                  src={Image.sized_url(image.path, :medium)}
                  alt={image.caption || "Species image"}
                  class="w-48 h-48 object-cover rounded"
                />
                <div
                  :if={image.sort_order == 0}
                  class="absolute top-2 left-2 bg-gf-maroon text-white text-sm px-2 py-1 rounded"
                >
                  Default
                </div>
                <div class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity rounded flex items-center justify-center gap-4">
                  <button
                    type="button"
                    phx-click="view_image"
                    phx-value-id={image.id}
                    class="p-2 bg-white rounded text-gray-700 hover:text-gf-maroon"
                    aria-label="View image"
                  >
                    <.icon name="ph-eye" class="h-6 w-6" />
                  </button>
                  <button
                    type="button"
                    phx-click="edit_image"
                    phx-value-id={image.id}
                    class="p-2 bg-white rounded text-gray-700 hover:text-gf-maroon"
                    aria-label="Edit image"
                  >
                    <.icon name="ph-pencil" class="h-6 w-6" />
                  </button>
                  <button
                    type="button"
                    phx-click="confirm_delete"
                    phx-value-id={image.id}
                    class="p-2 bg-white rounded text-gray-700 hover:text-red-600"
                    aria-label="Delete image"
                  >
                    <.icon name="ph-trash" class="h-6 w-6" />
                  </button>
                </div>
              </div>
            </div>
          </div>

          <%!-- Upload Section --%>
          <div class="bg-white rounded-lg border border-gray-200 p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">Upload Images</h2>

            <div
              id="image-uploader"
              phx-hook="ImageUpload"
              phx-update="ignore"
              data-species-id={@selected_species.id}
              data-max-files="4"
              data-accepted-types="image/jpeg,image/png,image/jpg"
            >
              <%!-- Dropzone --%>
              <div
                data-dropzone
                class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center cursor-pointer hover:border-gf-maroon transition-colors"
              >
                <.icon name="ph-cloud-arrow-up" class="h-12 w-12 mx-auto text-gray-400" />
                <p class="mt-2 text-sm text-gray-600">
                  Drag and drop images here, or click to select
                </p>
                <p class="mt-1 text-xs text-gray-500">
                  Max 4 files. JPG or PNG only.
                </p>
                <input
                  data-file-input
                  type="file"
                  accept="image/jpeg,image/png"
                  multiple
                  class="hidden"
                />
              </div>

              <%!-- Preview Container --%>
              <div data-preview-container class="flex flex-wrap gap-4 mt-4"></div>

              <%!-- Progress Container --%>
              <div data-progress-container class="hidden mt-4"></div>

              <%!-- Upload Button --%>
              <div class="mt-4">
                <button
                  data-upload-button
                  type="button"
                  disabled
                  class="px-4 py-2 bg-gf-maroon text-white rounded-md hover:bg-gf-maroon/90 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Upload Images
                </button>
              </div>
            </div>
          </div>
        </div>

        <%!-- Edit Modal --%>
        <.modal :if={@editing_image} id="edit-modal" show on_cancel={JS.push("cancel_edit")}>
          <:header>Edit Image Metadata</:header>
          <:body>
            <form id="edit-image-form" phx-submit="save_image" class="space-y-4">
              <.input
                type="text"
                name="creator"
                label="Creator / Photographer"
                value={@editing_image.creator || ""}
              />
              <.input
                type="text"
                name="attribution"
                label="Attribution"
                value={@editing_image.attribution || ""}
              />
              <div class="fieldset">
                <label>
                  <span class="label mb-2 text-base font-medium text-gray-700">License</span>
                  <select name="license" class="gf-select" phx-change="update_license">
                    <option value="">Select a license</option>
                    <option
                      :for={license <- Licenses.all()}
                      value={license}
                      selected={license == @editing_image.license}
                    >
                      {license}
                    </option>
                  </select>
                </label>
              </div>
              <.input
                :if={Licenses.url_readonly?(@editing_image.license)}
                type="text"
                name="licenselink"
                label="License URL"
                value={Licenses.url(@editing_image.license)}
                readonly
                class="gf-input bg-gray-50 text-gray-500 cursor-not-allowed"
              />
              <div :if={not Licenses.url_readonly?(@editing_image.license)}>
                <.input
                  type="text"
                  name="licenselink"
                  label="License URL"
                  value={@editing_image.licenselink || Licenses.url(@editing_image.license) || ""}
                  placeholder={
                    if @editing_image.license == "All Rights Reserved",
                      do: "Optional - link to usage terms",
                      else: ""
                  }
                />
                <p
                  :if={@editing_image.license == "Public Domain / CC0"}
                  class="mt-1 text-xs text-gray-500"
                >
                  Defaults to CC0, but can be changed for other public domain references
                </p>
              </div>
              <.input
                type="text"
                name="sourcelink"
                label="Source URL (e.g., iNaturalist)"
                value={@editing_image.sourcelink || ""}
              />
              <.input
                type="textarea"
                name="caption"
                label="Caption"
                rows="3"
                value={@editing_image.caption || ""}
              />
            </form>
          </:body>
          <:footer>
            <.button type="button" variant="secondary" phx-click="cancel_edit">
              Cancel
            </.button>
            <.button type="submit" variant="primary" form="edit-image-form">
              Save Changes
            </.button>
          </:footer>
        </.modal>

        <%!-- Delete Confirmation Modal --%>
        <.modal :if={@delete_image} id="delete-modal" show on_cancel={JS.push("cancel_delete")}>
          <:header>Delete Image</:header>
          <:body>
            <p class="text-gray-600 mb-4">
              Are you sure you want to delete this image? This action cannot be undone.
            </p>
            <div class="flex justify-center mb-4">
              <img
                src={Image.sized_url(@delete_image.path, :medium)}
                alt="Image to delete"
                class="max-w-xs rounded"
              />
            </div>
          </:body>
          <:footer>
            <.button type="button" variant="secondary" phx-click="cancel_delete">
              Cancel
            </.button>
            <.button
              type="button"
              variant="danger"
              phx-click="delete_image"
              phx-value-id={@delete_image.id}
            >
              Delete
            </.button>
          </:footer>
        </.modal>

        <%!-- View Image Modal --%>
        <.modal
          :if={@viewing_image}
          id="view-modal"
          show
          on_cancel={JS.push("cancel_view")}
          class="max-w-7xl"
        >
          <:body>
            <div class="flex justify-center">
              <img
                src={Image.sized_url(@viewing_image.path, :original)}
                alt={@viewing_image.caption || "Species image"}
                class="max-h-[90vh] w-auto object-contain"
              />
            </div>
          </:body>
        </.modal>
      </div>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("search_species", %{"value" => query}, socket) do
    search_results =
      if String.length(query) >= 2 do
        Images.search_species(query)
      else
        []
      end

    {:noreply, assign(socket, search_query: query, search_results: search_results)}
  end

  @impl true
  def handle_event("select_species", %{"id" => id}, socket) do
    species_id = String.to_integer(id)

    # Get the species name from search results
    species_result = Enum.find(socket.assigns.search_results, &(&1.id == species_id))
    name = if species_result, do: species_result.name, else: "Unknown"

    images = Images.list_images_for_species(species_id)

    socket =
      socket
      |> assign(:selected_species, %{id: species_id, name: name})
      |> assign(:images, images)
      |> assign(:search_results, [])
      |> assign(:search_query, "")
      |> push_patch(to: ~p"/admin/images?species_id=#{species_id}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_species", _params, socket) do
    socket =
      socket
      |> assign(:selected_species, nil)
      |> assign(:images, [])
      |> push_patch(to: ~p"/admin/images")

    {:noreply, socket}
  end

  # Handle presigned URL requests from JS hook
  @impl true
  def handle_event("request_presigned_urls", %{"files" => files}, socket) do
    species_id = socket.assigns.selected_species.id

    urls =
      Enum.map(files, fn file ->
        path = Images.generate_path(species_id, file["extension"])

        case Images.presigned_upload_url(path, file["type"]) do
          {:ok, presigned_url} ->
            %{
              path: path,
              presigned_url: presigned_url,
              content_type: file["type"]
            }

          {:error, _reason} ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:noreply, push_event(socket, "presigned_urls", %{urls: urls})}
  end

  # Handle upload completion from JS hook
  @impl true
  def handle_event("uploads_completed", %{"paths" => paths, "species_id" => species_id}, socket) do
    species_id = if is_binary(species_id), do: String.to_integer(species_id), else: species_id

    uploader =
      socket.assigns.current_user["name"] || socket.assigns.current_user["email"] || "admin"

    # Create image records in the database
    Enum.each(paths, fn path ->
      Images.create_image(%{
        species_id: species_id,
        path: path,
        uploader: uploader,
        lastchangedby: uploader,
        default: false
      })

      # Generate size variants in the background
      Task.start(fn ->
        # Wait for CDN to propagate
        Process.sleep(5000)
        Images.generate_size_variants(path)
      end)
    end)

    # Reload images
    images = Images.list_images_for_species(species_id)

    socket =
      socket
      |> assign(:images, images)
      |> push_event("upload_complete", %{
        message: "#{length(paths)} image(s) uploaded successfully"
      })

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_images", _params, socket) do
    case socket.assigns.selected_species do
      nil ->
        {:noreply, socket}

      species ->
        images = Images.list_images_for_species(species.id)
        {:noreply, assign(socket, :images, images)}
    end
  end

  @impl true
  def handle_event("reorder_images", %{"order" => order}, socket) do
    species_id = socket.assigns.selected_species.id

    case Images.reorder_images(species_id, order) do
      :ok ->
        # Don't reload images - the DOM already shows the correct order
        # (via JS manipulation) and the database has been updated.
        # Reloading would trigger a re-render that fights with phx-update="ignore".
        {:noreply, put_flash(socket, :info, "Image order saved")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save image order")}
    end
  end

  @impl true
  def handle_event("edit_image", %{"id" => id}, socket) do
    image = Images.get_image!(String.to_integer(id))
    {:noreply, assign(socket, :editing_image, image)}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_image, nil)}
  end

  @impl true
  def handle_event("view_image", %{"id" => id}, socket) do
    image = Images.get_image!(String.to_integer(id))
    {:noreply, assign(socket, :viewing_image, image)}
  end

  @impl true
  def handle_event("cancel_view", _params, socket) do
    {:noreply, assign(socket, :viewing_image, nil)}
  end

  @impl true
  def handle_event("update_license", %{"license" => license}, socket) do
    # Update both license and licenselink to reflect the new selection
    # For CC licenses, use the canonical URL; for others, use the canonical URL as a starting point
    updated_image = %{
      socket.assigns.editing_image
      | license: license,
        licenselink: Licenses.url(license)
    }

    {:noreply, assign(socket, :editing_image, updated_image)}
  end

  @impl true
  def handle_event("save_image", params, socket) do
    image = socket.assigns.editing_image

    lastchangedby =
      socket.assigns.current_user["name"] || socket.assigns.current_user["email"] || "admin"

    # Use canonical URL for read-only CC licenses, otherwise use the provided value
    # (Public Domain / CC0 allows custom URLs)
    license = params["license"]

    licenselink =
      if Licenses.url_readonly?(license), do: Licenses.url(license), else: params["licenselink"]

    attrs =
      params
      |> Map.put("lastchangedby", lastchangedby)
      |> Map.put("licenselink", licenselink)

    case Images.update_image(image, attrs) do
      {:ok, _updated} ->
        images = Images.list_images_for_species(socket.assigns.selected_species.id)

        socket =
          socket
          |> assign(:images, images)
          |> assign(:editing_image, nil)
          |> put_flash(:info, "Image updated successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update image")}
    end
  end

  @impl true
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    image = Images.get_image!(String.to_integer(id))
    {:noreply, assign(socket, :delete_image, image)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_image, nil)}
  end

  @impl true
  def handle_event("delete_image", %{"id" => id}, socket) do
    image = Images.get_image!(String.to_integer(id))

    case Images.delete_image(image) do
      {:ok, _} ->
        images = Images.list_images_for_species(socket.assigns.selected_species.id)

        socket =
          socket
          |> assign(:images, images)
          |> assign(:delete_image, nil)
          |> put_flash(:info, "Image deleted successfully")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete image: #{inspect(reason)}")}
    end
  end
end
