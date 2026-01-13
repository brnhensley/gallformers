defmodule GallformersWeb.Admin.SourceLive.Form do
  @moduledoc """
  Admin form for creating and editing scientific sources/references.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Sources
  alias Gallformers.Sources.Source

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Source")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    source = %Source{}
    changeset = Sources.change_source(source)

    socket
    |> assign(:page_title, "New Source")
    |> assign(:source, source)
    |> assign(:form, to_form(changeset))
    |> assign(:mode, :new)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    source = Sources.get_source!(String.to_integer(id))
    changeset = Sources.change_source(source)

    socket
    |> assign(:page_title, "Edit Source")
    |> assign(:source, source)
    |> assign(:form, to_form(changeset))
    |> assign(:mode, :edit)
  end

  @impl true
  def handle_event("validate", %{"source" => params}, socket) do
    changeset =
      socket.assigns.source
      |> Sources.change_source(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"source" => params}, socket) do
    save_source(socket, socket.assigns.mode, params)
  end

  defp save_source(socket, :new, params) do
    case Sources.create_source(params) do
      {:ok, _source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Source created successfully")
         |> push_navigate(to: ~p"/admin/sources")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_source(socket, :edit, params) do
    case Sources.update_source(socket.assigns.source, params) do
      {:ok, _source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Source updated successfully")
         |> push_navigate(to: ~p"/admin/sources")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <Layouts.admin_form_container
        back_path={~p"/admin/sources"}
        back_label="Back to Sources"
        max_width="max-w-3xl"
      >
        <Layouts.form_card title={if @mode == :new, do: "Add New Source"}>
          <.form for={@form} id="source-form" phx-change="validate" phx-submit="save" class="p-6">
            <div class="space-y-6">
              <div>
                <.input
                  field={@form[:title]}
                  type="text"
                  label="Title"
                  placeholder="Enter source title"
                  class="w-full input text-lg py-3"
                  required
                />
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <.input
                    field={@form[:author]}
                    type="text"
                    label="Author(s)"
                    placeholder="e.g., Smith, J. and Jones, M."
                    class="w-full input text-lg py-3"
                    required
                  />
                </div>
                <div>
                  <.input
                    field={@form[:pubyear]}
                    type="text"
                    label="Publication Year"
                    placeholder="e.g., 2023"
                    class="w-full input text-lg py-3"
                    required
                  />
                </div>
              </div>

              <div>
                <.input
                  field={@form[:link]}
                  type="url"
                  label="Reference Link"
                  placeholder="https://..."
                  class="w-full input text-lg py-3"
                  required
                />
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <.input
                    field={@form[:license]}
                    type="select"
                    label="License"
                    options={Source.license_types()}
                    prompt="Select license"
                    class="w-full select text-lg py-3"
                    required
                  />
                </div>
                <div>
                  <.input
                    field={@form[:licenselink]}
                    type="url"
                    label="License Link"
                    placeholder="https://creativecommons.org/..."
                    class="w-full input text-lg py-3"
                  />
                  <p class="mt-1 text-xs text-gray-500">
                    Required when using CC BY license
                  </p>
                </div>
              </div>

              <div>
                <.input
                  field={@form[:citation]}
                  type="textarea"
                  label="Citation (MLA format)"
                  placeholder="Enter full citation in MLA format"
                  rows={4}
                  class="w-full textarea text-lg py-3"
                  required
                />
                <p class="mt-1 text-sm text-gray-500">
                  Use
                  <a
                    href="https://www.mybib.com/tools/mla-citation-generator"
                    target="_blank"
                    rel="noopener"
                    class="text-gf-maroon hover:underline"
                  >
                    MLA Citation Generator
                  </a>
                  for help formatting
                </p>
              </div>

              <div class="flex items-center">
                <.input
                  field={@form[:datacomplete]}
                  type="checkbox"
                  label="All information from this source has been entered into the database"
                  class="checkbox"
                />
              </div>

              <div class="flex justify-end gap-4 pt-4 border-t border-gray-200">
                <.link
                  navigate={~p"/admin/sources"}
                  class="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
                >
                  Cancel
                </.link>
                <button
                  type="submit"
                  class="px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-gf-maroon hover:bg-gf-maroon/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon"
                >
                  {if @mode == :new, do: "Create Source", else: "Save Changes"}
                </button>
              </div>
            </div>
          </.form>
        </Layouts.form_card>
      </Layouts.admin_form_container>
    </Layouts.admin>
    """
  end
end
