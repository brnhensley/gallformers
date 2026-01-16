defmodule GallformersWeb.Admin.GlossaryLive.Form do
  @moduledoc """
  Admin form for creating and editing glossary entries.
  """
  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers

  alias Gallformers.Glossary
  alias Gallformers.Glossary.Glossary, as: GlossaryEntry

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Glossary Entry")
      |> init_form_state()

    {:ok, socket}
  end

  def close_form(socket) do
    push_navigate(socket, to: ~p"/admin/glossary")
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    entry = %GlossaryEntry{}
    changeset = Glossary.change_glossary(entry)

    socket
    |> assign(:page_title, "New Glossary Entry")
    |> assign(:entry, entry)
    |> assign(:form, to_form(changeset))
    |> assign(:mode, :new)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    entry = Glossary.get_glossary!(String.to_integer(id))
    changeset = Glossary.change_glossary(entry)

    socket
    |> assign(:page_title, "Edit Glossary Entry")
    |> assign(:entry, entry)
    |> assign(:form, to_form(changeset))
    |> assign(:mode, :edit)
  end

  @impl true
  def handle_event("validate", %{"glossary" => params}, socket) do
    changeset =
      socket.assigns.entry
      |> Glossary.change_glossary(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:form, to_form(changeset)) |> mark_dirty()}
  end

  @impl true
  def handle_event("save", %{"glossary" => params}, socket) do
    save_entry(socket, socket.assigns.mode, params)
  end

  @impl true
  def handle_event(event, params, socket)
      when event in ~w(request_cancel cancel_discard confirm_discard) do
    handle_form_event(event, params, socket)
  end

  defp save_entry(socket, :new, params) do
    case Glossary.create_glossary(params) do
      {:ok, _entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Glossary entry created successfully")
         |> push_navigate(to: ~p"/admin/glossary")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_entry(socket, :edit, params) do
    case Glossary.update_glossary(socket.assigns.entry, params) do
      {:ok, _entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Glossary entry updated successfully")
         |> push_navigate(to: ~p"/admin/glossary")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
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
              {if @mode == :new, do: "Create Entry", else: "Save Changes"}
            </button>
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
