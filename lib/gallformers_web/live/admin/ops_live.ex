defmodule GallformersWeb.Admin.OpsLive do
  @moduledoc """
  Operator-only page for managing site-wide operational settings:
  banner visibility, banner text, and read-only mode.
  """

  use GallformersWeb, :live_view

  alias Gallformers.SiteSettings

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    if connected?(socket), do: SiteSettings.subscribe()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Site Operations")
      |> assign_settings()

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_banner", _params, socket) do
    new_value = !socket.assigns.banner_enabled
    SiteSettings.set("banner_enabled", new_value)
    {:noreply, assign(socket, :banner_enabled, new_value)}
  end

  def handle_event("toggle_read_only", _params, socket) do
    new_value = !socket.assigns.read_only
    SiteSettings.set("read_only", new_value)
    {:noreply, assign(socket, :read_only, new_value)}
  end

  def handle_event("save_banner_text", %{"banner_text" => text}, socket) do
    SiteSettings.set("banner_text", text)

    socket =
      socket
      |> assign(:banner_text, text)
      |> put_flash(:info, "Banner text updated.")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:setting_updated, key, value}, socket) do
    socket =
      case key do
        "banner_enabled" -> assign(socket, :banner_enabled, value)
        "banner_text" -> assign(socket, :banner_text, value)
        "read_only" -> assign(socket, :read_only, value)
        _ -> socket
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title={@page_title}>
      <div class="max-w-2xl mx-auto space-y-8">
        <%!-- Banner Settings --%>
        <.card title="Site Banner" icon="ph-megaphone">
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-700">Banner Enabled</p>
                <p class="text-xs text-gray-500">
                  Show a notification banner at the top of every page.
                </p>
              </div>
              <.toggle
                id="banner-enabled"
                name="banner_enabled"
                checked={@banner_enabled}
                phx-click="toggle_banner"
              />
            </div>

            <form id="banner-text-form" phx-submit="save_banner_text">
              <.input
                id="banner-text"
                name="banner_text"
                type="text"
                label="Banner Text"
                value={@banner_text}
              />
              <div class="mt-3">
                <.button type="submit" phx-disable-with="Saving...">
                  Save Banner Text
                </.button>
              </div>
            </form>
          </div>
        </.card>

        <%!-- Read-Only Mode --%>
        <.card title="Read-Only Mode" icon="ph-lock">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-700">Read-Only Mode</p>
              <p class="text-xs text-gray-500">
                Block all write operations site-wide. Use during maintenance or migrations.
              </p>
            </div>
            <.toggle
              id="read-only"
              name="read_only"
              checked={@read_only}
              phx-click="toggle_read_only"
            />
          </div>
        </.card>
      </div>
    </Layouts.admin>
    """
  end

  defp assign_settings(socket) do
    socket
    |> assign(:banner_enabled, SiteSettings.banner_enabled?())
    |> assign(:banner_text, SiteSettings.banner_text())
    |> assign(:read_only, SiteSettings.read_only?())
  end
end
