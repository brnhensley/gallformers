defmodule GallformersWeb.Admin.HostRangeLiveTest do
  @moduledoc """
  LiveView tests for the host range review admin page.
  """
  use GallformersWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Gallformers.Accounts.Auth0User
  alias Gallformers.Plants

  defp conn_with_roles(conn, roles) do
    user = %Auth0User{
      id: "test-user-#{Enum.join(roles, "-")}",
      email: "admin@test.com",
      name: "Test Admin",
      nickname: nil,
      picture: nil,
      roles: roles
    }

    conn
    |> init_test_session(%{})
    |> put_session(:current_user, user)
    |> put_session(:db_display_name, "Test User")
  end

  setup %{conn: conn} do
    conn = conn_with_roles(conn, ["admin"])

    {:ok, conn: conn}
  end

  describe "Host Range Review page" do
    test "renders the page with unconfirmed hosts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/host-range")

      assert html =~ "Host Range Review"
      assert html =~ "Needs Review"
    end

    test "shows host names from seed data", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/host-range")

      # Seed data has host species at IDs 1-5 and 6-9
      assert html =~ "Quercus alba"
      assert html =~ "Acer rubrum"
    end

    test "filter toggle shows confirmed hosts", %{conn: conn} do
      # Confirm a host first
      Plants.bulk_confirm_host_ranges([1])

      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      # Initially shows unconfirmed, so host 1 (Quercus alba) should not appear
      refute render(view) =~ "Quercus alba"

      # Switch filter to confirmed
      view |> element("form#filter") |> render_change(%{value: "confirmed"})

      html = render(view)
      assert html =~ "Quercus alba"
    end

    test "name search filters the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      # Search for "Quercus" - should show Quercus species
      view |> element("input[phx-keyup=search]") |> render_keyup(%{value: "Quercus"})

      html = render(view)
      assert html =~ "Quercus alba"
      refute html =~ "Acer rubrum"
    end

    test "select and confirm a host", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      # Select host 1
      view |> element("input[phx-click=toggle_select][phx-value-id='1']") |> render_click()

      # Open confirm modal and confirm
      view |> element("button", "Confirm Selected") |> render_click()
      view |> element("#confirm-modal button[phx-click=do_confirm_selected]") |> render_click()

      # Verify flash message
      assert render(view) =~ "Confirmed range for 1 host(s)"

      # Verify host 1 is now confirmed in the database
      traits = Plants.get_host_traits(1)
      assert traits.range_confirmed != nil
    end

    test "bulk confirm creates host_traits for hosts without them", %{conn: _conn} do
      # Host 1 should not have host_traits initially
      assert Plants.get_host_traits(1) == nil

      {count, _} = Plants.bulk_confirm_host_ranges([1, 2])
      assert count == 2

      assert Plants.get_host_traits(1).range_confirmed == true
      assert Plants.get_host_traits(2).range_confirmed == true
    end

    test "select all and deselect all", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      # Click the header checkbox to select all
      view |> element("th input[type=checkbox]") |> render_click()

      html = render(view)
      assert html =~ "Confirm Selected"

      # Click deselect all
      view |> element("button", "Clear selection") |> render_click()

      html = render(view)
      refute html =~ "Confirm Selected"
    end

    test "shows confirmation modal when confirming with nothing selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      # Send the event directly since button is hidden when nothing selected
      view |> render_hook("confirm_selected", %{})

      # Modal shows with 0 count
      assert has_element?(view, "#confirm-modal")
      assert render(view) =~ "0"
    end

    test "shows empty state when all confirmed", %{conn: conn} do
      # Confirm all seed hosts
      hosts = Plants.list_hosts_for_range_review(filter: :all)

      Plants.bulk_confirm_host_ranges(Enum.map(hosts, & &1.id))

      {:ok, _view, html} = live(conn, ~p"/admin/host-range")
      assert html =~ "All host ranges confirmed!"
    end

    test "host name links to host edit page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      assert has_element?(view, "a[href*='/admin/hosts/1']")
    end

    test "back link navigates to admin dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      assert has_element?(view, "a[href='/admin']")
    end

    test "renders WCVP data date when available", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/host-range")

      assert html =~ "Host Range Review"
      assert html =~ "WCVP data:"
    end

    test "sync selected shows results modal after completion", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      # Select a host (none have WCVP IDs in seed data)
      view |> element("input[phx-click=toggle_select][phx-value-id='1']") |> render_click()

      # Show confirm modal, then execute sync
      view |> element("button", "Sync Selected from WCVP") |> render_click()
      view |> element("#sync-confirm-modal button[phx-click=do_sync_selected]") |> render_click()

      # The sync processes via handle_info message chain ({:sync_next, ...}).
      # Render flushes pending messages in the LiveView process.
      # Two renders: one for the sync step, one for the completion.
      render(view)
      html = render(view)

      assert html =~ "WCVP Sync Complete"
      assert has_element?(view, "#sync-results-modal")
    end

    test "match selected links hosts without syncing range data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      view |> element("input[phx-click=toggle_select][phx-value-id='6']") |> render_click()
      view |> element("button", "Match Selected to WCVP") |> render_click()

      view
      |> element("#match-confirm-modal button[phx-click=do_match_selected]")
      |> render_click()

      render(view)
      html = render(view)

      assert html =~ "WCVP Match Complete"
      assert has_element?(view, "#match-results-modal")

      traits = Plants.get_host_traits(6)
      assert traits.wcvp_id == "600"
      assert traits.powo_id == "urn:lsid:ipni.org:names:test"
      assert traits.wcvp_synced_at == nil
    end

    test "superadmin sees match-all-filtered button", %{conn: conn} do
      conn = conn_with_roles(conn, ["superadmin"])

      {:ok, _view, html} = live(conn, ~p"/admin/host-range")

      assert html =~ "Match All Filtered to WCVP"
      assert html =~ "Super Admin only"
    end

    test "regular admin does not see match-all-filtered button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/host-range")

      refute html =~ "Match All Filtered to WCVP"
    end

    test "superadmin can match all currently filtered hosts", %{conn: conn} do
      conn = conn_with_roles(conn, ["superadmin"])

      {:ok, view, _html} = live(conn, ~p"/admin/host-range?search=Thymus")

      view |> element("button", "Match All Filtered to WCVP") |> render_click()

      assert has_element?(view, "#match-confirm-modal")
      assert render(view) =~ "all currently filtered"

      view
      |> element("#match-confirm-modal button[phx-click=do_match_all_filtered]")
      |> render_click()

      render(view)
      html = render(view)

      assert html =~ "Thymus alpinus"
      assert html =~ "linked"

      traits = Plants.get_host_traits(6)
      assert traits.wcvp_id == "600"
      assert traits.powo_id == "urn:lsid:ipni.org:names:test"
    end

    test "non-superadmin cannot trigger match-all-filtered event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range?search=Thymus")

      view |> render_hook("match_all_filtered", %{})

      assert render(view) =~ "Only superadmins can match all filtered hosts"
      assert Plants.get_host_traits(6) == nil
    end

    test "ignored hosts are excluded by default and can be filtered in", %{conn: conn} do
      {:ok, _} = Plants.upsert_host_traits(1, %{wcvp_match_status: "ignored"})

      {:ok, _view, html} = live(conn, ~p"/admin/host-range")
      refute html =~ "Quercus alba"

      {:ok, _view, html} = live(conn, ~p"/admin/host-range?wcvp=ignored")
      assert html =~ "Quercus alba"
      assert html =~ "ignored"
    end

    test "ignore selected marks host as ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      view |> element("input[phx-click=toggle_select][phx-value-id='1']") |> render_click()
      view |> element("button", "Ignore Selected") |> render_click()

      assert Plants.get_host_traits(1).wcvp_match_status == "ignored"
      refute render(view) =~ "Quercus alba"
    end

    test "clear match status removes ignored status", %{conn: conn} do
      {:ok, _} = Plants.upsert_host_traits(1, %{wcvp_match_status: "ignored"})

      {:ok, view, _html} = live(conn, ~p"/admin/host-range?wcvp=ignored")

      view |> element("input[phx-click=toggle_select][phx-value-id='1']") |> render_click()
      view |> element("button", "Clear Match Status") |> render_click()

      assert Plants.get_host_traits(1).wcvp_match_status == nil
      refute render(view) =~ "Quercus alba"
    end

    test "sync selected shows modal when nothing is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      # Send the event directly since button is hidden when nothing selected
      view |> render_hook("sync_selected", %{})

      # Modal shows with 0 count
      assert has_element?(view, "#sync-confirm-modal")
    end
  end

  describe "URL param persistence" do
    test "reads filter from URL params", %{conn: conn} do
      # No hosts are confirmed by default, so confirmed filter shows empty state
      {:ok, _view, html} = live(conn, ~p"/admin/host-range?filter=confirmed")

      assert html =~ "No hosts found"
    end

    test "reads search from URL params", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/host-range?search=Quercus")

      assert html =~ "Quercus alba"
      refute html =~ "Acer rubrum"
    end

    test "reads multiple params together", %{conn: conn} do
      Plants.bulk_confirm_host_ranges([1])

      {:ok, view, _html} = live(conn, ~p"/admin/host-range?filter=confirmed&search=Quercus")

      html = render(view)
      assert html =~ "Quercus alba"
    end

    test "filter change updates URL via patch", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      view |> element("form#filter") |> render_change(%{value: "confirmed"})

      # After patch, the view should reflect the confirmed filter
      assert render(view) =~ "No hosts found"
    end
  end

  describe "sync status filter" do
    test "renders sync status dropdown", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      assert has_element?(view, "form#sync_status_filter")
    end

    test "sync status filter reads from URL params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range?sync_status=never")

      assert has_element?(view, "form#sync_status_filter option[value=never][selected]")
    end
  end

  describe "confirmation modals" do
    test "confirm button shows confirmation modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      view |> element("input[phx-click=toggle_select][phx-value-id='1']") |> render_click()
      view |> element("button[phx-click=confirm_selected]") |> render_click()

      assert has_element?(view, "#confirm-modal")
      assert render(view) =~ "Confirm Host Ranges"
    end

    test "sync button shows confirmation modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      view |> element("input[phx-click=toggle_select][phx-value-id='1']") |> render_click()
      view |> element("button[phx-click=sync_selected]") |> render_click()

      assert has_element?(view, "#sync-confirm-modal")
      assert render(view) =~ "Sync from WCVP"
    end

    test "match button shows confirmation modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      view |> element("input[phx-click=toggle_select][phx-value-id='6']") |> render_click()
      view |> element("button[phx-click=match_selected]") |> render_click()

      assert has_element?(view, "#match-confirm-modal")
      assert render(view) =~ "Match to WCVP"
    end

    test "cancel on confirmation modal preserves selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      view |> element("input[phx-click=toggle_select][phx-value-id='1']") |> render_click()
      view |> element("button[phx-click=confirm_selected]") |> render_click()

      # Cancel the modal
      view |> element("#confirm-modal button[phx-click=cancel_confirm]") |> render_click()

      # Selection should still be there
      assert has_element?(view, "button[phx-click=confirm_selected]")
    end

    test "confirming executes the action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/host-range")

      view |> element("input[phx-click=toggle_select][phx-value-id='1']") |> render_click()
      view |> element("button[phx-click=confirm_selected]") |> render_click()
      view |> element("#confirm-modal button[phx-click=do_confirm_selected]") |> render_click()

      assert render(view) =~ "Confirmed range for 1 host(s)"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users", %{conn: _conn} do
      conn = Phoenix.ConnTest.build_conn()
      conn = get(conn, ~p"/admin/host-range")

      assert redirected_to(conn) =~ "/"
    end
  end
end
