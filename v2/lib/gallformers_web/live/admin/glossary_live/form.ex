defmodule GallformersWeb.Admin.GlossaryLive.Form do
  @moduledoc """
  Admin form for creating and editing glossary entries.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Glossary
  alias Gallformers.Glossary.Glossary, as: GlossaryEntry

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Glossary Entry")

    {:ok, socket}
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
    |> assign(:page_title, "Edit #{entry.word}")
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

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"glossary" => params}, socket) do
    save_entry(socket, socket.assigns.mode, params)
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
      <div class="max-w-2xl">
        <%!-- Back link --%>
        <div class="mb-6">
          <.link navigate={~p"/admin/glossary"} class="text-gf-maroon hover:underline">
            <.icon name="hero-arrow-left" class="h-4 w-4 inline" /> Back to Glossary
          </.link>
        </div>

        <%!-- Form Card --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
            <h2 class="text-xl font-semibold text-gf-maroon">
              {if @mode == :new, do: "Add New Glossary Entry", else: "Edit Glossary Entry"}
            </h2>
          </div>

          <.form for={@form} id="glossary-form" phx-change="validate" phx-submit="save" class="p-6">
            <div class="space-y-6">
              <div>
                <.input
                  field={@form[:word]}
                  type="text"
                  label="Word"
                  placeholder="Enter term (lowercase unless proper noun)"
                  required
                />
                <p class="mt-1 text-sm text-gray-500">
                  Use lowercase unless it's a proper name
                </p>
              </div>

              <div>
                <.input
                  field={@form[:definition]}
                  type="textarea"
                  label="Definition"
                  placeholder="Enter the definition"
                  rows={4}
                  required
                />
              </div>

              <div>
                <.input
                  field={@form[:urls]}
                  type="textarea"
                  label="Source URLs"
                  placeholder="Enter URLs (one per line)"
                  rows={3}
                  required
                />
                <p class="mt-1 text-sm text-gray-500">
                  Enter one URL per line. These are the sources for the definition.
                </p>
              </div>

              <div class="flex justify-end gap-4 pt-4 border-t border-gray-200">
                <.link
                  navigate={~p"/admin/glossary"}
                  class="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
                >
                  Cancel
                </.link>
                <button
                  type="submit"
                  class="px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-gf-maroon hover:bg-gf-maroon/90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gf-maroon"
                >
                  {if @mode == :new, do: "Create Entry", else: "Save Changes"}
                </button>
              </div>
            </div>
          </.form>
        </div>

        <%!-- Preview Card (when editing) --%>
        <%= if @mode == :edit do %>
          <div class="mt-6 bg-white shadow rounded-lg overflow-hidden">
            <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
              <h3 class="text-lg font-medium text-gray-900">Preview</h3>
            </div>
            <div class="p-6">
              <h4 class="font-semibold text-gf-maroon">{@entry.word}</h4>
              <p class="mt-2 text-gray-700">{@entry.definition}</p>
              <%= if @entry.urls && @entry.urls != "" do %>
                <div class="mt-4">
                  <h5 class="text-sm font-medium text-gray-500">Sources:</h5>
                  <ul class="mt-1 space-y-1">
                    <li :for={url <- String.split(@entry.urls, "\n", trim: true)}>
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
      </div>
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
end
