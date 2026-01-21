defmodule GallformersWeb.Live.UserAuth do
  @moduledoc """
  LiveView on_mount hook for fetching the current user from the session.

  This hook is used by all public LiveViews to make the current user available
  for the layout (header/footer display).
  """

  import Phoenix.Component, only: [assign: 2]

  def on_mount(:fetch_current_user, _params, session, socket) do
    current_user = session["current_user"]
    {:cont, assign(socket, current_user: current_user)}
  end
end
