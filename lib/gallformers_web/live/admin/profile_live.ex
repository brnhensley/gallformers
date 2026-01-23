defmodule GallformersWeb.Admin.ProfileLive do
  @moduledoc """
  LiveView for admins to edit their own profile.

  Displays and allows editing of:
  - Display name (editable)
  - Nickname (read-only, synced from Auth0)
  - About me bio text
  - iNaturalist URL
  - Social media URL
  - Personal website URL
  - About page visibility toggle
  """

  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers

  import GallformersWeb.Admin.FormComponents, only: [form_actions: 1]

  alias Gallformers.Accounts
  alias Gallformers.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "My Profile")
      |> assign(:mode, :edit)
      |> init_form_state()
      |> load_user_profile()

    {:ok, socket}
  end

  defp load_user_profile(socket) do
    auth0_user = socket.assigns.current_user

    case Accounts.get_user_by_auth0_id(auth0_user.id) do
      nil ->
        # This shouldn't happen - login flow creates user records
        # But handle gracefully by showing an error
        socket
        |> put_flash(:error, "Profile not found. Please log out and log back in.")
        |> assign(:user, nil)
        |> assign(:form, nil)

      %User{} = user ->
        changeset = User.update_changeset(user, %{})

        socket
        |> assign(:user, user)
        |> assign(:form, to_form(changeset))
        |> assign(:inat_username, extract_inat_username(user.inaturalist_url))
    end
  end

  @inat_url_pattern ~r{^https?://(?:www\.)?inaturalist\.org/people/([^/\s?]+)}

  defp extract_inat_username(nil), do: ""
  defp extract_inat_username(""), do: ""

  defp extract_inat_username(url) do
    case Regex.run(@inat_url_pattern, url) do
      [_, username] -> username
      _ -> ""
    end
  end

  defp build_inat_url(""), do: nil
  defp build_inat_url(nil), do: nil
  defp build_inat_url(username), do: "https://www.inaturalist.org/people/#{username}"

  def close_form(socket) do
    push_navigate(socket, to: ~p"/admin")
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    # Handle inat_username separately - it's not a real form field
    inat_username = Map.get(user_params, "inat_username", socket.assigns.inat_username)

    # Convert username to URL for the changeset
    user_params = Map.put(user_params, "inaturalist_url", build_inat_url(inat_username))

    changeset =
      socket.assigns.user
      |> User.update_changeset(user_params)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:form, to_form(changeset))
      |> assign(:inat_username, inat_username)
      |> mark_dirty()

    {:noreply, socket}
  end

  # Catch-all for validate events that don't match the expected form structure
  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    # Convert inat_username to URL
    inat_username = Map.get(user_params, "inat_username", "")
    user_params = Map.put(user_params, "inaturalist_url", build_inat_url(inat_username))

    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        changeset = User.update_changeset(user, %{})

        socket =
          socket
          |> assign(:user, user)
          |> assign(:form, to_form(changeset))
          |> assign(:inat_username, extract_inat_username(user.inaturalist_url))
          |> assign(:form_dirty, false)
          |> put_flash(:info, "Profile updated successfully")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

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
      public_url={if @user && @user.nickname, do: ~p"/user/#{@user.nickname}"}
    >
      <Layouts.admin_edit_layout
        back_path={~p"/admin"}
        back_label="Back to Dashboard"
        title="Edit Profile"
      >
        <:intro>
          Update your profile information. Your display name and profile links will be visible
          on the About page if you opt in below.
        </:intro>

        <%= if @form do %>
          <.form for={@form} id="profile-form" phx-change="validate" phx-submit="save">
            <%!-- Display Name --%>
            <div class="mb-3">
              <label class="gf-label">Display Name:</label>
              <input
                type="text"
                name={@form[:display_name].name}
                value={Phoenix.HTML.Form.input_value(@form, :display_name)}
                placeholder="How you want to be known"
                class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              />
            </div>

            <%!-- Nickname (read-only, from Auth0) --%>
            <div class="mb-3">
              <label class="gf-label">Auth0 Nickname:</label>
              <input
                type="text"
                value={@current_user.nickname || "Not set"}
                disabled
                class="w-full px-3 py-2 bg-gray-100 border border-gray-300 rounded text-gray-500 text-sm"
              />
              <p class="mt-1 text-xs text-gray-500">
                Synced from your Auth0 account and cannot be changed here
              </p>
            </div>

            <%!-- About Me --%>
            <div class="mb-3">
              <.input
                field={@form[:about_me]}
                type="textarea"
                label="About Me:"
                rows="4"
                placeholder="Tell us a bit about yourself..."
              />
            </div>

            <%!-- iNaturalist Username --%>
            <div class="mb-3">
              <label class="gf-label">iNaturalist Username:</label>
              <div class="flex items-center">
                <span class="px-3 py-2 bg-gray-100 border border-r-0 border-gray-300 rounded-l text-sm text-gray-500">
                  inaturalist.org/people/
                </span>
                <input
                  type="text"
                  name="user[inat_username]"
                  value={@inat_username}
                  placeholder="yourusername"
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-r text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
                />
              </div>
              <p class="mt-1 text-xs text-gray-500">
                Just enter your username, not the full URL
              </p>
            </div>

            <%!-- Social Media URL --%>
            <div class="mb-3">
              <label class="gf-label">Social Media URL:</label>
              <input
                type="url"
                name={@form[:social_url].name}
                value={Phoenix.HTML.Form.input_value(@form, :social_url)}
                placeholder="https://twitter.com/yourusername"
                class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              />
            </div>

            <%!-- Personal Website URL --%>
            <div class="mb-3">
              <label class="gf-label">
                Personal Website URL:
              </label>
              <input
                type="url"
                name={@form[:personal_url].name}
                value={Phoenix.HTML.Form.input_value(@form, :personal_url)}
                placeholder="https://yourwebsite.com"
                class="w-full px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              />
            </div>

            <%!-- Show on About Page --%>
            <div class="mb-3">
              <.input type="checkbox" field={@form[:show_on_about]} label="List me on the About page" />
            </div>

            <%!-- Buttons --%>
            <div class="flex justify-end pt-4 border-t border-gray-200">
              <.form_actions form_dirty={@form_dirty} mode={@mode} />
            </div>
          </.form>

          <.discard_confirm_modal show={@show_discard_confirm} />
        <% else %>
          <div class="p-4 bg-red-50 border border-red-200 rounded">
            <p class="text-red-700">
              Unable to load your profile. Please try logging out and logging back in.
            </p>
          </div>
        <% end %>
      </Layouts.admin_edit_layout>
    </Layouts.admin>
    """
  end
end
