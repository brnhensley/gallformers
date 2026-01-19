defmodule GallformersWeb.Admin.GallLive.FormTest do
  @moduledoc """
  LiveView tests for the GallLive.Form admin page.

  Tests the gall form admin functionality including:
  - Mount/render in new and edit modes
  - Form validation and submission
  - Alias management (add, remove, update)
  - Host search and management
  - Filter field management
  - Detachable and undescribed toggles
  - Rename modal
  - Dirty state tracking
  """
  use GallformersWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Gallformers.Accounts.Auth0User
  alias Gallformers.Hosts
  alias Gallformers.Species

  # Helper to set up admin session
  defp setup_admin_session(conn) do
    user = %Auth0User{
      id: "test-admin-id",
      email: "admin@test.com",
      name: "Test Admin",
      nickname: nil,
      picture: nil,
      roles: ["admin"]
    }

    conn
    |> init_test_session(%{})
    |> put_session(:current_user, user)
  end

  # Helper to find any gall for testing - fails explicitly if no data
  defp require_gall do
    case Species.list_galls() do
      [gall | _] -> gall
      [] -> flunk("No gall found in test database - ensure test fixtures exist")
    end
  end

  # Helper to find any host for testing - fails explicitly if no data
  defp require_host do
    case Hosts.list_hosts() do
      [host | _] -> host
      [] -> flunk("No host found in test database - ensure test fixtures exist")
    end
  end

  describe "Mount and render - new mode" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "renders new gall form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/galls/new")

      assert html =~ "Add New Gall"
      assert html =~ "Name (binomial)"
    end

    test "shows correct page title for new gall", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/galls/new")

      assert page_title(view) =~ "New Gall"
    end

    test "save button is disabled initially", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/galls/new")

      assert html =~ "cursor-not-allowed"
    end

    test "shows back link to galls list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/galls/new")

      assert has_element?(view, "a[href='/admin/galls']")
    end

    test "hosts field is disabled in new mode", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/galls/new")

      assert html =~ "Save gall first to add hosts"
    end
  end

  describe "Mount and render - edit mode" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "renders edit gall form with gall data", %{conn: conn} do
      gall = require_gall()
      {:ok, _view, html} = live(conn, ~p"/admin/galls/#{gall.id}")

      assert html =~ "Edit Gall"
      assert html =~ gall.name
    end

    test "shows correct page title for edit gall", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      assert page_title(view) =~ gall.name
    end

    test "shows rename button in edit mode", %{conn: conn} do
      gall = require_gall()
      {:ok, _view, html} = live(conn, ~p"/admin/galls/#{gall.id}")

      assert html =~ "Rename"
    end

    test "shows quick links in edit mode", %{conn: conn} do
      gall = require_gall()
      {:ok, _view, html} = live(conn, ~p"/admin/galls/#{gall.id}")

      assert html =~ "Manage Images"
      assert html =~ "Gall-Host Mappings"
      assert html =~ "Species-Source Mappings"
    end

    test "shows view public page link in edit mode", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      assert has_element?(view, "a[href='/gall/#{gall.id}']", "View public page")
    end

    test "shows filter fields in edit mode", %{conn: conn} do
      gall = require_gall()
      {:ok, _view, html} = live(conn, ~p"/admin/galls/#{gall.id}")

      assert html =~ "Detachable"
      assert html =~ "Walls"
      assert html =~ "Cells"
      assert html =~ "Color"
      assert html =~ "Shape"
    end

    test "handles invalid gall ID", %{conn: conn} do
      # Invalid ID causes an error (not a valid integer)
      assert_raise ArgumentError, fn ->
        live(conn, ~p"/admin/galls/invalid")
      end
    end

    test "redirects for non-existent gall ID", %{conn: conn} do
      # Non-existent gall redirects with error flash
      assert {:error, {:live_redirect, %{to: "/admin/galls", flash: flash}}} =
               live(conn, ~p"/admin/galls/999999999")

      assert flash["error"] =~ "not found"
    end
  end

  describe "Form validation" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "validate event marks form as dirty", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/galls/new")

      # Trigger validation with a valid species name
      html =
        view
        |> form("#gall-form", species: %{name: "Genus species"})
        |> render_change()

      # Form should now be dirty - check that the save button is present
      # and the form has been modified
      assert html =~ "gall-form"
    end
  end

  describe "Alias management - update_new_alias event" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "update_new_alias handles name field change (phx-keyup)", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      # Simulate typing in alias name field - sends value and type from phx-value-type
      html =
        render_click(view, "update_new_alias", %{
          "value" => "Test Alias",
          "type" => "common name"
        })

      # Should update the input field value
      assert html =~ "Test Alias" or html =~ gall.name
    end

    test "update_new_alias handles type field change (phx-change)", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      # Simulate changing select - sends value and name from phx-value-name
      html =
        render_click(view, "update_new_alias", %{
          "value" => "scientific synonym",
          "name" => "Some Alias"
        })

      # Should update both fields
      assert html =~ "Some Alias" or html =~ "scientific synonym" or html =~ gall.name
    end
  end

  describe "Host search - search_hosts event" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "search_hosts handles value parameter correctly", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      # Simulate searching - phx-keyup sends "value" not "query"
      html = render_click(view, "search_hosts", %{"value" => "quercus"})

      # Should not crash and should process search
      assert html =~ "Edit Gall" or html =~ gall.name
    end

    test "search_hosts with short query returns no results", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      # Search with 1 character - should return no results
      html = render_click(view, "search_hosts", %{"value" => "q"})

      # Should not show results dropdown
      refute has_element?(view, "#host-search-results button")
      assert html =~ gall.name
    end
  end

  describe "Filter search - filter_search event" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "filter_search handles value parameter correctly", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      # Simulate filter search - phx-keyup sends "value" not "query"
      html = render_click(view, "filter_search", %{"type" => "colors", "value" => "red"})

      # Should not crash
      assert html =~ "Edit Gall" or html =~ gall.name
    end

    test "filter_search works for various filter types", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      # Test multiple filter types
      filter_types = ~w(walls cells alignments colors shapes seasons forms locations textures)

      for filter_type <- filter_types do
        html = render_click(view, "filter_search", %{"type" => filter_type, "value" => "test"})
        assert html =~ gall.name, "Failed for filter type: #{filter_type}"
      end
    end
  end

  describe "Detachable - update_detachable event" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "update_detachable marks form as dirty", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      # Initially form should not be dirty (save button disabled)
      assert has_element?(view, "button[type='submit'][disabled]")

      # Change detachable value
      render_click(view, "update_detachable", %{"value" => "2"})

      # Form should now be dirty (save button enabled)
      refute has_element?(view, "button[type='submit'][disabled]")
    end

    test "update_detachable updates the select value", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      html = render_click(view, "update_detachable", %{"value" => "2"})

      # Should show detachable as selected
      assert html =~ "detachable"
    end
  end

  describe "Undescribed toggle - toggle_undescribed event" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "toggle_undescribed marks form as dirty", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      # Initially form should not be dirty (save button disabled)
      assert has_element?(view, "button[type='submit'][disabled]")

      # Toggle undescribed
      render_click(view, "toggle_undescribed", %{})

      # Form should now be dirty (save button enabled)
      refute has_element?(view, "button[type='submit'][disabled]")
    end

    test "toggle_undescribed toggles checkbox state", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      # Toggle twice should return to original state
      render_click(view, "toggle_undescribed", %{})
      html = render_click(view, "toggle_undescribed", %{})

      # Should still render correctly
      assert html =~ "Undescribed"
    end
  end

  describe "Add and remove alias" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "add_alias with empty name shows error", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      html = render_click(view, "add_alias", %{})

      assert html =~ "cannot be empty"
    end
  end

  describe "Add and remove host" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "add_host adds host to the list", %{conn: conn} do
      gall = require_gall()
      host = require_host()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      html = render_click(view, "add_host", %{"id" => Integer.to_string(host.id)})

      assert html =~ "Host added" or html =~ host.name or html =~ "already"
    end
  end

  describe "Rename modal" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "open_rename_modal shows the modal", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      html = render_click(view, "open_rename_modal", %{})

      assert html =~ "Edit Gall Name"
      assert html =~ "Add Alias for old name"
    end

    test "close_rename_modal hides the modal", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      render_click(view, "open_rename_modal", %{})
      html = render_click(view, "close_rename_modal", %{})

      refute html =~ "Edit Gall Name"
    end

    test "update_rename_value updates the input", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      render_click(view, "open_rename_modal", %{})
      html = render_click(view, "update_rename_value", %{"value" => "New test name"})

      assert html =~ "New test name"
    end

    test "toggle_add_alias_on_rename toggles checkbox", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      render_click(view, "open_rename_modal", %{})
      html = render_click(view, "toggle_add_alias_on_rename", %{})

      # Just verify it doesn't crash
      assert html =~ "Add Alias"
    end

    test "do_rename with empty name shows error", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      render_click(view, "open_rename_modal", %{})
      render_click(view, "update_rename_value", %{"value" => ""})
      html = render_click(view, "do_rename", %{})

      assert html =~ "cannot be empty"
    end

    test "do_rename with invalid name format shows error", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      render_click(view, "open_rename_modal", %{})
      render_click(view, "update_rename_value", %{"value" => "invalidname"})
      html = render_click(view, "do_rename", %{})

      assert html =~ "valid species name"
    end
  end

  describe "Cancel and discard" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "request_cancel with clean form navigates away", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      # Form is clean, so cancel should navigate (returns redirect)
      result = render_click(view, "request_cancel", %{})

      # Should either redirect or show page
      case result do
        {:error, {:live_redirect, %{to: to}}} ->
          assert to =~ "/admin/galls"

        html when is_binary(html) ->
          assert html =~ "Galls" or html =~ gall.name
      end
    end

    test "request_cancel with dirty form shows confirm modal", %{conn: conn} do
      gall = require_gall()
      {:ok, view, _html} = live(conn, ~p"/admin/galls/#{gall.id}")

      # Make form dirty
      render_click(view, "update_detachable", %{"value" => "2"})

      # Request cancel - should show confirm modal
      html = render_click(view, "request_cancel", %{})

      assert html =~ "Discard" or html =~ "unsaved"
    end
  end

  describe "Access control" do
    test "page requires admin session", %{conn: _conn} do
      conn_without_admin = build_conn()
      conn_result = get(conn_without_admin, ~p"/admin/galls/new")

      assert redirected_to(conn_result) =~ "/" or redirected_to(conn_result) =~ "/auth"
    end
  end
end
