defmodule GallformersWeb.BrowserSupportTest do
  @moduledoc """
  Tests for browser support detection and banner rendering.
  """
  use GallformersWeb.ConnCase, async: true

  alias GallformersWeb.BrowserSupport

  describe "supported_user_agent?/1" do
    test "rejects Safari 15" do
      refute BrowserSupport.supported_user_agent?(
               "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " <>
                 "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6 Safari/605.1.15"
             )
    end

    test "accepts Safari 16.4" do
      assert BrowserSupport.supported_user_agent?(
               "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3) " <>
                 "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15"
             ) == true
    end

    test "rejects Firefox 127" do
      refute BrowserSupport.supported_user_agent?(
               "Mozilla/5.0 (Macintosh; Intel Mac OS X 14.0; rv:127.0) " <>
                 "Gecko/20100101 Firefox/127.0"
             )
    end

    test "accepts Chrome 111" do
      assert BrowserSupport.supported_user_agent?(
               "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_2_1) " <>
                 "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36"
             ) == true
    end
  end

  describe "root layout" do
    test "renders the unsupported browser banner for Safari 15", %{conn: conn} do
      conn =
        conn
        |> put_req_header(
          "user-agent",
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " <>
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6 Safari/605.1.15"
        )
        |> get("/")

      html = html_response(conn, 200)

      assert html =~ "unsupported-browser-banner"
      assert html =~ BrowserSupport.banner_message()
    end

    test "does not render the unsupported browser banner for supported Safari", %{conn: conn} do
      conn =
        conn
        |> put_req_header(
          "user-agent",
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3) " <>
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15"
        )
        |> get("/")

      html = html_response(conn, 200)

      refute html =~ "unsupported-browser-banner"
    end
  end
end
