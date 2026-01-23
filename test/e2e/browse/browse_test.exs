defmodule GallformersWeb.E2E.BrowseTest do
  @moduledoc """
  E2E tests for browsing species, hosts, and galls.
  These verify that detail pages load and navigation works.
  """
  use GallformersWeb.E2ECase

  @moduletag :e2e
  @moduletag :e2e_browse

  describe "gall detail page" do
    test "loads for valid gall ID", %{session: session} do
      # Get a valid gall ID from the database
      galls = Gallformers.Species.list_galls()

      if length(galls) > 0 do
        gall = hd(galls)

        session
        |> visit("/gall/#{gall.id}")
        |> assert_has(css("body.phx-connected"))
        |> assert_has(css("h1", text: gall.name))
      end
    end

    test "shows 404 for invalid gall ID", %{session: session} do
      session
      |> visit("/gall/999999999")
      |> assert_has(css("body.phx-connected"))
      # Should show not found message
      |> assert_has(Query.text("not found"))
    end
  end

  describe "host detail page" do
    test "loads for valid host ID", %{session: session} do
      # Get a valid host ID from the database
      hosts = Gallformers.Hosts.list_hosts()

      if length(hosts) > 0 do
        host = hd(hosts)

        session
        |> visit("/host/#{host.id}")
        |> assert_has(css("body.phx-connected"))
        |> assert_has(css("h1", text: host.name))
      end
    end

    test "shows 404 for invalid host ID", %{session: session} do
      session
      |> visit("/host/999999999")
      |> assert_has(css("body.phx-connected"))
      # Should show not found message
      |> assert_has(Query.text("not found"))
    end
  end

  describe "navigation between gall and host" do
    test "can navigate from gall to host", %{session: session} do
      # Find a gall that has associated hosts
      galls = Gallformers.Species.list_galls()

      gall_with_host =
        Enum.find(galls, fn g ->
          length(Gallformers.Hosts.get_hosts_for_gall(g.id)) > 0
        end)

      if gall_with_host do
        hosts = Gallformers.Hosts.get_hosts_for_gall(gall_with_host.id)
        host = hd(hosts)

        session
        |> visit("/gall/#{gall_with_host.id}")
        |> assert_has(css("body.phx-connected"))
        # Find and click link to host
        |> click(link(host.name))
        |> assert_has(css("body.phx-connected"))
        |> assert_has(css("h1", text: host.name))
      end
    end
  end
end
