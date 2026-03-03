defmodule GallformersWeb.Admin.GlossaryLive.Form do
  @moduledoc """
  Admin form for creating and editing glossary entries.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers, crud_helpers: true

  import GallformersWeb.Admin.FormComponents, only: [form_actions: 1]

  alias Gallformers.Glossaries.Glossary

  # Required callbacks for FormHelpers
  @impl GallformersWeb.Admin.FormHelpers
  def entity_key, do: :entry
  @impl GallformersWeb.Admin.FormHelpers
  def entity_struct, do: Gallformers.Glossaries.Glossary
  @impl GallformersWeb.Admin.FormHelpers
  def list_path, do: ~p"/admin/glossary"
  @impl GallformersWeb.Admin.FormHelpers
  def form_key, do: "glossary"
  @impl GallformersWeb.Admin.FormHelpers
  def load_entity(id), do: Gallformers.Glossaries.get_glossary!(id)
  @impl GallformersWeb.Admin.FormHelpers
  def change_entity(entity, params \\ %{}),
    do: Gallformers.Glossaries.change_glossary(entity, params)

  @impl GallformersWeb.Admin.FormHelpers
  def create_entity(params), do: Gallformers.Glossaries.create_glossary(params)
  @impl GallformersWeb.Admin.FormHelpers
  def update_entity(entity, params), do: Gallformers.Glossaries.update_glossary(entity, params)
  @impl GallformersWeb.Admin.FormHelpers
  def delete_entity(entity), do: Gallformers.Glossaries.delete_glossary(entity)

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
  def handle_event("delete", params, socket), do: handle_delete(params, socket)

  @impl true
  def handle_event(event, params, socket)
      when event in ~w(request_cancel cancel_discard confirm_discard) do
    handle_form_event(event, params, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <:page_title_html>
        <%= if @mode == :edit do %>
          Editing <em class="font-bold">{@entry.word}</em>
        <% else %>
          New Glossary Entry
        <% end %>
      </:page_title_html>
      <Layouts.admin_edit_layout
        back_path={~p"/admin/glossary"}
        back_label="Back to Glossary"
        public_url={if @mode == :edit, do: ~p"/glossary"}
      >
        <:intro>
          Glossary entries are automatically linked in species descriptions and other text throughout the site.
          Use lowercase for terms unless they are proper nouns.
        </:intro>

        <.form for={@form} id="glossary-form" phx-change="validate" phx-submit="save">
          <div class="mb-3">
            <.input
              field={@form[:word]}
              schema={Glossary}
              type="text"
              label="Word"
              placeholder="Enter term (lowercase unless proper noun)"
            />
            <p class="mt-1 text-xs text-gray-500">Use lowercase unless it's a proper name</p>
          </div>

          <div class="mb-3">
            <.input
              field={@form[:definition]}
              schema={Glossary}
              type="textarea"
              label="Definition"
              rows="4"
              placeholder="Enter the definition"
            />
          </div>

          <div class="mb-3">
            <.input
              field={@form[:urls]}
              schema={Glossary}
              type="textarea"
              label="Source URLs"
              rows="2"
              placeholder="Enter URLs (one per line)"
            />
            <p class="mt-1 text-xs text-gray-500">
              Enter one URL per line. These are the sources for the definition.
            </p>
          </div>

          <div class="flex justify-between pt-4 border-t border-gray-200">
            <div>
              <button
                :if={@mode == :edit}
                type="button"
                phx-click="delete"
                data-confirm="Are you sure you want to delete this glossary entry?"
                class="gf-btn gf-btn-danger"
              >
                Delete
              </button>
            </div>
            <.form_actions form_dirty={@form_dirty} mode={@mode} create_label="Create Entry" />
          </div>
        </.form>

        <.discard_confirm_modal show={@show_discard_confirm} />
      </Layouts.admin_edit_layout>
    </Layouts.admin>
    """
  end
end
