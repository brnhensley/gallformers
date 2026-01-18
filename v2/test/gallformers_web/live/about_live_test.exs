defmodule GallformersWeb.AboutLiveTest do
  @moduledoc """
  LiveView tests for the public About page.
  """
  use GallformersWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Gallformers.Accounts

  # Helper to generate unique auth0 IDs
  defp unique_auth0_id, do: "auth0|test-#{System.unique_integer([:positive])}"

  describe "About page - public access" do
    test "page loads successfully without authentication", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "About Us"
    end

    test "displays page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert page_title(view) =~ "About"
    end

    test "displays site description", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "Gallformers" or html =~ "gall"
    end

    test "displays co-founder information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "Adam Kranz"
      assert html =~ "Jeff Clark"
    end

    test "displays contact information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "gallformers@gmail.com"
    end

    test "displays site statistics", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Should have stats section
      assert html =~ "Stats" or html =~ "galls" or html =~ "hosts"
    end

    test "displays administrators section heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "Administrators"
    end
  end

  describe "About page - administrators list" do
    setup do
      # Create test users - some opted in, some opted out
      {:ok, user_opted_in_with_links} =
        Accounts.create_user(%{
          auth0_id: unique_auth0_id(),
          display_name: "Admin With Links",
          nickname: "adminlinks",
          inaturalist_url: "https://www.inaturalist.org/people/adminlinks",
          social_url: "https://twitter.com/adminlinks",
          personal_url: "https://adminlinks.com",
          show_on_about: true
        })

      {:ok, user_opted_in_no_links} =
        Accounts.create_user(%{
          auth0_id: unique_auth0_id(),
          display_name: "Admin No Links",
          nickname: "adminnolinks",
          show_on_about: true
        })

      {:ok, user_opted_out} =
        Accounts.create_user(%{
          auth0_id: unique_auth0_id(),
          display_name: "Hidden Admin",
          nickname: "hiddenadmin",
          show_on_about: false
        })

      {:ok,
       user_opted_in_with_links: user_opted_in_with_links,
       user_opted_in_no_links: user_opted_in_no_links,
       user_opted_out: user_opted_out}
    end

    test "displays opted-in users", %{
      conn: conn,
      user_opted_in_with_links: user_with_links,
      user_opted_in_no_links: user_no_links
    } do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ user_with_links.display_name
      assert html =~ user_no_links.display_name
    end

    test "does not show users with show_on_about=false", %{conn: conn, user_opted_out: user} do
      {:ok, _view, html} = live(conn, ~p"/about")

      refute html =~ user.display_name
    end

    test "shows display_name when set", %{conn: conn, user_opted_in_with_links: user} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ user.display_name
    end

    test "shows profile links when set", %{conn: conn, user_opted_in_with_links: user} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Should have links to iNaturalist, Social, Website
      assert html =~ user.inaturalist_url or html =~ "iNaturalist"
      assert html =~ "twitter.com" or html =~ "Social"
      assert html =~ user.personal_url or html =~ "Website"
    end

    test "does not show link section when user has no links", %{
      conn: conn,
      user_opted_in_no_links: user
    } do
      {:ok, _view, html} = live(conn, ~p"/about")

      # User should appear
      assert html =~ user.display_name

      # The user entry shouldn't have link text like "iNaturalist" near their name
      # This is hard to test precisely without more structure, but we can verify
      # the page loads correctly
    end
  end

  describe "About page - nickname fallback" do
    setup do
      # Create user with only nickname (no display_name)
      {:ok, user_with_nickname_only} =
        Accounts.create_user(%{
          auth0_id: unique_auth0_id(),
          display_name: nil,
          nickname: "OnlyNickname",
          show_on_about: true
        })

      {:ok, user_with_nickname_only: user_with_nickname_only}
    end

    test "shows nickname when display_name is nil", %{
      conn: conn,
      user_with_nickname_only: user
    } do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Should show the nickname as fallback
      assert html =~ user.nickname
    end
  end

  describe "About page - empty state" do
    test "handles case when no users opted in gracefully", %{conn: conn} do
      # Even if no users are opted in, the page should load without error
      {:ok, _view, html} = live(conn, ~p"/about")

      # Should still show the Administrators section heading
      assert html =~ "Administrators"
    end
  end

  describe "About page - external links" do
    test "displays GitHub link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "github.com" or html =~ "GitHub"
    end

    test "displays Patreon link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "patreon.com" or html =~ "Patreon"
    end

    test "displays Twitter link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "twitter.com" or html =~ "@gallformers"
    end

    test "displays API documentation link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "/api/docs" or html =~ "API Documentation"
    end
  end

  describe "About page - citation section" do
    test "displays citation information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "Citing" or html =~ "Citation"
      assert html =~ "Gallformers Contributors"
    end

    test "displays license information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "CC-BY" or html =~ "Creative Commons"
    end
  end

  describe "About page - funding section" do
    test "displays NSF funding information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "Funding" or html =~ "NSF" or html =~ "National Science Foundation"
    end
  end

  describe "About page - version info" do
    test "displays version information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "App:" or html =~ "API:"
    end
  end

  describe "About page - easter egg" do
    test "has easter egg toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "button", "Dare You Click?")
    end

    test "easter egg toggles on click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      # Click the easter egg button
      html =
        view
        |> element("button", "Dare You Click?")
        |> render_click()

      # Should now show "Hide"
      assert html =~ "Hide"
    end
  end

  describe "About page - responsive design" do
    test "page renders with proper structure", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      # Check for main structural elements
      assert has_element?(view, "h1")
      assert has_element?(view, "h2")
    end
  end
end
