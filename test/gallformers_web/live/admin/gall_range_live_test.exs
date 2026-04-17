defmodule GallformersWeb.Admin.GallRangeLiveTest do
  use GallformersWeb.ConnCase

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Gallformers.Accounts.Auth0User
  alias Gallformers.Galls
  alias Gallformers.Places.Place
  alias Gallformers.Ranges
  alias Gallformers.Ranges.{GallRange, HostRange}
  alias Gallformers.Repo
  alias Gallformers.Species.Species

  defp setup_admin_session(conn) do
    user = %Auth0User{
      id: "test-user-id",
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
    Repo.insert!(%Species{name: name, taxoncode: taxoncode})
  end

  defp create_gall(name), do: create_species(name, "gall")
  defp create_host(name), do: create_species(name, "plant")

  defp place_id!(code) do
    Repo.one!(from(p in Place, where: p.code == ^code, select: p.id))
  end

  defp create_gall_traits(gall, attrs) do
    Repo.insert!(struct(Gallformers.Galls.GallTraits, Map.merge(%{species_id: gall.id}, attrs)))
  end

  defp create_gall_range(gall, place_code) do
    Repo.insert!(%GallRange{
      species_id: gall.id,
      place_id: place_id!(place_code),
      precision: "exact"
    })
  end

  defp create_host_range(host, place_code, opts \\ []) do
    Repo.insert!(%HostRange{
      species_id: host.id,
      place_id: place_id!(place_code),
      precision: Keyword.get(opts, :precision, "exact"),
      distribution_type: Keyword.get(opts, :distribution_type, "native")
    })
  end

  defp create_review_world do
    alpha = create_gall("Alpha gall")
    beta = create_gall("Beta gall")
    gamma = create_gall("Gamma gall")

    create_gall_traits(alpha, %{range_confirmed: false, undescribed: false})
    create_gall_traits(beta, %{range_confirmed: true, undescribed: false})
    create_gall_traits(gamma, %{range_confirmed: false, undescribed: true})

    create_gall_range(alpha, "US-CA")

    host = create_host("Host alpha")
    {:ok, _} = Galls.create_gall_host(%{gall_species_id: alpha.id, host_species_id: host.id})
    create_host_range(host, "CA-AB")

    %{alpha: alpha, beta: beta, gamma: gamma}
  end

  describe "Gall Range Review page" do
    setup %{conn: conn} do
      {:ok, Map.merge(create_review_world(), %{conn: setup_admin_session(conn)})}
    end

    test "renders unconfirmed galls by default", %{
      conn: conn,
      alpha: alpha,
      gamma: gamma,
      beta: beta
    } do
      {:ok, _view, html} = live(conn, ~p"/admin/gall-range")

      assert html =~ "Gall Range Review"
      assert html =~ alpha.name
      assert html =~ gamma.name
      refute html =~ beta.name
    end

    test "status filter can show confirmed galls", %{conn: conn, beta: beta} do
      {:ok, view, _html} = live(conn, ~p"/admin/gall-range?filter=all")

      render_change(view, "filter", %{"value" => "confirmed"})

      html = render(view)
      assert html =~ beta.name
      assert html =~ "Confirmed"
    end

    test "search filters gall names", %{conn: conn, alpha: alpha, gamma: gamma} do
      {:ok, view, _html} = live(conn, ~p"/admin/gall-range?filter=all")

      render_keyup(view, "search", %{"value" => "Alpha"})

      html = render(view)
      assert html =~ alpha.name
      refute html =~ gamma.name
    end

    test "confirm selected marks gall as confirmed", %{conn: conn, alpha: alpha} do
      {:ok, view, _html} = live(conn, ~p"/admin/gall-range?filter=all")

      view
      |> element("input[phx-click=toggle_select][phx-value-id='#{alpha.id}']")
      |> render_click()

      view |> element("button", "Confirm Selected") |> render_click()
      view |> element("button[phx-click=do_confirm_selected]") |> render_click()

      html = render(view)
      assert html =~ "Confirmed range for 1 gall(s)"

      traits = Galls.get_gall_traits(alpha.id)
      assert traits.range_confirmed == true
      assert traits.range_computed_at != nil
    end

    test "recompute selected replaces range with host-native union and leaves it unconfirmed", %{
      conn: conn,
      alpha: alpha
    } do
      Galls.confirm_gall_range(alpha.id)

      {:ok, view, _html} = live(conn, ~p"/admin/gall-range?filter=all")

      view
      |> element("input[phx-click=toggle_select][phx-value-id='#{alpha.id}']")
      |> render_click()

      view |> element("button", "Recompute from hosts") |> render_click()
      view |> element("button[phx-click=do_recompute_selected]") |> render_click()

      render(view)
      assert Ranges.get_gall_range_codes(alpha.id) == ["CA-AB"]

      traits = Galls.get_gall_traits(alpha.id)
      assert traits.range_confirmed == false
    end

    test "range filter can show galls without stored ranges", %{
      conn: conn,
      gamma: gamma,
      alpha: alpha
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/gall-range")

      render_change(view, "range_filter", %{"value" => "no"})

      html = render(view)
      assert html =~ gamma.name
      refute html =~ alpha.name
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users" do
      conn = build_conn()
      conn = get(conn, ~p"/admin/gall-range")

      assert redirected_to(conn) =~ "/"
    end
  end
end
