defmodule GallformersWeb.Admin.SourceLive.Form do
  @moduledoc """
  Admin form for creating and editing scientific sources/references.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers

  alias Gallformers.Licenses
  alias Gallformers.Sources
  alias Gallformers.Sources.Source

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Source")
      |> init_form_state()

    {:ok, socket}
  end

  def close_form(socket) do
    push_navigate(socket, to: ~p"/admin/sources")
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

    {:noreply, socket |> assign(:form, to_form(changeset)) |> mark_dirty()}
  end

  @impl true
  def handle_event("save", %{"source" => params}, socket) do
    save_source(socket, socket.assigns.mode, params)
  end

  @impl true
  def handle_event(event, params, socket)
      when event in ~w(request_cancel cancel_discard confirm_discard) do
    handle_form_event(event, params, socket)
  end

  defp save_source(socket, :new, params) do
    params = maybe_set_canonical_license_url(params)

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
    params = maybe_set_canonical_license_url(params)

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

  defp maybe_set_canonical_license_url(params) do
    license = params["license"]

    # Only force canonical URL for read-only licenses (not Public Domain / CC0)
    if Licenses.url_readonly?(license) do
      Map.put(params, "licenselink", Licenses.url(license))
    else
      params
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <Layouts.admin_edit_layout
        back_path={~p"/admin/sources"}
        back_label="Back to Sources"
        title={if @mode == :new, do: "Add New Source", else: "Edit Source"}
      >
        <:intro>
          Sources are scientific references and publications. After adding a source, you can
          <.link navigate={~p"/admin/species-sources/add"} class="text-gf-maroon hover:underline">
            map species to this source
          </.link>
          to add descriptions and external links.
        </:intro>

        <:quick_links :if={@mode == :edit}>
          <.link
            navigate={~p"/admin/species-sources/add?source_id=#{@source.id}"}
            class="text-sm text-gf-maroon hover:underline"
          >
            Add Species from this Source
          </.link>
        </:quick_links>

        <.form for={@form} id="source-form" phx-change="validate" phx-submit="save">
          <%!-- Row: Title --%>
          <div class="mb-3">
            <label class="block text-sm font-medium text-gray-700 mb-1">Title:</label>
            <input
              type="text"
              name={@form[:title].name}
              value={Phoenix.HTML.Form.input_value(@form, :title)}
              placeholder="Enter source title"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
            />
          </div>

          <%!-- Row: Author | Year --%>
          <div class="grid grid-cols-2 gap-4 mb-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Author(s):</label>
              <input
                type="text"
                name={@form[:author].name}
                value={Phoenix.HTML.Form.input_value(@form, :author)}
                placeholder="e.g., Smith, J. and Jones, M."
                required
                class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Publication Year:</label>
              <input
                type="text"
                name={@form[:pubyear].name}
                value={Phoenix.HTML.Form.input_value(@form, :pubyear)}
                placeholder="e.g., 2023"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              />
            </div>
          </div>

          <%!-- Row: Reference Link --%>
          <div class="mb-3">
            <label class="block text-sm font-medium text-gray-700 mb-1">Reference Link:</label>
            <input
              type="url"
              name={@form[:link].name}
              value={Phoenix.HTML.Form.input_value(@form, :link)}
              placeholder="https://..."
              required
              class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
            />
          </div>

          <%!-- Row: License | License Link --%>
          <% current_license = Phoenix.HTML.Form.input_value(@form, :license) %>
          <div class="grid grid-cols-2 gap-4 mb-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">License:</label>
              <select
                name={@form[:license].name}
                required
                class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              >
                <option value="">Select license</option>
                <option
                  :for={license <- Source.license_types()}
                  value={license}
                  selected={current_license == license}
                >
                  {license}
                </option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">License Link:</label>
              <%= if Licenses.url_readonly?(current_license) do %>
                <input
                  type="url"
                  name={@form[:licenselink].name}
                  value={Licenses.url(current_license)}
                  readonly
                  class="w-full px-3 py-2 border border-gray-300 rounded text-sm bg-gray-100 text-gray-500 cursor-not-allowed"
                />
                <p class="mt-1 text-xs text-gray-500">Auto-filled from license selection</p>
              <% else %>
                <input
                  type="url"
                  name={@form[:licenselink].name}
                  value={
                    Phoenix.HTML.Form.input_value(@form, :licenselink) ||
                      Licenses.url(current_license) || ""
                  }
                  placeholder={
                    if current_license == "All Rights Reserved",
                      do: "Optional - link to usage terms",
                      else: ""
                  }
                  class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
                />
                <p :if={current_license == "Public Domain / CC0"} class="mt-1 text-xs text-gray-500">
                  Defaults to CC0, but can be changed for other public domain references
                </p>
              <% end %>
            </div>
          </div>

          <%!-- Row: Citation --%>
          <div class="mb-3">
            <label class="block text-sm font-medium text-gray-700 mb-1">Citation (MLA format):</label>
            <textarea
              name={@form[:citation].name}
              rows="4"
              required
              placeholder="Enter full citation in MLA format"
              class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
            >{Phoenix.HTML.Form.input_value(@form, :citation)}</textarea>
            <p class="mt-1 text-xs text-gray-500">
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

          <%!-- Row: Data Complete checkbox --%>
          <div class="mb-3">
            <label class="flex items-center gap-2">
              <input
                type="checkbox"
                name={@form[:datacomplete].name}
                value="true"
                checked={Phoenix.HTML.Form.input_value(@form, :datacomplete) == true}
                class="rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
              />
              <span class="text-sm text-gray-700">
                All information from this source has been entered into the database
              </span>
            </label>
          </div>

          <%!-- Buttons --%>
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
              {if @mode == :new, do: "Create Source", else: "Save Changes"}
            </button>
          </div>
        </.form>

        <.discard_confirm_modal show={@show_discard_confirm} />
      </Layouts.admin_edit_layout>
    </Layouts.admin>
    """
  end
end
