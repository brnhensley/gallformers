defmodule GallformersWeb.AdminDashboardLive do
  @moduledoc """
  Admin dashboard showing overview statistics and quick actions.
  """

  use GallformersWeb, :live_view

  alias Gallformers.Repo

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Admin Dashboard")
      |> assign_stats()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Admin Dashboard">
      <%!-- Stats Grid --%>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <.stat_card title="Galls" value={@stats.gall_count} icon="gf-gall" href="/admin/galls" />
        <.stat_card title="Hosts" value={@stats.host_count} icon="gf-host" href="/admin/hosts" />
        <.stat_card
          title="Sources"
          value={@stats.source_count}
          icon="gf-source"
          href="/admin/sources"
        />
        <.stat_card title="Images" value={@stats.image_count} icon="ph-image" href="/admin/images" />
      </div>

      <%!-- Welcome --%>
      <div class="mt-6">
        <div class="bg-white rounded-lg border border-gray-200 p-4">
          <p class="text-gray-600 text-lg">
            Welcome to the Gallformers admin panel. If you need help ask in the <a
              href="https://discord.com/channels/1178401400821125122/1180224727978094632"
              target="_blank"
              class="text-gf-maroon hover:underline"
            >Discord</a>.
          </p>
          <p class="text-lg text-red-600 font-bold">
            Note: Admin functionality is being migrated from v1. Some features may not yet be available.
          </p>
        </div>
      </div>

      <%!-- Quick Actions --%>
      <div class="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <.action_card label="Create a New Gall" href="/admin/galls/new" icon="ph-plus-circle" />
        <.action_card label="Create a New Host" href="/admin/hosts/new" icon="ph-plus-circle" />
        <.action_card label="Create a New Source" href="/admin/sources/new" icon="ph-plus-circle" />
        <.action_card label="Create a New Taxon" href="/admin/taxonomy/new" icon="ph-plus-circle" />
        <.action_card
          label="Create a New Glossary Entry"
          href="/admin/glossary/new"
          icon="ph-plus-circle"
        />
        <.action_card label="Create a New Article" href="/admin/articles/new" icon="ph-plus-circle" />
        <%= if Gallformers.Accounts.superadmin?(@current_user) do %>
          <.action_card label="Create a New Place" href="/admin/places/new" icon="ph-plus-circle" />
        <% end %>
        <.action_card
          label="Manage Gall-Host Associations"
          href="/admin/gallhost"
          icon="ph-arrows-left-right"
        />
        <.action_card
          label="Bulk Add Species Descriptions from Sources"
          href="/admin/species-sources/add"
          icon="ph-file-plus"
        />
        <.action_card
          label="Find and Edit Species-Source Mappings"
          href="/admin/species-sources/find"
          icon="ph-magnifying-glass"
        />
      </div>
    </Layouts.admin>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <a
      href={@href}
      class="block bg-white rounded-lg border border-gray-200 p-3 hover:shadow-md transition-shadow"
    >
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <div class="rounded-md bg-gf-maroon/10 p-2">
            <.icon name={@icon} class="h-5 w-5 text-gf-maroon" />
          </div>
        </div>
        <div class="ml-3 w-0 flex-1">
          <dl>
            <dt class="text-xs font-medium text-gray-500 truncate">{@title}</dt>
            <dd class="text-xl font-semibold text-gray-900">{format_number(@value)}</dd>
          </dl>
        </div>
      </div>
    </a>
    """
  end

  defp action_card(assigns) do
    ~H"""
    <a
      href={@href}
      class="flex items-center gap-3 bg-white rounded-lg border border-gray-200 p-4 hover:shadow-md transition-shadow group"
    >
      <.icon name={@icon} class="h-7 w-7 flex-shrink-0 text-gf-maroon group-hover:text-gf-autumn" />
      <span class="text-lg font-medium text-gray-900 group-hover:text-gf-maroon">{@label}</span>
    </a>
    """
  end

  defp assign_stats(socket) do
    stats = %{
      gall_count: count_galls(),
      host_count: count_table("host"),
      source_count: count_table("source"),
      image_count: count_table("image")
    }

    assign(socket, :stats, stats)
  end

  defp count_table(table_name) do
    query = "SELECT COUNT(*) FROM #{table_name}"

    case Repo.query(query) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end

  defp count_galls do
    query = "SELECT COUNT(*) FROM species WHERE taxoncode = 'gall'"

    case Repo.query(query) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(_), do: "0"
end
