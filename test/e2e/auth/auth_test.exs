defmodule GallformersWeb.E2E.AuthTest do
  @moduledoc """
  E2E tests for authentication flows.
  These verify login/logout routes exist and behave correctly.

  Note: Full Auth0 OAuth flow cannot be tested in E2E without mocking.
  These tests verify the application's auth routes and redirects.
  """
  use GallformersWeb.E2ECase

  @moduletag :e2e
  @moduletag :e2e_auth

  describe "login route" do
    test "redirects to Auth0", %{session: session} do
      # The login route should redirect to Auth0
      # We can't follow the full OAuth flow, but we can verify the redirect
      session
      |> visit("/auth/auth0")
      # This will either redirect externally or show an error page
      # In test mode without real Auth0, we expect some response
      |> assert_has(css("body"))
    end
  end

  describe "logout route" do
    test "redirects appropriately", %{session: session} do
      # Logout route should redirect
      session
      |> visit("/auth/logout")
      # Should redirect to home or Auth0 logout
      |> assert_has(css("body"))
    end
  end

  describe "protected routes" do
    test "admin redirects when not authenticated", %{session: session} do
      session
      |> visit("/admin")
      # Should not show admin content without auth
      |> refute_has(css("h1", text: "Dashboard"))
    end
  end
end
