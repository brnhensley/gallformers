defmodule GallformersWeb.Admin.FilterTermsLive.Form do
  @moduledoc """
  Admin form for creating and editing filter terms.

  Note: This form uses polymorphic types (different schemas based on filter_type),
  so it doesn't use crud_helpers - the custom logic handles the polymorphism.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers

  import GallformersWeb.Admin.FormComponents, only: [form_actions: 1]

  alias Gallformers.FilterFields

  # Whitelist of valid filter type strings (derived from FilterFields.filter_types/0)
  @valid_filter_type_strings Enum.map(FilterFields.filter_types(), &Atom.to_string/1)

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Filter Term")
      |> init_form_state()

    {:ok, socket}
  end

  def close_form(socket) do
    push_navigate(socket, to: ~p"/admin/filter-terms?type=#{socket.assigns.filter_type}")
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter_type =
      case params["type"] do
        nil -> :alignment
        type when type in @valid_filter_type_strings -> String.to_atom(type)
        _invalid -> nil
      end

    if filter_type && filter_type in FilterFields.filter_types() do
      {:noreply, apply_action(socket, socket.assigns.live_action, params, filter_type)}
    else
      {:noreply, push_navigate(socket, to: ~p"/admin/filter-terms")}
    end
  end

  defp apply_action(socket, :new, _params, filter_type) do
    schema = FilterFields.schema_for(filter_type)
    item = struct(schema)
    changeset = FilterFields.change(filter_type, item)

    socket
    |> assign(:page_title, "New #{FilterFields.singular_label(filter_type)}")
    |> assign(:filter_type, filter_type)
    |> assign(:item, item)
    |> assign(:form, to_form(changeset))
    |> assign(:mode, :new)
  end

  defp apply_action(socket, :edit, %{"id" => id}, filter_type) do
    item = FilterFields.get!(filter_type, String.to_integer(id))
    changeset = FilterFields.change(filter_type, item)
    field_name = FilterFields.field_name_for(filter_type)
    field_value = Map.get(item, field_name)

    socket
    |> assign(:page_title, "Edit #{field_value}")
    |> assign(:filter_type, filter_type)
    |> assign(:item, item)
    |> assign(:form, to_form(changeset))
    |> assign(:mode, :edit)
  end

  @impl true
  def handle_event("validate", %{"filter_field" => params}, socket) do
    changeset =
      socket.assigns.item
      |> FilterFields.change(socket.assigns.filter_type, params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:form, to_form(changeset, as: :filter_field)) |> mark_dirty()}
  end

  @impl true
  def handle_event("save", %{"filter_field" => params}, socket) do
    save_item(socket, socket.assigns.mode, params)
  end

  @impl true
  def handle_event(event, params, socket)
      when event in ~w(request_cancel cancel_discard confirm_discard) do
    handle_form_event(event, params, socket)
  end

  defp save_item(socket, :new, params) do
    filter_type = socket.assigns.filter_type

    case FilterFields.create(filter_type, params) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{FilterFields.singular_label(filter_type)} created successfully")
         |> push_navigate(to: ~p"/admin/filter-terms?type=#{filter_type}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :filter_field))}
    end
  end

  defp save_item(socket, :edit, params) do
    filter_type = socket.assigns.filter_type

    case FilterFields.update(filter_type, socket.assigns.item, params) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{FilterFields.singular_label(filter_type)} updated successfully")
         |> push_navigate(to: ~p"/admin/filter-terms?type=#{filter_type}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :filter_field))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <Layouts.admin_edit_layout
        back_path={~p"/admin/filter-terms?type=#{@filter_type}"}
        back_label={"Back to #{FilterFields.type_label(@filter_type)}"}
        title={
          if @mode == :new,
            do: "Add New #{FilterFields.singular_label(@filter_type)}",
            else: "Edit #{FilterFields.singular_label(@filter_type)}"
        }
      >
        <:intro>
          Filter terms are used by the ID tool to help identify galls.
          Modifying or deleting terms that are in use by existing galls may affect filtering.
        </:intro>

        <.form for={@form} id="filter-field-form" phx-change="validate" phx-submit="save">
          <div class="mb-3">
            <label class="gf-label">
              {FilterFields.singular_label(@filter_type)}:
            </label>
            <input
              type="text"
              name={@form[FilterFields.field_name_for(@filter_type)].name}
              value={Phoenix.HTML.Form.input_value(@form, FilterFields.field_name_for(@filter_type))}
              placeholder={"Enter #{FilterFields.singular_label(@filter_type) |> String.downcase()}"}
              required
              class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
            />
          </div>

          <%= if FilterFields.has_description?(@filter_type) do %>
            <div class="mb-3">
              <.input
                field={@form[:description]}
                type="textarea"
                label="Description:"
                rows="4"
                placeholder="Enter a description explaining this term"
              />
              <p class="mt-1 text-xs text-gray-500">
                A brief explanation of what this term means, shown in the filter guide.
              </p>
            </div>
          <% end %>

          <div class="flex justify-end pt-4 border-t border-gray-200">
            <.form_actions
              form_dirty={@form_dirty}
              mode={@mode}
              create_label={"Create #{FilterFields.singular_label(@filter_type)}"}
            />
          </div>
        </.form>

        <.discard_confirm_modal show={@show_discard_confirm} />
      </Layouts.admin_edit_layout>
    </Layouts.admin>
    """
  end
end
