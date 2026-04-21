defmodule GallformersWeb.Plugs.LegacyFrontendTest do
  use GallformersWeb.ConnCase

  @legacy_ipad_ua "Mozilla/5.0 (iPad; CPU OS 15_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Mobile/15E148 Safari/604.1"
  @legacy_desktop_safari_ua "Mozilla/5.0 (Macintosh; Intel Mac OS X 12_6_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Safari/605.1.15"
  @modern_ios_safari_ua "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
  @modern_mac_chrome_ua "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

  describe "legacy stylesheet split" do
    test "serves legacy css to old iPad Safari on LiveView routes", %{conn: conn} do
      html = response_html(conn, "/", @legacy_ipad_ua)

      assert html =~ ~s(href="/assets/css/app-legacy.css")
      refute html =~ ~s(href="/assets/css/app.css")
    end

    test "serves legacy css to old iPad Safari on controller routes", %{conn: conn} do
      html = response_html(conn, "/about", @legacy_ipad_ua)

      assert html =~ ~s(href="/assets/css/app-legacy.css")
      refute html =~ ~s(href="/assets/css/app.css")
    end

    test "serves legacy css to old desktop Safari", %{conn: conn} do
      html = response_html(conn, "/", @legacy_desktop_safari_ua)

      assert html =~ ~s(href="/assets/css/app-legacy.css")
      refute html =~ ~s(href="/assets/css/app.css")
    end

    test "keeps modern css for current iOS Safari", %{conn: conn} do
      html = response_html(conn, "/", @modern_ios_safari_ua)

      assert html =~ ~s(href="/assets/css/app.css")
      refute html =~ ~s(href="/assets/css/app-legacy.css")
    end

    test "keeps modern css for desktop Chrome on older macOS", %{conn: conn} do
      html = response_html(conn, "/", @modern_mac_chrome_ua)

      assert html =~ ~s(href="/assets/css/app.css")
      refute html =~ ~s(href="/assets/css/app-legacy.css")
    end
  end

  defp response_html(conn, path, user_agent) do
    conn
    |> put_req_header("user-agent", user_agent)
    |> get(path)
    |> html_response(200)
  end
end
