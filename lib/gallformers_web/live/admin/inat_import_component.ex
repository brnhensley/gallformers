defmodule GallformersWeb.Admin.InatImportComponent do
  @moduledoc """
  LiveComponent for importing images from iNaturalist observations.

  Mounted in the Images Admin upload section. Owns its own lifecycle:
  :idle → :fetching → :picking → :importing → :done
  """

  use GallformersWeb, :live_component

  require Logger

  alias Gallformers.Images
  alias Gallformers.INaturalist
  alias Gallformers.Licenses
  alias Gallformers.Storage

  # -------------------------------------------------------------------
  # Lifecycle
  # -------------------------------------------------------------------

  @impl true
  def mount(socket) do
    {:ok, reset_state(socket)}
  end

  @impl true
  def update(%{fetch_result: result}, socket) do
    case result do
      {:ok, observation} ->
        {:ok,
         socket
         |> assign(:state, :picking)
         |> assign(:observation, observation)
         |> assign(:selected_photo_ids, MapSet.new())
         |> assign(:error, nil)}

      {:error, :not_found} ->
        {:ok, assign(socket, state: :idle, error: "Observation not found.")}

      {:error, _reason} ->
        {:ok,
         assign(socket, state: :idle, error: "Failed to fetch observation. Please try again.")}
    end
  end

  def update(%{import_result: {:done, imported, errors}}, socket) do
    message =
      case {imported, length(errors)} do
        {n, 0} -> "Imported #{n} image(s) successfully."
        {0, e} -> "Failed to import #{e} image(s)."
        {n, e} -> "Imported #{n} image(s). #{e} failed."
      end

    # Notify parent to refresh images
    send(self(), {:inat_import_complete, socket.assigns.species_id})

    {:ok,
     socket
     |> assign(:state, :done)
     |> assign(:error, if(errors != [], do: Enum.join(errors, "; ")))
     |> assign(:done_message, message)}
  end

  def update(%{import_progress: progress}, socket) do
    {:ok, assign(socket, :import_progress, progress)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(:species_id, assigns.species_id)
     |> assign(:uploader, assigns.uploader)
     |> assign(:id, assigns.id)}
  end

  # -------------------------------------------------------------------
  # Render
  # -------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mt-6 border-t border-gray-200 pt-6">
      <h3 class="text-sm font-medium text-gray-700 mb-3">Import from iNaturalist</h3>

      {render_state(assigns)}

      <.error_message
        :if={@error}
        title="Import Error"
        message={@error}
        class="mt-3"
      />
    </div>
    """
  end

  defp render_state(%{state: :idle} = assigns) do
    ~H"""
    <form phx-submit="inat_fetch" phx-target={@myself} class="flex gap-2 items-end">
      <input
        type="text"
        name="url"
        data-role="inat-url-input"
        value={@url_input}
        placeholder="iNaturalist observation URL or ID"
        phx-change="inat_url_changed"
        phx-target={@myself}
        class="gf-input max-w-md"
      />
      <.button
        type="submit"
        data-role="inat-fetch-button"
        disabled={@url_input == ""}
        variant="primary"
      >
        Fetch
      </.button>
    </form>
    """
  end

  defp render_state(%{state: :fetching} = assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <.loading_spinner size="sm" />
      <span class="text-sm text-gray-600">Fetching observation...</span>
      <.button phx-click="inat_cancel" phx-target={@myself} variant="ghost" size="sm">
        Cancel
      </.button>
    </div>
    """
  end

  defp render_state(%{state: :picking} = assigns) do
    ~H"""
    <div>
      <%!-- Observation header --%>
      <div class="mb-4 text-sm text-gray-600">
        <p>
          <span :if={@observation.taxon_name} class="font-medium italic">
            {@observation.taxon_name}
          </span>
          observed by
          <span class="font-medium">
            {INaturalist.format_creator(@observation.observer_login, @observation.observer_name)}
          </span>
          —
          <a href={@observation.url} target="_blank" class="text-gf-maroon hover:underline">
            view on iNaturalist
          </a>
        </p>
      </div>

      <%!-- No photos message --%>
      <div :if={@observation.photos == []} class="text-sm text-gray-500 py-4">
        This observation has no photos.
      </div>

      <%!-- Photo grid --%>
      <div
        :if={@observation.photos != []}
        data-role="inat-photo-grid"
        class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-3 mb-4"
      >
        <label
          :for={photo <- @observation.photos}
          class={[
            "relative cursor-pointer rounded-lg overflow-hidden border-2 transition-colors",
            if(MapSet.member?(@selected_photo_ids, photo.id),
              do: "border-gf-maroon",
              else: "border-gray-200 hover:border-gray-300"
            )
          ]}
        >
          <img
            src={photo.thumbnail_url}
            class="w-full aspect-square object-cover"
            loading="lazy"
          />
          <input
            type="checkbox"
            data-role="inat-photo-checkbox"
            checked={MapSet.member?(@selected_photo_ids, photo.id)}
            phx-click="inat_toggle_photo"
            phx-value-photo-id={photo.id}
            phx-target={@myself}
            class="gf-checkbox absolute top-2 left-2"
          />
          <div
            :if={photo.all_rights_reserved?}
            class="absolute bottom-0 inset-x-0 bg-amber-500/90 text-white text-xs px-2 py-1 text-center"
          >
            All Rights Reserved
          </div>
          <div
            :if={!photo.all_rights_reserved?}
            class="absolute bottom-0 inset-x-0 bg-black/50 text-white text-xs px-2 py-1 text-center"
          >
            {photo.mapped_license}
          </div>
        </label>
      </div>

      <%!-- Action buttons --%>
      <div :if={@observation.photos != []} class="flex gap-2">
        <.button
          phx-click="inat_import"
          phx-target={@myself}
          disabled={MapSet.size(@selected_photo_ids) == 0}
          variant="primary"
          size="sm"
        >
          Import Selected ({MapSet.size(@selected_photo_ids)})
        </.button>
        <.button phx-click="inat_cancel" phx-target={@myself} variant="ghost" size="sm">
          Cancel
        </.button>
      </div>
    </div>
    """
  end

  defp render_state(%{state: :importing} = assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <.loading_spinner size="sm" />
      <span class="text-sm text-gray-600">
        Importing {@import_progress.current} of {@import_progress.total}...
      </span>
    </div>
    """
  end

  defp render_state(%{state: :done} = assigns) do
    ~H"""
    <div class="text-sm">
      <p class="text-green-700 font-medium">{@done_message}</p>
      <.button phx-click="inat_reset" phx-target={@myself} variant="ghost" size="sm" class="mt-2">
        Import another
      </.button>
    </div>
    """
  end

  # -------------------------------------------------------------------
  # Event handlers
  # -------------------------------------------------------------------

  @impl true
  def handle_event("inat_url_changed", %{"url" => value}, socket) do
    {:noreply, assign(socket, :url_input, String.trim(value))}
  end

  def handle_event("inat_fetch", %{"url" => url}, socket) do
    do_fetch(socket, String.trim(url))
  end

  def handle_event("inat_fetch", _params, socket) do
    do_fetch(socket, socket.assigns.url_input)
  end

  def handle_event("inat_cancel", _params, socket) do
    {:noreply, reset_state(socket)}
  end

  def handle_event("inat_toggle_photo", %{"photo-id" => photo_id_str}, socket) do
    photo_id = String.to_integer(photo_id_str)

    selected =
      if MapSet.member?(socket.assigns.selected_photo_ids, photo_id) do
        MapSet.delete(socket.assigns.selected_photo_ids, photo_id)
      else
        MapSet.put(socket.assigns.selected_photo_ids, photo_id)
      end

    {:noreply, assign(socket, :selected_photo_ids, selected)}
  end

  def handle_event("inat_import", _params, socket) do
    selected_ids = socket.assigns.selected_photo_ids
    photos = Enum.filter(socket.assigns.observation.photos, &MapSet.member?(selected_ids, &1.id))
    total = length(photos)

    socket =
      assign(socket,
        state: :importing,
        import_progress: %{current: 0, total: total}
      )

    # Run the import in a background task
    component_id = socket.assigns.id
    species_id = socket.assigns.species_id
    uploader = socket.assigns.uploader
    observation = socket.assigns.observation
    lv = self()

    Gallformers.Async.run(fn ->
      {imported, errors} =
        do_import_photos(photos, species_id, uploader, observation, component_id, lv)

      send_update(lv, __MODULE__, id: component_id, import_result: {:done, imported, errors})
    end)

    {:noreply, socket}
  end

  def handle_event("inat_reset", _params, socket) do
    {:noreply, reset_state(socket)}
  end

  # -------------------------------------------------------------------
  # Private
  # -------------------------------------------------------------------

  defp do_fetch(socket, input) do
    case INaturalist.parse_observation_id(input) do
      {:ok, _id} ->
        socket = assign(socket, state: :fetching, error: nil, url_input: input)
        component_id = socket.assigns.id
        lv = self()

        Gallformers.Async.run(fn ->
          result = INaturalist.fetch_observation(input)
          send_update(lv, __MODULE__, id: component_id, fetch_result: result)
        end)

        {:noreply, socket}

      {:error, :invalid_input} ->
        {:noreply,
         assign(socket, :error, "Please enter a valid iNaturalist observation URL or numeric ID.")}
    end
  end

  defp do_import_photos(photos, species_id, uploader, observation, component_id, lv) do
    total = length(photos)

    photos
    |> Enum.with_index(1)
    |> Enum.reduce({0, []}, fn {photo, index}, acc ->
      send_update(lv, __MODULE__,
        id: component_id,
        import_progress: %{current: index, total: total}
      )

      result = import_single_photo(photo, species_id, uploader, observation)
      # Respect iNat rate limits (~1s between requests)
      if index < total, do: Process.sleep(1_000)
      accumulate_result(acc, result, photo.id)
    end)
  end

  defp accumulate_result({imported, errors}, :ok, _photo_id), do: {imported + 1, errors}

  defp accumulate_result({imported, errors}, {:error, reason}, photo_id),
    do: {imported, errors ++ ["Photo #{photo_id}: #{inspect(reason)}"]}

  defp import_single_photo(photo, species_id, uploader, observation) do
    with {:ok, binary} <- INaturalist.download_photo(photo.original_url),
         path = Storage.generate_path(species_id, extension_from_url(photo.original_url)),
         {:ok, _} <- Storage.upload(path, binary, content_type_from_url(photo.original_url)),
         creator =
           INaturalist.format_creator(observation.observer_login, observation.observer_name),
         {:ok, _image} <-
           Images.finalize_upload(path, species_id, uploader, %{
             creator: creator,
             license: photo.mapped_license,
             licenselink: Licenses.url(photo.mapped_license),
             sourcelink: observation.url
           }) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extension_from_url(url) do
    url
    |> URI.parse()
    |> Map.get(:path, "")
    |> Path.extname()
    |> String.trim_leading(".")
    |> case do
      "" -> "jpg"
      ext -> ext
    end
  end

  defp content_type_from_url(url) do
    case extension_from_url(url) do
      "png" -> "image/png"
      _ -> "image/jpeg"
    end
  end

  defp reset_state(socket) do
    socket
    |> assign(:state, :idle)
    |> assign(:url_input, "")
    |> assign(:error, nil)
    |> assign(:observation, nil)
    |> assign(:selected_photo_ids, MapSet.new())
    |> assign(:import_progress, nil)
    |> assign(:done_message, nil)
  end
end
