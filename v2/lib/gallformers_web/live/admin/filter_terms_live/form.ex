defmodule GallformersWeb.Admin.FilterTermsLive.Form do
  @moduledoc """
  Admin form for creating and editing filter terms.
  """
  use GallformersWeb, :live_view

  alias Gallformers.FilterFields

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Filter Term")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter_type =
      case params["type"] do
        nil -> :alignment
        type -> String.to_existing_atom(type)
      end

    if filter_type in FilterFields.filter_types() do
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

    {:noreply, assign(socket, :form, to_form(changeset, as: :filter_field))}
  end

  @impl true
  def handle_event("save", %{"filter_field" => params}, socket) do
    save_item(socket, socket.assigns.mode, params)
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
      <Layouts.admin_form_container
        back_path={~p"/admin/filter-terms?type=#{@filter_type}"}
        back_label={"Back to #{FilterFields.type_label(@filter_type)}"}
        max_width="max-w-2xl"
      >
        <Layouts.form_card title={
          if @mode == :new, do: "Add New #{FilterFields.singular_label(@filter_type)}"
        }>
          <.form
            for={@form}
            id="filter-field-form"
            phx-change="validate"
            phx-submit="save"
            class="p-6"
          >
            <div class="space-y-6">
              <div>
                <.input
                  field={@form[FilterFields.field_name_for(@filter_type)]}
                  type="text"
                  label={FilterFields.singular_label(@filter_type)}
                  placeholder={"Enter #{FilterFields.singular_label(@filter_type) |> String.downcase()}"}
                  class="w-full input text-lg py-3"
                  required
                />
              </div>

              <%= if FilterFields.has_description?(@filter_type) do %>
                <div>
                  <.input
                    field={@form[:description]}
                    type="textarea"
                    label="Description"
                    placeholder="Enter a description explaining this term"
                    rows={4}
                    class="w-full textarea text-lg py-3"
                  />
                  <p class="mt-1 text-sm text-gray-500">
                    A brief explanation of what this term means, shown in the filter guide.
                  </p>
                </div>
              <% end %>

              <div class="flex justify-end gap-4 pt-4 border-t border-gray-200">
                <.link
                  navigate={~p"/admin/filter-terms?type=#{@filter_type}"}
                  class="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
                >
                  Cancel
                </.link>
                <button
                  type="submit"
                  class="px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-gf-maroon hover:bg-gf-maroon/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon"
                >
                  {if @mode == :new,
                    do: "Create #{FilterFields.singular_label(@filter_type)}",
                    else: "Save Changes"}
                </button>
              </div>
            </div>
          </.form>
        </Layouts.form_card>

        <%!-- Help Card --%>
        <div class="mt-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <h3 class="text-sm font-medium text-yellow-800 mb-2">
            <.icon name="hero-exclamation-triangle" class="h-4 w-4 inline mr-1" /> Usage Note
          </h3>
          <p class="text-sm text-yellow-700">
            Filter terms are used by the ID tool to help identify galls. Modifying or deleting
            terms that are in use by existing galls may affect the ID tool's filtering capabilities.
            Consider the impact before making changes.
          </p>
        </div>
      </Layouts.admin_form_container>
    </Layouts.admin>
    """
  end
end
