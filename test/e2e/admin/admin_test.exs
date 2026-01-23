defmodule GallformersWeb.E2E.AdminTest do
  @moduledoc """
  E2E tests for admin functionality.
  These verify that admin pages load and basic CRUD works.

  Note: These tests require authentication. In E2E tests, we use a test
  authentication route to set up the session.
  """
  use GallformersWeb.E2ECase

  @moduletag :e2e
  @moduletag :e2e_admin

  # TODO: Implement test auth route for E2E tests
  # For now, these tests verify that unauthenticated access is properly handled

  describe "admin access control" do
    test "redirects unauthenticated users", %{session: session} do
      # Visiting admin without auth should redirect to Auth0
      # Since we can't follow external OAuth redirect, just verify we don't see admin content
      session
      |> visit("/admin")
      # Should NOT show admin dashboard (would require auth)
      |> refute_has(css("h1", text: "Dashboard"))
    end
  end

  # The following tests require authenticated session setup
  # Uncomment when test auth route is implemented

  # describe "admin dashboard" do
  #   test "loads for authenticated admin", %{session: session} do
  #     session
  #     |> visit("/auth/test/admin")  # Test auth route
  #     |> visit("/admin")
  #     |> assert_has(css(".phx-connected"))
  #     |> assert_has(css("h1", text: "Dashboard"))
  #   end
  # end

  # describe "admin gall management" do
  #   test "can view galls list", %{session: session} do
  #     session
  #     |> visit("/auth/test/admin")
  #     |> visit("/admin/galls")
  #     |> assert_has(css(".phx-connected"))
  #     |> assert_has(css("h1", text: "Galls"))
  #   end
  # end

  # describe "admin host management" do
  #   test "can view hosts list", %{session: session} do
  #     session
  #     |> visit("/auth/test/admin")
  #     |> visit("/admin/hosts")
  #     |> assert_has(css(".phx-connected"))
  #     |> assert_has(css("h1", text: "Hosts"))
  #   end
  # end
end
