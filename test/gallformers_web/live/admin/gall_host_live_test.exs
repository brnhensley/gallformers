defmodule GallformersWeb.Admin.GallHostLiveTest do
  @moduledoc """
  LiveView tests for the GallHostLive admin page.

  Tests the gall-host mapping admin functionality including:
  - Mount/render with and without URL params
  - Gall selection flow (search, select, clear)
  - Host management (add, remove)
  - Range curation (toggle, save, confirm)
  - Integration: save persists all changes to database
  """
  use GallformersWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Ecto.Query

  alias Gallformers.Accounts.Auth0User
  alias Gallformers.Galls
  alias Gallformers.Ranges
  alias Gallformers.Repo

  # ============================================
  # Test data — every test owns its data
  # ============================================

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
    |> put_session(:db_display_name, "Test User")
  end

  defp create_species(name, taxoncode) do
    Repo.insert!(%Gallformers.Species.Species{name: name, taxoncode: taxoncode})
  end

  defp create_gall(name), do: create_species(name, "gall")
  defp create_host(name), do: create_species(name, "plant")

  # Look up places by code — places are baseline seed data (like lookup tables).
  # We reference by code (stable) not by ID (fragile).
  defp place_id!(code) do
    Repo.one!(from(p in Gallformers.Places.Place, where: p.code == ^code, select: p.id))
  end

  defp create_host_range(host, place_code, opts \\ []) do
    precision = Keyword.get(opts, :precision, "exact")
    dist_type = Keyword.get(opts, :distribution_type, "native")

    Repo.insert!(%Gallformers.Ranges.HostRange{
      species_id: host.id,
      place_id: place_id!(place_code),
      precision: precision,
      distribution_type: dist_type
    })
  end

  defp create_gall_range(gall, place_code, opts \\ []) do
    precision = Keyword.get(opts, :precision, "exact")

    Repo.insert!(%Gallformers.Ranges.GallRange{
      species_id: gall.id,
      place_id: place_id!(place_code),
      precision: precision
    })
  end

  defp create_gall_traits(gall, attrs) do
    Repo.insert!(struct(Gallformers.Galls.GallTraits, Map.merge(%{species_id: gall.id}, attrs)))
  end

  # Full test world: gall with hosts, range data, gall traits, plus an unassociated host
  defp create_test_world do
    gall = create_gall("Testicus gallwaspicus")
    host1 = create_host("Quercus testalba")
    host2 = create_host("Quercus testrubra")
    unassociated_host = create_host("Acer testaceum")

    {:ok, rel1} =
      Galls.create_gall_host(%{gall_species_id: gall.id, host_species_id: host1.id})

    {:ok, rel2} =
      Galls.create_gall_host(%{gall_species_id: gall.id, host_species_id: host2.id})

    # Host range: the "canvas" for range curation
    create_host_range(host1, "US-CA")
    create_host_range(host1, "CA-AB")
    create_host_range(host2, "US-CA")

    # Gall range: curated range
    create_gall_range(gall, "US-CA")
    create_gall_range(gall, "CA-AB")

    # Gall traits (needed for range_confirmed)
    create_gall_traits(gall, %{range_confirmed: false})

    %{
      gall: gall,
      host1: host1,
      host2: host2,
      unassociated_host: unassociated_host,
      rel1: rel1,
      rel2: rel2
    }
  end

  # ============================================
  # Mount and render
  # ============================================

  describe "Mount and render" do
    setup %{conn: conn} do
      {:ok, Map.merge(create_test_world(), %{conn: setup_admin_session(conn)})}
    end

    test "renders page without a selected gall", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost")

      assert html =~ "Gall - Host Mappings"
      assert html =~ "Select a gall first"
    end

    test "renders page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")

      assert page_title(view) =~ "Gall-Host Mappings"
    end

    test "renders back to admin link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")

      assert has_element?(view, "a[href='/admin']")
    end

    test "loads gall from URL param", %{conn: conn, gall: gall} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      assert html =~ gall.name
    end

    test "invalid gall ID in URL shows error", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost?id=invalid")

      assert html =~ "Invalid gall ID"
    end

    test "non-existent gall ID in URL shows error", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost?id=999999999")

      assert html =~ "not found"
    end

    test "displays instructions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost")

      assert html =~ "First select a gall"
    end

    test "map placeholder shown when no gall selected", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost")

      assert html =~ "Select a gall to see its range"
    end
  end

  # ============================================
  # Gall selection flow
  # ============================================

  describe "Gall selection flow" do
    setup %{conn: conn} do
      {:ok, Map.merge(create_test_world(), %{conn: setup_admin_session(conn)})}
    end

    test "search returns results for matching query", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")

      html = render_click(view, "search_galls", %{"value" => "Testicus"})

      assert html =~ gall.name
    end

    test "search requires minimum 2 characters", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")

      render_click(view, "search_galls", %{"value" => "T"})

      refute has_element?(view, "[data-typeahead-results] button")
    end

    test "selecting a gall loads its hosts", %{conn: conn, gall: gall, host1: host1} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")

      html = render_click(view, "select_gall", %{"id" => Integer.to_string(gall.id)})

      assert html =~ gall.name
      assert html =~ host1.name
    end

    test "clearing gall resets state", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      html = render_click(view, "clear_gall", %{})

      assert html =~ "Select a gall first"
    end

    test "selecting invalid gall ID shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")

      html = render_click(view, "select_gall", %{"id" => "invalid"})

      assert html =~ "Invalid gall ID"
    end

    test "selecting a plant species shows error", %{conn: conn, host1: host} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")

      html = render_click(view, "select_gall", %{"id" => Integer.to_string(host.id)})

      assert html =~ "not a gall"
    end
  end

  # ============================================
  # Host management (deferred changes, pre-save)
  # ============================================

  describe "Host management" do
    setup %{conn: conn} do
      {:ok, Map.merge(create_test_world(), %{conn: setup_admin_session(conn)})}
    end

    test "host search returns results", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      html = render_click(view, "search_hosts", %{"value" => "Acer"})

      assert html =~ "Acer testaceum"
    end

    test "host search requires minimum 2 characters", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      render_click(view, "search_hosts", %{"value" => "A"})

      refute has_element?(view, "#host-search-results button")
    end

    test "adding host shows it in the UI", %{conn: conn, gall: gall, unassociated_host: host} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      # Search first (add_host requires host in search results)
      render_click(view, "search_hosts", %{"value" => "Acer"})
      html = render_click(view, "add_host", %{"id" => Integer.to_string(host.id)})

      assert html =~ host.name
    end

    test "adding duplicate host shows error", %{conn: conn, gall: gall, host1: host} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      # host1 is already associated — try adding via search
      render_click(view, "search_hosts", %{"value" => String.slice(host.name, 0, 8)})
      html = render_click(view, "add_host", %{"id" => Integer.to_string(host.id)})

      assert html =~ "already"
    end

    test "removing host removes it from the UI", %{conn: conn, gall: gall, rel1: rel, host1: host} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      html =
        render_click(view, "remove_host", %{"id" => Integer.to_string(rel.id)})

      refute html =~ host.name
    end

    test "removing host with invalid ID shows error", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      html = render_click(view, "remove_host", %{"id" => "invalid"})

      assert html =~ "Invalid relation ID"
    end

    test "add host requires gall to be selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")

      html = render_click(view, "add_host", %{"id" => "1"})

      assert html =~ "Select a gall first"
    end
  end

  # ============================================
  # Range curation
  # ============================================

  describe "Range curation" do
    setup %{conn: conn} do
      {:ok, Map.merge(create_test_world(), %{conn: setup_admin_session(conn)})}
    end

    test "toggle_region for code in host range works", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      # US-CA is in both host range and gall range — toggle removes it
      html = render_click(view, "toggle_region", %{"code" => "US-CA"})

      assert html =~ gall.name
    end

    test "toggle_region for code NOT in host range is no-op", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      # MX-JAL is not in any host range
      html = render_click(view, "toggle_region", %{"code" => "MX-JAL"})

      assert html =~ gall.name
    end

    test "toggle_region without gall selected is no-op", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")

      html = render_click(view, "toggle_region", %{"code" => "US-CA"})

      assert html =~ "Gall - Host Mappings"
    end

    test "toggle_region can toggle off and back on", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      # Toggle off
      render_click(view, "toggle_region", %{"code" => "CA-AB"})
      # Toggle back on
      html = render_click(view, "toggle_region", %{"code" => "CA-AB"})

      assert html =~ gall.name
    end

    test "range summary is displayed", %{conn: conn, gall: gall} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      assert html =~ "Range summary"
    end

    test "unconfirmed gall shows confirmation banner", %{conn: conn, gall: gall} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      assert html =~ "not been confirmed"
      assert html =~ "Save &amp; Confirm Range"
    end
  end

  # ============================================
  # Save: range persists to database
  # ============================================

  describe "Save persists range changes" do
    setup %{conn: conn} do
      {:ok, Map.merge(create_test_world(), %{conn: setup_admin_session(conn)})}
    end

    test "save persists gall_range changes to database", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      # Toggle CA-AB off to make form dirty
      render_click(view, "toggle_region", %{"code" => "CA-AB"})

      html = render_click(view, "save", %{})
      assert html =~ "Changes saved"

      gall_range_codes = Ranges.get_gall_range_codes(gall.id)
      refute "CA-AB" in gall_range_codes
      assert "US-CA" in gall_range_codes
    end

    test "save_and_confirm sets range_confirmed flag", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      # Toggle to make dirty
      render_click(view, "toggle_region", %{"code" => "CA-AB"})

      html = render_click(view, "save_and_confirm", %{})
      assert html =~ "Changes saved and range confirmed"

      gall_traits = Galls.get_gall_traits(gall.id)
      assert gall_traits.range_confirmed == true
      assert gall_traits.range_computed_at != nil
    end
  end

  # ============================================
  # Save: host changes persist to database
  # ============================================

  describe "Save persists host changes" do
    setup %{conn: conn} do
      {:ok, Map.merge(create_test_world(), %{conn: setup_admin_session(conn)})}
    end

    test "adding a host and saving persists to database", %{
      conn: conn,
      gall: gall,
      unassociated_host: new_host
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      render_click(view, "search_hosts", %{"value" => "Acer"})
      render_click(view, "add_host", %{"id" => Integer.to_string(new_host.id)})

      html = render_click(view, "save", %{})
      assert html =~ "Changes saved"

      host_ids = Galls.get_host_species_ids_for_gall(gall.id)
      assert new_host.id in host_ids
    end

    test "removing a host and saving persists to database", %{
      conn: conn,
      gall: gall,
      rel1: rel,
      host1: removed_host
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      render_click(view, "remove_host", %{"id" => Integer.to_string(rel.id)})

      html = render_click(view, "save", %{})
      assert html =~ "Changes saved"

      host_ids = Galls.get_host_species_ids_for_gall(gall.id)
      refute removed_host.id in host_ids
    end
  end

  # ============================================
  # Integration: full workflow verifies all state
  # ============================================

  describe "Integration: full save_and_confirm workflow" do
    setup %{conn: conn} do
      {:ok, Map.merge(create_test_world(), %{conn: setup_admin_session(conn)})}
    end

    test "add host, remove host, toggle range, confirm — all persist atomically", %{
      conn: conn,
      gall: gall,
      host1: removed_host,
      rel1: rel_to_remove,
      unassociated_host: new_host
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      # 1. Add a new host
      render_click(view, "search_hosts", %{"value" => "Acer"})
      render_click(view, "add_host", %{"id" => Integer.to_string(new_host.id)})

      # 2. Remove an existing host
      render_click(view, "remove_host", %{"id" => Integer.to_string(rel_to_remove.id)})

      # 3. Toggle US-CA off (both hosts provide it, so it remains in host range
      #    even after removing host1 — the toggle is valid)
      render_click(view, "toggle_region", %{"code" => "US-CA"})

      # 4. Save and confirm
      html = render_click(view, "save_and_confirm", %{})
      assert html =~ "Changes saved and range confirmed"

      # Verify ALL changes persisted:

      # Hosts
      host_ids = Galls.get_host_species_ids_for_gall(gall.id)
      assert new_host.id in host_ids
      refute removed_host.id in host_ids

      # Range
      range_codes = Ranges.get_gall_range_codes(gall.id)
      refute "US-CA" in range_codes

      # Range confirmed
      gall_traits = Galls.get_gall_traits(gall.id)
      assert gall_traits.range_confirmed == true
    end
  end

  # ============================================
  # Edge cases and error handling
  # ============================================

  describe "Edge cases" do
    setup %{conn: conn} do
      {:ok, conn: setup_admin_session(conn)}
    end

    test "malformed gall ID in URL", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost?id=abc123")
      assert html =~ "Invalid gall ID"
    end

    test "empty string gall ID in URL", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost?id=")
      assert html =~ "Search for a gall"
    end

    test "very large gall ID", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost?id=99999999999999")
      assert html =~ "not found"
    end

    test "negative gall ID", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost?id=-1")
      assert html =~ "not found"
    end

    test "special characters in search query", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")

      html = render_click(view, "search_galls", %{"value" => "test<script>alert(1)</script>"})

      # Should not crash — page still renders
      assert html =~ "Gall - Host Mappings"
    end

    test "page requires admin session", %{} do
      conn = build_conn()
      conn_result = get(conn, ~p"/admin/gallhost")

      assert redirected_to(conn_result) =~ "/"
    end
  end

  # ============================================
  # UI elements
  # ============================================

  describe "UI elements" do
    setup %{conn: conn} do
      {:ok, Map.merge(create_test_world(), %{conn: setup_admin_session(conn)})}
    end

    test "gall typeahead input is present", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")
      assert has_element?(view, "#gall-picker")
    end

    test "host picker is disabled when no gall selected", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost")
      assert html =~ "Select a gall first"
    end

    test "host picker is enabled when gall selected", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")
      assert has_element?(view, "#host-picker-input")
    end

    test "cancel button present", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")
      assert has_element?(view, "button[phx-click='request_cancel']", "Cancel")
    end

    test "save button disabled without gall selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost")
      assert has_element?(view, "button[phx-click='save'][disabled]", "Save")
    end

    test "public page link shown when gall selected", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")
      assert has_element?(view, "a[href='/gall/#{gall.id}']")
    end

    test "edit gall details link shown when gall selected", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")
      assert has_element?(view, "a[href='/admin/galls/#{gall.id}']")
    end

    test "bidirectional arrow is displayed", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost")
      assert html =~ "⇅"
    end

    test "link to add hosts page is present", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/gallhost")
      assert html =~ "/admin/hosts"
    end
  end

  # ============================================
  # Page title
  # ============================================

  describe "Page title" do
    setup %{conn: conn} do
      {:ok, Map.merge(create_test_world(), %{conn: setup_admin_session(conn)})}
    end

    test "updates when gall selected", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      assert page_title(view) =~ gall.name
    end

    test "resets when gall cleared", %{conn: conn, gall: gall} do
      {:ok, view, _html} = live(conn, ~p"/admin/gallhost?id=#{gall.id}")

      render_click(view, "clear_gall", %{})

      assert page_title(view) =~ "Gall-Host Mappings"
    end
  end
end
