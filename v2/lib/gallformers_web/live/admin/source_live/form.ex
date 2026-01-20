defmodule GallformersWeb.Admin.SourceLive.Form do
  @moduledoc """
  Admin form for creating and editing scientific sources/references.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers, crud_helpers: true

  import GallformersWeb.Admin.FormComponents, only: [form_actions: 1]

  alias Gallformers.Licenses
  alias Gallformers.Sources.Source

  # Required callbacks for FormHelpers
  @impl GallformersWeb.Admin.FormHelpers
  def context_module, do: Gallformers.Sources
  @impl GallformersWeb.Admin.FormHelpers
  def entity_key, do: :source
  @impl GallformersWeb.Admin.FormHelpers
  def list_path, do: ~p"/admin/sources"

  # Override to apply canonical license URL for read-only licenses
  @impl GallformersWeb.Admin.FormHelpers
  def prepare_params(params) do
    license = params["license"]

    if Licenses.url_readonly?(license) do
      Map.put(params, "licenselink", Licenses.url(license))
    else
      params
    end
  end

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
      public_url={if @mode == :edit, do: ~p"/source/#{@source.id}"}
    >
      <Layouts.admin_edit_layout
        back_path={~p"/admin/sources"}
        back_label="Back to Sources"
        title={if @mode == :new, do: "Add New Source", else: "Edit Source"}
      >
        <:intro>
          Sources are scientific references and publications. After adding a source, you can
          <.link navigate={~p"/admin/species-sources/add"} class="hover:underline">
            map species to this source
          </.link>
          to add descriptions and external links.
        </:intro>

        <:quick_links :if={@mode == :edit}>
          <.link
            navigate={~p"/admin/species-sources/add?source_id=#{@source.id}"}
            class="text-sm hover:underline"
          >
            Add Species from this Source
          </.link>
        </:quick_links>

        <.form for={@form} id="source-form" phx-change="validate" phx-submit="save">
          <%!-- Row: Title --%>
          <div class="mb-3">
            <label class="gf-label">Title:</label>
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
              <label class="gf-label">Author(s):</label>
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
              <label class="gf-label">Publication Year:</label>
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
            <label class="gf-label">Reference Link:</label>
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
              <.input
                field={@form[:license]}
                type="select"
                label="License:"
                prompt="Select license"
                options={Enum.map(Source.license_types(), &{&1, &1})}
                required
              />
            </div>
            <div>
              <label class="gf-label">License Link:</label>
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
            <.input
              field={@form[:citation]}
              type="textarea"
              label="Citation (MLA format):"
              rows="4"
              placeholder="Enter full citation in MLA format"
              required
            />
            <p class="mt-1 text-xs text-gray-500">
              Use
              <a
                href="https://www.mybib.com/tools/mla-citation-generator"
                target="_blank"
                rel="noopener"
                class="hover:underline"
              >
                MLA Citation Generator
              </a>
              for help formatting
            </p>
          </div>

          <%!-- Row: Data Complete checkbox --%>
          <div class="mb-3">
            <.input
              type="checkbox"
              field={@form[:datacomplete]}
              label="All information from this source has been entered into the database"
            />
          </div>

          <%!-- Buttons --%>
          <div class="flex justify-end pt-4 border-t border-gray-200">
            <.form_actions form_dirty={@form_dirty} mode={@mode} create_label="Create Source" />
          </div>
        </.form>

        <.discard_confirm_modal show={@show_discard_confirm} />
      </Layouts.admin_edit_layout>
    </Layouts.admin>
    """
  end
end
