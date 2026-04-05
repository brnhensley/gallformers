defmodule GallformersWeb.AdminFormComponentsTest do
  use GallformersWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias GallformersWeb.Admin.FormComponents

  defmodule EmptyWarningsTestLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <FormComponents.duplicate_host_warning warnings={@warnings} />
      """
    end

    def mount(_params, _session, socket) do
      {:ok, assign(socket, warnings: [])}
    end
  end

  defmodule NameMatchTestLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <FormComponents.duplicate_host_warning warnings={@warnings} />
      """
    end

    def mount(_params, _session, socket) do
      {:ok,
       assign(socket,
         warnings: [
           %{reason: :name_match, species_id: 42, species_name: "Quercus alba"}
         ]
       )}
    end
  end

  defmodule AliasMatchCommonTestLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <FormComponents.duplicate_host_warning warnings={@warnings} />
      """
    end

    def mount(_params, _session, socket) do
      {:ok,
       assign(socket,
         warnings: [
           %{
             reason: :alias_match,
             alias_type: "common",
             species_id: 99,
             species_name: "Quercus rubra"
           }
         ]
       )}
    end
  end

  defmodule AliasMatchScientificTestLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <FormComponents.duplicate_host_warning warnings={@warnings} />
      """
    end

    def mount(_params, _session, socket) do
      {:ok,
       assign(socket,
         warnings: [
           %{
             reason: :alias_match,
             alias_type: "scientific",
             species_id: 55,
             species_name: "Quercus velutina"
           }
         ]
       )}
    end
  end

  defmodule WcvpIdMatchTestLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <FormComponents.duplicate_host_warning warnings={@warnings} />
      """
    end

    def mount(_params, _session, socket) do
      {:ok,
       assign(socket,
         warnings: [
           %{reason: :wcvp_id_match, species_id: 77, species_name: "Acer saccharum"}
         ]
       )}
    end
  end

  defmodule MultipleWarningsTestLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <FormComponents.duplicate_host_warning warnings={@warnings} />
      """
    end

    def mount(_params, _session, socket) do
      {:ok,
       assign(socket,
         warnings: [
           %{reason: :name_match, species_id: 42, species_name: "Quercus alba"},
           %{
             reason: :alias_match,
             alias_type: "common",
             species_id: 99,
             species_name: "Quercus rubra"
           },
           %{reason: :wcvp_id_match, species_id: 77, species_name: "Acer saccharum"}
         ]
       )}
    end
  end

  describe "duplicate_host_warning/1" do
    test "renders nothing when warnings list is empty", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, EmptyWarningsTestLive)

      refute html =~ "Possible duplicate"
      refute html =~ "warning"
    end

    test "renders warning for name_match", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, NameMatchTestLive)

      assert html =~ "Possible duplicate"
      assert html =~ "exact name already exists"
      assert html =~ "Quercus alba"
      assert html =~ ~s(href="/admin/hosts/42")
    end

    test "renders warning for alias_match with common type", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, AliasMatchCommonTestLive)

      assert html =~ "Possible duplicate"
      assert html =~ "common name of"
      assert html =~ "Quercus rubra"
    end

    test "renders warning for alias_match with scientific type", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, AliasMatchScientificTestLive)

      assert html =~ "Possible duplicate"
      assert html =~ "scientific synonym of"
      assert html =~ "Quercus velutina"
    end

    test "renders warning for wcvp_id_match", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, WcvpIdMatchTestLive)

      assert html =~ "Possible duplicate"
      assert html =~ "WCVP record is already linked to"
      assert html =~ "Acer saccharum"
    end

    test "renders multiple warnings", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, MultipleWarningsTestLive)

      assert html =~ "Possible duplicate"
      assert html =~ "exact name already exists"
      assert html =~ "Quercus alba"
      assert html =~ "common name of"
      assert html =~ "Quercus rubra"
      assert html =~ "WCVP record is already linked to"
      assert html =~ "Acer saccharum"
    end
  end
end
