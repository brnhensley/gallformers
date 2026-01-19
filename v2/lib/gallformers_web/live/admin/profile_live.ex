defmodule GallformersWeb.Admin.ProfileLive do
  @moduledoc """
  LiveView for admins to edit their own profile.

  Displays and allows editing of:
  - Display name (editable)
  - Nickname (read-only, synced from Auth0)
  - iNaturalist URL
  - Social media URL
  - Personal website URL
  - About page visibility toggle
  """

  use GallformersWeb, :live_view
  use GallformersWeb.Admin.FormHelpers

  alias Gallformers.Accounts
  alias Gallformers.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "My Profile")
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
    end
  end

  def close_form(socket) do
    push_navigate(socket, to: ~p"/admin")
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> User.update_changeset(user_params)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:form, to_form(changeset))
      |> mark_dirty()

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        changeset = User.update_changeset(user, %{})

        socket =
          socket
          |> assign(:user, user)
          |> assign(:form, to_form(changeset))
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
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="My Profile">
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
            <div class="mb-4">
              <label
                for={@form[:display_name].name}
                class="block text-sm font-medium text-gray-700 mb-1"
              >
                Display Name
              </label>
              <input
                type="text"
                id={@form[:display_name].id}
                name={@form[:display_name].name}
                value={Phoenix.HTML.Form.input_value(@form, :display_name)}
                placeholder="How you want to be known"
                class="w-full max-w-md px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon"
              />
              <p class="mt-1 text-xs text-gray-500">
                This is how your name will appear on the site
              </p>
            </div>

            <%!-- Nickname (read-only) --%>
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Auth0 Nickname
              </label>
              <input
                type="text"
                value={@current_user.nickname || "Not set"}
                disabled
                class="w-full max-w-md px-3 py-2 border border-gray-200 rounded text-sm bg-gray-50 text-gray-500"
              />
              <p class="mt-1 text-xs text-gray-500">
                This is synced from your Auth0 account and cannot be changed here
              </p>
            </div>

            <%!-- iNaturalist URL --%>
            <div class="mb-4">
              <label
                for={@form[:inaturalist_url].name}
                class="block text-sm font-medium text-gray-700 mb-1"
              >
                iNaturalist Profile URL
              </label>
              <input
                type="url"
                id={@form[:inaturalist_url].id}
                name={@form[:inaturalist_url].name}
                value={Phoenix.HTML.Form.input_value(@form, :inaturalist_url)}
                placeholder="https://www.inaturalist.org/people/yourusername"
                class={[
                  "w-full max-w-md px-3 py-2 border rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon",
                  @form[:inaturalist_url].errors != [] && "border-red-500"
                ]}
              />
              <%= if @form[:inaturalist_url].errors != [] do %>
                <p class="mt-1 text-xs text-red-600">
                  {translate_error(hd(@form[:inaturalist_url].errors))}
                </p>
              <% end %>
            </div>

            <%!-- Social Media URL --%>
            <div class="mb-4">
              <label
                for={@form[:social_url].name}
                class="block text-sm font-medium text-gray-700 mb-1"
              >
                Social Media URL
              </label>
              <input
                type="url"
                id={@form[:social_url].id}
                name={@form[:social_url].name}
                value={Phoenix.HTML.Form.input_value(@form, :social_url)}
                placeholder="https://twitter.com/yourusername"
                class={[
                  "w-full max-w-md px-3 py-2 border rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon",
                  @form[:social_url].errors != [] && "border-red-500"
                ]}
              />
              <p class="mt-1 text-xs text-gray-500">
                Twitter, Mastodon, Bluesky, etc.
              </p>
              <%= if @form[:social_url].errors != [] do %>
                <p class="mt-1 text-xs text-red-600">
                  {translate_error(hd(@form[:social_url].errors))}
                </p>
              <% end %>
            </div>

            <%!-- Personal URL --%>
            <div class="mb-4">
              <label
                for={@form[:personal_url].name}
                class="block text-sm font-medium text-gray-700 mb-1"
              >
                Personal Website URL
              </label>
              <input
                type="url"
                id={@form[:personal_url].id}
                name={@form[:personal_url].name}
                value={Phoenix.HTML.Form.input_value(@form, :personal_url)}
                placeholder="https://yourwebsite.com"
                class={[
                  "w-full max-w-md px-3 py-2 border rounded text-sm focus:outline-none focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon",
                  @form[:personal_url].errors != [] && "border-red-500"
                ]}
              />
              <%= if @form[:personal_url].errors != [] do %>
                <p class="mt-1 text-xs text-red-600">
                  {translate_error(hd(@form[:personal_url].errors))}
                </p>
              <% end %>
            </div>

            <%!-- Show on About Page --%>
            <div class="mb-6">
              <div class="flex items-center">
                <input type="hidden" name={@form[:show_on_about].name} value="false" />
                <input
                  type="checkbox"
                  id={@form[:show_on_about].id}
                  name={@form[:show_on_about].name}
                  value="true"
                  checked={Phoenix.HTML.Form.input_value(@form, :show_on_about) == true}
                  class="h-4 w-4 text-gf-maroon border-gray-300 rounded focus:ring-gf-maroon"
                />
                <label for={@form[:show_on_about].id} class="ml-2 text-sm font-medium text-gray-700">
                  List me on the About page
                </label>
              </div>
              <p class="mt-1 text-xs text-gray-500 ml-6">
                If checked, your display name and profile links will appear in the Administrators
                section of the About page
              </p>
            </div>

            <%!-- Hidden field for checkbox when unchecked --%>
            <input type="hidden" name={@form[:show_on_about].name} value="false" />

            <%!-- Actions --%>
            <div class="flex justify-end gap-3 pt-4 border-t border-gray-200">
              <button
                type="button"
                phx-click="request_cancel"
                class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-4 py-2 bg-gf-maroon text-white rounded-md hover:bg-gf-maroon/90 disabled:opacity-50"
              >
                Save Changes
              </button>
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
