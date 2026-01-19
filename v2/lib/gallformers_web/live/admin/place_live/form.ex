defmodule GallformersWeb.Admin.PlaceLive.Form do
  @moduledoc """
  Admin form for creating and editing geographic places.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers, crud_helpers: true

  import GallformersWeb.Admin.FormComponents, only: [form_actions: 1]

  alias Gallformers.Places.Place

  # Required callbacks for FormHelpers
  @impl GallformersWeb.Admin.FormHelpers
  def context_module, do: Gallformers.Places
  @impl GallformersWeb.Admin.FormHelpers
  def entity_key, do: :place
  @impl GallformersWeb.Admin.FormHelpers
  def list_path, do: ~p"/admin/places"

  @impl true
  def mount(_params, session, socket) do
    {:ok, init_admin_form(socket, session)}
  end

  def close_form(socket) do
    push_navigate(socket, to: list_path())
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params), do: apply_new_action(socket)
  defp apply_action(socket, :edit, %{"id" => id}), do: apply_edit_action(socket, id)

  @impl true
  def handle_event("validate", params, socket), do: handle_validate(params, socket)

  @impl true
  def handle_event("save", params, socket), do: handle_save(params, socket)

  @impl true
  def handle_event(event, params, socket)
      when event in ~w(request_cancel cancel_discard confirm_discard) do
    handle_form_event(event, params, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      page_title={@page_title}
      public_url={if @mode == :edit, do: ~p"/place/#{@place.id}"}
    >
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
            <.input
              field={@form[:name]}
              type="text"
              label="Name:"
              placeholder="e.g., California, Ontario"
              required
            />
          </div>

          <div class="grid grid-cols-2 gap-4 mb-3">
            <div>
              <.input
                field={@form[:code]}
                type="text"
                label="Code:"
                placeholder="e.g., CA, ON"
                required
              />
              <p class="mt-1 text-xs text-gray-500">Standard 2-letter postal code</p>
            </div>
            <div>
              <.input
                field={@form[:type]}
                type="select"
                label="Type:"
                prompt="Select type"
                options={Enum.map(Place.place_types(), &{&1, &1})}
                required
              />
            </div>
          </div>

          <div class="flex justify-end pt-4 border-t border-gray-200">
            <.form_actions form_dirty={@form_dirty} mode={@mode} create_label="Create Place" />
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
