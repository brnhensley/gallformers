defmodule GallformersWeb.PageController do
  use GallformersWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
