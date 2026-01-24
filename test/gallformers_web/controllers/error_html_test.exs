defmodule GallformersWeb.ErrorHTMLTest do
  use GallformersWeb.ConnCase

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    html = render_to_string(GallformersWeb.ErrorHTML, "404", "html", [])
    assert html =~ "404"
    assert html =~ "Page Not Found"
  end

  test "renders 500.html" do
    html = render_to_string(GallformersWeb.ErrorHTML, "500", "html", [])
    assert html =~ "500"
    assert html =~ "Something went wrong"
  end
end
