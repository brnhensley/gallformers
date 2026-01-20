defmodule GallformersWeb.UserProfileLive do
  @moduledoc """
  Public user profile page.

  Displays a user's public profile information including their display name,
  about me text, and profile links. Shows an edit button if the logged-in user
  is viewing their own profile.
  """

  use GallformersWeb, :live_view

  alias Gallformers.Accounts

  @impl true
  def mount(%{"nickname" => nickname}, session, socket) do
    current_user = session["current_user"]

    case Accounts.get_user_by_nickname(nickname) do
      nil ->
        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:page_title, "User Not Found")
         |> assign(:user, nil)}

      user ->
        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:page_title, display_name(user))
         |> assign(:page_description, user.about_me)
         |> assign(:user, user)
         |> assign(:is_own_profile, is_own_profile?(current_user, user))}
    end
  end

  defp is_own_profile?(nil, _user), do: false

  defp is_own_profile?(current_user, user) do
    current_user.id == user.auth0_id
  end

  defp display_name(user) do
    cond do
      user.display_name && user.display_name != "" -> user.display_name
      user.nickname && user.nickname != "" -> user.nickname
      true -> "Anonymous"
    end
  end

  defp has_links?(user) do
    (user.inaturalist_url && user.inaturalist_url != "") ||
      (user.social_url && user.social_url != "") ||
      (user.personal_url && user.personal_url != "")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <%= if @user do %>
        <div class="max-w-2xl mx-auto">
          <div class="bg-white rounded-lg border border-gray-200 p-6">
            <%!-- Header with name and edit button --%>
            <div class="flex items-center justify-between mb-4">
              <h1 class="text-2xl font-bold text-gf-maroon">
                {display_name(@user)}
              </h1>
              <%= if @is_own_profile do %>
                <a
                  href="/admin/profile"
                  class="flex items-center gap-1 text-sm hover:underline"
                  title="Edit profile"
                >
                  <.icon name="ph-pencil-simple" class="h-4 w-4" /> Edit
                </a>
              <% end %>
            </div>

            <%!-- About Me --%>
            <%= if @user.about_me && @user.about_me != "" do %>
              <div class="mb-6">
                <p class="text-gray-700 whitespace-pre-wrap">{@user.about_me}</p>
              </div>
            <% end %>

            <%!-- Profile Links --%>
            <%= if has_links?(@user) do %>
              <div class="flex flex-wrap gap-4 text-sm">
                <%= if @user.inaturalist_url && @user.inaturalist_url != "" do %>
                  <a
                    href={@user.inaturalist_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="hover:underline"
                  >
                    iNaturalist
                  </a>
                <% end %>
                <%= if @user.social_url && @user.social_url != "" do %>
                  <a
                    href={@user.social_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="hover:underline"
                  >
                    Social
                  </a>
                <% end %>
                <%= if @user.personal_url && @user.personal_url != "" do %>
                  <a
                    href={@user.personal_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="hover:underline"
                  >
                    Website
                  </a>
                <% end %>
              </div>
            <% end %>

            <%!-- Empty state if no about_me and no links --%>
            <%= if (!@user.about_me || @user.about_me == "") && !has_links?(@user) do %>
              <p class="text-gray-500 italic">This user hasn't added any profile information yet.</p>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="max-w-2xl mx-auto">
          <div class="bg-white rounded-lg border border-gray-200 p-6 text-center">
            <h1 class="text-2xl font-bold text-gray-700 mb-2">User Not Found</h1>
            <p class="text-gray-500">The user you're looking for doesn't exist.</p>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
