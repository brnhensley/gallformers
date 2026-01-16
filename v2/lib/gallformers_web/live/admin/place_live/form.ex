defmodule GallformersWeb.Admin.PlaceLive.Form do
  @moduledoc """
  Admin form for creating and editing geographic places.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers

  alias Gallformers.Places
  alias Gallformers.Places.Place

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Place")
      |> init_form_state()

    {:ok, socket}
  end

  def close_form(socket) do
    push_navigate(socket, to: ~p"/admin/places")
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    place = %Place{}
    changeset = Places.change_place(place)

    socket
    |> assign(:page_title, "New Place")
    |> assign(:place, place)
    |> assign(:form, to_form(changeset))
    |> assign(:mode, :new)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    place = Places.get_place!(String.to_integer(id))
    changeset = Places.change_place(place)

    socket
    |> assign(:page_title, "Edit #{place.name}")
    |> assign(:place, place)
    |> assign(:form, to_form(changeset))
    |> assign(:mode, :edit)
  end

  @impl true
  def handle_event("validate", %{"place" => params}, socket) do
    changeset =
      socket.assigns.place
      |> Places.change_place(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:form, to_form(changeset)) |> mark_dirty()}
  end

  @impl true
  def handle_event("save", %{"place" => params}, socket) do
    save_place(socket, socket.assigns.mode, params)
  end

  @impl true
  def handle_event(event, params, socket)
      when event in ~w(request_cancel cancel_discard confirm_discard) do
    handle_form_event(event, params, socket)
  end

  defp save_place(socket, :new, params) do
    case Places.create_place(params) do
      {:ok, _place} ->
        {:noreply,
         socket
         |> put_flash(:info, "Place created successfully")
         |> push_navigate(to: ~p"/admin/places")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_place(socket, :edit, params) do
    case Places.update_place(socket.assigns.place, params) do
      {:ok, _place} ->
        {:noreply,
         socket
         |> put_flash(:info, "Place updated successfully")
         |> push_navigate(to: ~p"/admin/places")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <Layouts.admin_edit_layout
        back_path={~p"/admin/places"}
        back_label="Back to Places"
        title={if @mode == :new, do: "Add New Place", else: "Edit Place"}
      >
        <:intro>
          Places represent geographic regions (states, provinces) used for range data.
          To manage which hosts occur in which places, use the Host admin page.
        </:intro>

        <.form for={@form} id="place-form" phx-change="validate" phx-submit="save">
          <div class="mb-3">
            <label class="block text-sm font-medium text-gray-700 mb-1">Name:</label>
            <input
              type="text"
              name={@form[:name].name}
              value={Phoenix.HTML.Form.input_value(@form, :name)}
              placeholder="e.g., California, Ontario"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
            />
          </div>

          <div class="grid grid-cols-2 gap-4 mb-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Code:</label>
              <input
                type="text"
                name={@form[:code].name}
                value={Phoenix.HTML.Form.input_value(@form, :code)}
                placeholder="e.g., CA, ON"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              />
              <p class="mt-1 text-xs text-gray-500">Standard 2-letter postal code</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Type:</label>
              <select
                name={@form[:type].name}
                required
                class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              >
                <option value="">Select type</option>
                <option
                  :for={type <- Place.place_types()}
                  value={type}
                  selected={Phoenix.HTML.Form.input_value(@form, :type) == type}
                >
                  {type}
                </option>
              </select>
            </div>
          </div>

          <div class="flex justify-end gap-2 pt-4 border-t border-gray-200">
            <button
              type="button"
              phx-click="request_cancel"
              class="px-4 py-2 text-sm bg-gray-200 hover:bg-gray-300 border border-gray-300 rounded"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={not @form_dirty}
              class={[
                "px-4 py-2 text-sm rounded",
                if(@form_dirty,
                  do: "text-white bg-gf-maroon hover:bg-gf-maroon/90",
                  else: "bg-gray-300 text-gray-500 cursor-not-allowed"
                )
              ]}
            >
              {if @mode == :new, do: "Create Place", else: "Save Changes"}
            </button>
          </div>
        </.form>

        <.discard_confirm_modal show={@show_discard_confirm} />

        <%!-- Help Card --%>
        <div class="mt-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <h3 class="text-sm font-medium text-yellow-800 mb-2">
            <.icon name="ph-warning" class="h-4 w-4 inline mr-1" /> Limited Functionality
          </h3>
          <p class="text-sm text-yellow-700">
            This is a basic place management page. Place hierarchies (regions containing states) and
            place aggregations are not yet supported in this admin interface.
          </p>
        </div>
      </Layouts.admin_edit_layout>
    </Layouts.admin>
    """
  end
end
