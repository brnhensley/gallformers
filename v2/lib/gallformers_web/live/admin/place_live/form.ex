defmodule GallformersWeb.Admin.PlaceLive.Form do
  @moduledoc """
  Admin form for creating and editing geographic places.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Places
  alias Gallformers.Places.Place

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Place")

    {:ok, socket}
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

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"place" => params}, socket) do
    save_place(socket, socket.assigns.mode, params)
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
      <div class="max-w-2xl">
        <%!-- Back link --%>
        <div class="mb-6">
          <.link navigate={~p"/admin/places"} class="text-gf-maroon hover:underline">
            <.icon name="hero-arrow-left" class="h-4 w-4 inline" /> Back to Places
          </.link>
        </div>

        <%!-- Form Card --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
            <h2 class="text-xl font-semibold text-gf-maroon">
              {if @mode == :new, do: "Add New Place", else: "Edit Place"}
            </h2>
          </div>

          <.form for={@form} id="place-form" phx-change="validate" phx-submit="save" class="p-6">
            <div class="space-y-6">
              <div>
                <.input
                  field={@form[:name]}
                  type="text"
                  label="Name"
                  placeholder="e.g., California, Ontario"
                  required
                />
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <.input
                    field={@form[:code]}
                    type="text"
                    label="Code"
                    placeholder="e.g., CA, ON"
                    required
                  />
                  <p class="mt-1 text-sm text-gray-500">
                    Standard 2-letter postal code
                  </p>
                </div>
                <div>
                  <.input
                    field={@form[:type]}
                    type="select"
                    label="Type"
                    options={Place.place_types()}
                    prompt="Select type"
                    required
                  />
                </div>
              </div>

              <div class="flex justify-end gap-4 pt-4 border-t border-gray-200">
                <.link
                  navigate={~p"/admin/places"}
                  class="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
                >
                  Cancel
                </.link>
                <button
                  type="submit"
                  class="px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-gf-maroon hover:bg-gf-maroon/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon"
                >
                  {if @mode == :new, do: "Create Place", else: "Save Changes"}
                </button>
              </div>
            </div>
          </.form>
        </div>

        <%!-- Help Card --%>
        <div class="mt-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <h3 class="text-sm font-medium text-yellow-800 mb-2">
            <.icon name="hero-exclamation-triangle" class="h-4 w-4 inline mr-1" />
            Limited Functionality
          </h3>
          <p class="text-sm text-yellow-700">
            This is a basic place management page. Place hierarchies (regions containing states) and
            place aggregations are not yet supported in this admin interface. To manage which hosts
            occur in which places (range data), use the Host admin page.
          </p>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
