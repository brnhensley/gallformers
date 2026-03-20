defmodule GallformersWeb.Plugs.EnforceReadOnly do
  @moduledoc """
  Plug that blocks admin routes when the site is in read-only mode.

  Exempts /admin/ops so the operator can always toggle read-only off.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if Gallformers.SiteSettings.read_only?() and not exempt?(conn) do
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(503, maintenance_html())
      |> halt()
    else
      conn
    end
  end

  defp exempt?(conn) do
    match?(["admin", "ops" | _], conn.path_info)
  end

  defp maintenance_html do
    """
    <!DOCTYPE html>
    <html>
    <head><title>Maintenance</title></head>
    <body style="font-family: system-ui; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0;">
      <div style="text-align: center;">
        <h1>Site Maintenance</h1>
        <p>The admin area is currently in read-only mode for maintenance.</p>
        <p>Public pages remain accessible.</p>
      </div>
    </body>
    </html>
    """
  end
end
