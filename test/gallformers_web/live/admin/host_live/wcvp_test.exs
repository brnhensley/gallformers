defmodule GallformersWeb.Admin.HostLive.WcvpTest do
  @moduledoc """
  Tests for WCVP integration in the host admin form.

  Uses Wcvp.LookupStub instead of a real SQLite database.
  The stub returns canned data, making tests fast and deterministic.
  """
  use GallformersWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Gallformers.Accounts.Auth0User
  alias Gallformers.Plants

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

  defp require_host do
    case Plants.list_hosts() do
      [host | _] -> host
      [] -> flunk("No host found in test database - ensure test fixtures exist")
    end
  end

  defp get_assign(view, key) do
    :sys.get_state(view.pid).socket.assigns[key]
  end

  setup %{conn: conn} do
    {:ok, conn: setup_admin_session(conn)}
  end

  describe "WCVP async search" do
    test "search_wcvp shows loading then results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/new")

      # Trigger search — handle_event sets wcvp_searching=true
      html = render_keyup(view, "search_wcvp", %{"value" => "Zzyzx"})
      assert html =~ "wcvp-search-loading"

      # After async completes, results appear
      html = render_async(view)
      assert html =~ "Zzyzx wcvponly"
      assert get_assign(view, :wcvp_searching) == false
      refute html =~ "wcvp-search-loading"
    end

    test "search_wcvp with short query does not search", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/new")

      html = render_keyup(view, "search_wcvp", %{"value" => "Zz"})
      refute html =~ "wcvp-search-loading"
      assert get_assign(view, :wcvp_searching) == false
    end
  end

  describe "WCVP async select" do
    test "select_wcvp shows loading then populates form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/new")

      # Search first to get results
      render_keyup(view, "search_wcvp", %{"value" => "Zzyzx"})
      render_async(view)

      # Select triggers async get
      html = render_click(view, "select_wcvp", %{"id" => "500"})
      assert html =~ "Loading WCVP data..."

      # After async completes, form is populated
      html = render_async(view)
      assert html =~ "Zzyzx wcvponly"
      assert get_assign(view, :wcvp_loading) == false
    end
  end

  describe "WCVP async refresh" do
    test "refresh_from_wcvp shows loading then diff for matching host", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/6")

      html = render_click(view, "refresh_from_wcvp", %{})
      assert html =~ "wcvp-refresh-loading"

      html = render_async(view)
      assert html =~ "POWO-WCVP Data Comparison"
      assert get_assign(view, :wcvp_refreshing) == false
      assert get_assign(view, :powo_diff) != nil
    end

    test "refresh_from_wcvp shows nomatch modal for non-matching host", %{conn: conn} do
      host = require_host()
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/#{host.id}")

      render_click(view, "refresh_from_wcvp", %{})
      html = render_async(view)

      assert html =~ "No exact match found"
    end

    test "cancel closes the nomatch modal", %{conn: conn} do
      host = require_host()
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/#{host.id}")

      render_click(view, "refresh_from_wcvp", %{})
      render_async(view)
      html = render_click(view, "cancel_wcvp_search", %{})

      refute html =~ "No exact match found"
    end
  end

  describe "WCVP nomatch modal search" do
    test "search updates results in modal", %{conn: conn} do
      host = require_host()
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/#{host.id}")

      render_click(view, "refresh_from_wcvp", %{})
      render_async(view)

      render_keyup(view, "wcvp_nomatch_search", %{"value" => "Zzyzx"})
      html = render_async(view)

      assert html =~ "Zzyzx wcvponly"
    end

    test "continue with selection opens diff", %{conn: conn} do
      host = require_host()
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/#{host.id}")

      render_click(view, "refresh_from_wcvp", %{})
      render_async(view)
      render_keyup(view, "wcvp_nomatch_search", %{"value" => "Zzyzx"})
      render_async(view)
      render_click(view, "select_wcvp_nomatch", %{"id" => "500"})
      render_click(view, "continue_wcvp_search", %{})
      html = render_async(view)

      refute html =~ "No exact match found"
      assert html =~ "POWO-WCVP Data Comparison"
    end
  end

  describe "POWO diff apply" do
    test "apply from diff updates range_entries and stages host_traits", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/6")

      render_click(view, "refresh_from_wcvp", %{})
      render_async(view)
      diff = get_assign(view, :powo_diff)
      assert diff != nil

      alias GallformersWeb.Admin.PowoDiffReview

      selections = %{
        add_native: MapSet.new(diff.add_native),
        add_introduced: MapSet.new(diff.add_introduced),
        remove: MapSet.new(),
        reclassify_to_introduced: MapSet.new(diff.reclassify_to_introduced),
        reclassify_to_native: MapSet.new(diff.reclassify_to_native)
      }

      send(view.pid, {PowoDiffReview, {:apply, selections}})
      _ = render(view)

      assert get_assign(view, :powo_diff) == nil
      pending = get_assign(view, :pending_host_traits)
      assert pending != nil
      assert pending.wcvp_id == "600"

      range_entries = get_assign(view, :range_entries)

      for code <- diff.add_native do
        assert range_entries[code].distribution_type == "native"
      end

      assert get_assign(view, :form_dirty) == true
    end

    test "cancel dismisses the diff", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/6")

      render_click(view, "refresh_from_wcvp", %{})
      render_async(view)
      assert get_assign(view, :powo_diff) != nil

      alias GallformersWeb.Admin.PowoDiffReview
      send(view.pid, {PowoDiffReview, :cancel})
      _ = render(view)

      assert get_assign(view, :powo_diff) == nil
    end
  end

  describe "WCVP loading state initialization" do
    test "initializes loading assigns to false on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/new")

      assert get_assign(view, :wcvp_searching) == false
      assert get_assign(view, :wcvp_loading) == false
    end

    test "initializes wcvp_refreshing to false on mount", %{conn: conn} do
      host = require_host()
      {:ok, view, _html} = live(conn, ~p"/admin/hosts/#{host.id}")

      assert get_assign(view, :wcvp_refreshing) == false
    end
  end
end
