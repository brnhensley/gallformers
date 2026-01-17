defmodule GallformersWeb.Admin.GlossaryLive.Form do
  @moduledoc """
  Admin form for creating and editing glossary entries.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers, crud_helpers: true

  import GallformersWeb.Admin.FormComponents, only: [form_actions: 1]

  # Required callbacks for FormHelpers
  @impl GallformersWeb.Admin.FormHelpers
  def context_module, do: Gallformers.Glossary
  @impl GallformersWeb.Admin.FormHelpers
  def entity_key, do: :entry
  @impl GallformersWeb.Admin.FormHelpers
  def list_path, do: ~p"/admin/glossary"

  # Override because the assign is :entry but params key is "glossary"
  @impl GallformersWeb.Admin.FormHelpers
  def form_key, do: "glossary"

  @impl true
  def mount(_params, session, socket) do
    {:ok, init_admin_form(socket, session, page_title: "Glossary Entry")}
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
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <Layouts.admin_edit_layout
        back_path={~p"/admin/glossary"}
        back_label="Back to Glossary"
        title={if @mode == :new, do: "Add New Glossary Entry", else: "Edit Glossary Entry"}
      >
        <:intro>
          Glossary entries are automatically linked in species descriptions and other text throughout the site.
          Use lowercase for terms unless they are proper nouns.
        </:intro>

        <.form for={@form} id="glossary-form" phx-change="validate" phx-submit="save">
          <div class="mb-3">
            <label class="block text-sm font-medium text-gray-700 mb-1">Word:</label>
            <input
              type="text"
              name={@form[:word].name}
              value={Phoenix.HTML.Form.input_value(@form, :word)}
              placeholder="Enter term (lowercase unless proper noun)"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
            />
            <p class="mt-1 text-xs text-gray-500">Use lowercase unless it's a proper name</p>
          </div>

          <div class="mb-3">
            <label class="block text-sm font-medium text-gray-700 mb-1">Definition:</label>
            <textarea
              name={@form[:definition].name}
              rows="4"
              required
              placeholder="Enter the definition"
              class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
            >{Phoenix.HTML.Form.input_value(@form, :definition)}</textarea>
          </div>

          <div class="mb-3">
            <label class="block text-sm font-medium text-gray-700 mb-1">Source URLs:</label>
            <textarea
              name={@form[:urls].name}
              rows="2"
              required
              placeholder="Enter URLs (one per line)"
              class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
            >{Phoenix.HTML.Form.input_value(@form, :urls)}</textarea>
            <p class="mt-1 text-xs text-gray-500">
              Enter one URL per line. These are the sources for the definition.
            </p>
          </div>

          <div class="flex justify-end pt-4 border-t border-gray-200">
            <.form_actions form_dirty={@form_dirty} mode={@mode} create_label="Create Entry" />
          </div>
        </.form>

        <.discard_confirm_modal show={@show_discard_confirm} />

        <%!-- Live Preview Card --%>
        <% preview_word = get_form_value(@form, :word) %>
        <% preview_definition = get_form_value(@form, :definition) %>
        <% preview_urls = get_form_value(@form, :urls) %>
        <%= if preview_word != "" || preview_definition != "" do %>
          <div class="mt-6 bg-white border border-gray-200 rounded shadow-sm">
            <div class="px-4 py-3 border-b border-gray-200 bg-gray-50">
              <h4 class="text-lg font-semibold text-gf-maroon">Preview</h4>
            </div>
            <div class="p-4">
              <h4 class="font-semibold text-gf-maroon">{preview_word}</h4>
              <p class="mt-2 text-gray-700">{preview_definition}</p>
              <%= if preview_urls && preview_urls != "" do %>
                <div class="mt-4">
                  <h5 class="text-sm font-medium text-gray-500">Sources:</h5>
                  <ul class="mt-1 space-y-1">
                    <li :for={url <- String.split(preview_urls, "\n", trim: true)}>
                      <a
                        href={url}
                        target="_blank"
                        rel="noopener"
                        class="text-sm text-gf-maroon hover:underline"
                      >
                        {truncate_url(url)}
                      </a>
                    </li>
                  </ul>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </Layouts.admin_edit_layout>
    </Layouts.admin>
    """
  end

  defp truncate_url(url) do
    if String.length(url) > 60 do
      String.slice(url, 0, 60) <> "..."
    else
      url
    end
  end

  defp get_form_value(form, field) do
    Ecto.Changeset.get_field(form.source, field) || ""
  end
end
