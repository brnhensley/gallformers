defmodule GallformersWeb.AdminImagesLive do
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
      |> assign(:show_upload, false)

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
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold text-gf-maroon">Image Management</h1>
          <.link navigate="/admin" class="text-gf-maroon hover:underline">
            &larr; Back to Dashboard
          </.link>
        </div>

        <%!-- Species Search --%>
        <div class="bg-white rounded-lg border border-gray-200 p-6">
          <h2 class="text-lg font-medium text-gray-900 mb-4">Select Species</h2>
          <div class="relative">
            <form phx-change="search" phx-submit="search" class="flex gap-2">
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search for a species..."
                class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon"
                phx-debounce="300"
              />
            </form>

            <%!-- Search Results Dropdown --%>
            <div
              :if={@search_results != []}
              class="absolute z-10 mt-1 w-full bg-white rounded-md shadow-lg border border-gray-200 max-h-60 overflow-auto"
            >
              <button
                :for={species <- @search_results}
                type="button"
                phx-click="select_species"
                phx-value-id={species.id}
                phx-value-name={species.name}
                class="w-full px-4 py-2 text-left hover:bg-gf-sky-blue/20 flex justify-between items-center"
              >
                <span class="text-gray-900">{species.name}</span>
                <span class="text-sm text-gray-500">{species.image_count} images</span>
              </button>
            </div>
          </div>

          <%!-- Selected Species --%>
          <div :if={@selected_species} class="mt-4 p-4 bg-gf-sky-blue/10 rounded-lg">
            <div class="flex items-center justify-between">
              <div>
                <span class="text-sm text-gray-500">Selected:</span>
                <span class="ml-2 font-medium text-gray-900">{@selected_species.name}</span>
              </div>
              <button
                type="button"
                phx-click="clear_selection"
                class="text-gray-500 hover:text-gray-700"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
            </div>
          </div>
        </div>

        <%!-- Image Management Section --%>
        <div :if={@selected_species} class="space-y-6">
          <%!-- Upload Section --%>
          <div class="bg-white rounded-lg border border-gray-200 p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-medium text-gray-900">Upload Images</h2>
              <button
                type="button"
                phx-click="toggle_upload"
                class="text-gf-maroon hover:text-gf-autumn"
              >
                {if @show_upload, do: "Hide Upload", else: "Show Upload"}
              </button>
            </div>

            <div
              :if={@show_upload}
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
                <.icon name="hero-cloud-arrow-up" class="h-12 w-12 mx-auto text-gray-400" />
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

          <%!-- Image Grid --%>
          <div class="bg-white rounded-lg border border-gray-200 p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-medium text-gray-900">
                Images ({length(@images)})
              </h2>
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
              class="flex flex-wrap gap-4"
            >
              <div
                :for={image <- @images}
                data-image-id={image.id}
                class={[
                  "relative group cursor-move",
                  image.default && "ring-2 ring-gf-maroon ring-offset-2"
                ]}
              >
                <img
                  src={Image.sized_url(image.path, :small)}
                  alt={image.caption || "Species image"}
                  class="w-24 h-24 object-cover rounded"
                />
                <div
                  :if={image.default}
                  class="absolute top-1 left-1 bg-gf-maroon text-white text-xs px-1 rounded"
                >
                  Default
                </div>
                <div class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity rounded flex items-center justify-center gap-2">
                  <button
                    type="button"
                    phx-click="edit_image"
                    phx-value-id={image.id}
                    class="p-1 bg-white rounded text-gray-700 hover:text-gf-maroon"
                    title="Edit"
                  >
                    <.icon name="hero-pencil" class="h-4 w-4" />
                  </button>
                  <button
                    type="button"
                    phx-click="confirm_delete"
                    phx-value-id={image.id}
                    class="p-1 bg-white rounded text-gray-700 hover:text-red-600"
                    title="Delete"
                  >
                    <.icon name="hero-trash" class="h-4 w-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Edit Modal --%>
        <.modal :if={@editing_image} id="edit-modal" show on_cancel={JS.push("cancel_edit")}>
          <:title>Edit Image Metadata</:title>
          <form id="edit-image-form" phx-submit="save_image" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Creator / Photographer
              </label>
              <input
                type="text"
                name="creator"
                value={@editing_image.creator || ""}
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Attribution</label>
              <input
                type="text"
                name="attribution"
                value={@editing_image.attribution || ""}
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">License</label>
              <select
                name="license"
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon"
              >
                <option value="">Select a license</option>
                <option
                  value="Public Domain / CC0"
                  selected={@editing_image.license == "Public Domain / CC0"}
                >
                  Public Domain / CC0
                </option>
                <option value="CC-BY" selected={@editing_image.license == "CC-BY"}>CC-BY</option>
                <option value="CC-BY-SA" selected={@editing_image.license == "CC-BY-SA"}>
                  CC-BY-SA
                </option>
                <option value="CC-BY-NC" selected={@editing_image.license == "CC-BY-NC"}>
                  CC-BY-NC
                </option>
                <option value="CC-BY-NC-SA" selected={@editing_image.license == "CC-BY-NC-SA"}>
                  CC-BY-NC-SA
                </option>
                <option
                  value="All Rights Reserved"
                  selected={@editing_image.license == "All Rights Reserved"}
                >
                  All Rights Reserved
                </option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">License URL</label>
              <input
                type="text"
                name="licenselink"
                value={@editing_image.licenselink || ""}
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Source URL (e.g., iNaturalist)
              </label>
              <input
                type="text"
                name="sourcelink"
                value={@editing_image.sourcelink || ""}
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Caption</label>
              <textarea
                name="caption"
                rows="3"
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon"
              >{@editing_image.caption || ""}</textarea>
            </div>
            <div class="flex items-center gap-2">
              <input
                type="checkbox"
                name="default"
                value="true"
                checked={@editing_image.default}
                id="default-checkbox"
                class="rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
              />
              <label for="default-checkbox" class="text-sm text-gray-700">Set as default image</label>
            </div>
          </form>
          <:actions>
            <button
              type="button"
              phx-click="cancel_edit"
              class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              form="edit-image-form"
              class="px-4 py-2 bg-gf-maroon text-white rounded-md hover:bg-gf-maroon/90"
            >
              Save Changes
            </button>
          </:actions>
        </.modal>

        <%!-- Delete Confirmation Modal --%>
        <.modal :if={@delete_image} id="delete-modal" show on_cancel={JS.push("cancel_delete")}>
          <:title>Delete Image</:title>
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
          <:actions>
            <button
              type="button"
              phx-click="cancel_delete"
              class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="button"
              phx-click="delete_image"
              phx-value-id={@delete_image.id}
              class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
            >
              Delete
            </button>
          </:actions>
        </.modal>
      </div>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    search_results =
      if String.length(query) >= 2 do
        Images.search_species(query)
      else
        []
      end

    {:noreply, assign(socket, search_query: query, search_results: search_results)}
  end

  @impl true
  def handle_event("select_species", %{"id" => id, "name" => name}, socket) do
    species_id = String.to_integer(id)
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
  def handle_event("clear_selection", _params, socket) do
    socket =
      socket
      |> assign(:selected_species, nil)
      |> assign(:images, [])
      |> push_patch(to: ~p"/admin/images")

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_upload", _params, socket) do
    {:noreply, assign(socket, :show_upload, !socket.assigns.show_upload)}
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
    Images.reorder_images(species_id, order)

    # Reload to get updated default status
    images = Images.list_images_for_species(species_id)

    {:noreply, assign(socket, :images, images)}
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
  def handle_event("save_image", params, socket) do
    image = socket.assigns.editing_image

    lastchangedby =
      socket.assigns.current_user["name"] || socket.assigns.current_user["email"] || "admin"

    attrs =
      params
      |> Map.put("lastchangedby", lastchangedby)
      |> Map.put("default", params["default"] == "true")

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
