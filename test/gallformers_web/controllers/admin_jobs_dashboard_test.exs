defmodule GallformersWeb.AdminJobsDashboardTest do
  use GallformersWeb.ConnCase, async: false

  alias Gallformers.Accounts.Auth0User

  test "mounts the admin jobs dashboard route" do
    assert %{plug: Phoenix.LiveView.Plug, route: "/admin/jobs"} =
             Phoenix.Router.route_info(GallformersWeb.Router, "GET", "/admin/jobs", "localhost")
  end

  test "redirects unauthenticated users", %{conn: conn} do
    conn = get(conn, ~p"/admin/jobs")

    assert redirected_to(conn) == "/auth/auth0"
  end

  test "returns 403 for regular admins", %{conn: conn} do
    admin = %Auth0User{
      id: "auth0|admin-jobs",
      email: "admin@test.com",
      name: "Admin User",
      nickname: "admin",
      picture: nil,
      roles: ["admin"]
    }

    conn =
      conn
      |> init_test_session(%{})
      |> put_session(:current_user, admin)
      |> put_session(:db_display_name, "Admin User")

    conn = get(conn, ~p"/admin/jobs")

    assert conn.status == 403
  end
end
