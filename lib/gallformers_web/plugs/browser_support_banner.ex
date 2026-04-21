defmodule GallformersWeb.Plugs.BrowserSupportBanner do
  @moduledoc """
  Exposes whether the current request is using an unsupported browser,
  based on the shared Browserslist-generated matcher.
  """

  import Plug.Conn

  alias GallformersWeb.BrowserSupport

  def init(opts), do: opts

  def call(conn, _opts) do
    assign(conn, :unsupported_browser, BrowserSupport.unsupported_user_agent?(user_agent(conn)))
  end

  defp user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      [] -> nil
    end
  end
end
