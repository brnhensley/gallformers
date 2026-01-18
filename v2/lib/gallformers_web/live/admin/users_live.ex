defmodule GallformersWeb.Admin.UsersLive do
  @moduledoc """
  Admin page for superadmins to manage user About page visibility.

  This is a cleanup tool for when someone loses admin access in Auth0
  but their show_on_about flag is still true.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Accounts

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "User Management")
      |> load_users()

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_show_on_about", %{"id" => id}, socket) do
    user = Accounts.get_user(String.to_integer(id))

    case Accounts.update_user(user, %{show_on_about: !user.show_on_about}) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User visibility updated")
         |> load_users()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update user")}
    end
  end

  defp load_users(socket) do
    users = Accounts.list_all_users()
    assign(socket, :users, users)
  end

  defp display_name(%{display_name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{nickname: nickname}) when is_binary(nickname), do: nickname
  defp display_name(_), do: "(no name)"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="User Management">
      <div class="space-y-6">
        <%!-- Info banner --%>
        <div class="gf-admin-info">
          <.icon name="ph-info" class="h-5 w-5 text-blue-400 mr-2 flex-shrink-0" />
          <p>
            Manage which users appear on the About page. Use this to remove users who have
            lost admin access but still have "Show on About" enabled.
          </p>
        </div>

        <%!-- Users table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="gf-table gf-table-dark">
            <thead>
              <tr>
                <th>Display Name</th>
                <th>Nickname</th>
                <th class="text-center">Show on About</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={user <- @users}>
                <td class="font-medium">
                  {display_name(user)}
                </td>
                <td class="text-gray-500">
                  {user.nickname || "-"}
                </td>
                <td class="text-center">
                  <button
                    type="button"
                    phx-click="toggle_show_on_about"
                    phx-value-id={user.id}
                    class={[
                      "relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-gf-maroon focus:ring-offset-2",
                      if(user.show_on_about, do: "bg-gf-maroon", else: "bg-gray-200")
                    ]}
                    role="switch"
                    aria-checked={to_string(user.show_on_about)}
                    aria-label={"Toggle show on about for #{display_name(user)}"}
                  >
                    <span
                      aria-hidden="true"
                      class={[
                        "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                        if(user.show_on_about, do: "translate-x-5", else: "translate-x-0")
                      ]}
                    />
                  </button>
                </td>
              </tr>
              <tr :if={@users == []}>
                <td colspan="3" class="px-6 py-8 text-center text-gray-500">
                  No users found.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-sm text-gray-500">
          Showing {length(@users)} users
        </p>
      </div>
    </Layouts.admin>
    """
  end
end
