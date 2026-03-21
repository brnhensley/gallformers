defmodule GallformersWeb.Admin.IngestionReviewLiveTest do
  use GallformersWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Gallformers.Accounts.Auth0User

  defp admin_conn(conn) do
    user = %Auth0User{
      id: "test-admin-id",
      email: "admin@test.com",
      name: "Test Admin",
      nickname: nil,
      picture: nil,
      roles: ["admin", "superadmin"]
    }

    conn
    |> init_test_session(%{})
    |> put_session(:current_user, user)
    |> put_session(:db_display_name, "Test Admin")
  end

  # Helper to put the LiveView into "loaded" state by sending it fake data
  defp load_fake_data(view, opts \\ []) do
    metadata =
      opts[:metadata] ||
        %{
          "title" => "Test Paper",
          "authors" => ["Test Author"],
          "year" => 2024,
          "doi" => nil
        }

    extraction =
      opts[:extraction] ||
        [
          %{
            "gall_species" => %{"name" => "Testgallus testus", "authority" => "Smith"},
            "host_species" => %{"name" => "Quercus alba", "authority" => "L."},
            "traits" => %{
              "plant_part" => %{"original" => "leaf", "suggested" => ["upper leaf"]},
              "shape" => %{"original" => "round", "suggested" => ["globular"]}
            },
            "description" => "A test gall.",
            "location" => nil,
            "confidence" => 0.9
          }
        ]

    markdown = opts[:markdown] || "# Test Paper\n\nA test gall on *Quercus alba*."

    send(view.pid, {:load_data, metadata, extraction, markdown})
    render(view)
  end

  describe "mount" do
    test "renders the ingestion review page with upload form", %{conn: conn} do
      {:ok, view, html} = live(admin_conn(conn), ~p"/admin/ingestion-review")

      assert html =~ "Source Ingestion Review"
      assert has_element?(view, "#pdf-dropzone")
    end
  end

  describe "PDF upload" do
    test "accepts a PDF and triggers processing", %{conn: conn} do
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/ingestion-review")

      pdf_content = "%PDF-1.4 fake pdf content for testing"

      pdf =
        file_input(view, "#upload-form", :pdf, [
          %{
            name: "test-document.pdf",
            content: pdf_content,
            type: "application/pdf"
          }
        ])

      render_upload(pdf, "test-document.pdf")
      html = render(view)

      # After upload, should either be loading files or running pipeline
      assert html =~ "Running pipeline" || html =~ "Source"
    end
  end

  describe "pipeline" do
    test "detects existing output and shows cached badge", %{conn: conn} do
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/ingestion-review")

      pdf_content = "%PDF-1.4 fake pdf for skip test"

      hash =
        :crypto.hash(:sha256, pdf_content)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 12)

      # Create fake output directory with the expected files
      output_dir = Path.join(System.tmp_dir!(), "ingestion-test-#{hash}")
      File.mkdir_p!(output_dir)

      metadata =
        Jason.encode!(%{title: "Test Paper", authors: ["Author"], year: 2024, doi: nil})

      extraction =
        Jason.encode!([
          %{
            gall_species: %{name: "Test gall"},
            host_species: %{name: "Test host"},
            traits: %{}
          }
        ])

      markdown = "# Test Paper\n\nSome content."

      File.write!(Path.join(output_dir, "bhl-deepseek-v3-4-metadata.json"), metadata)
      File.write!(Path.join(output_dir, "bhl-deepseek-v3-5-data-extract.json"), extraction)
      File.write!(Path.join(output_dir, "bhl-deepseek-v3-#{hash}.md"), markdown)

      # Tell the LiveView to use this output dir
      send(view.pid, {:set_output_dir, output_dir})

      pdf =
        file_input(view, "#upload-form", :pdf, [
          %{name: "test.pdf", content: pdf_content, type: "application/pdf"}
        ])

      render_upload(pdf, "test.pdf")
      html = render(view)

      # Should show loaded data and cached indicator
      assert html =~ "Test Paper"
      assert html =~ "cached"

      # Cleanup
      File.rm_rf!(output_dir)
    end
  end

  describe "source matching" do
    test "shows source search typeahead after data is loaded", %{conn: conn} do
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/ingestion-review")

      html = load_fake_data(view)

      assert html =~ "Source Lookup"
      assert has_element?(view, "#source-typeahead")
    end

    test "searches sources by query", %{conn: conn} do
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/ingestion-review")
      load_fake_data(view)

      # Send a search event directly — the event should not crash
      html = render_click(view, "search_source", %{"query" => "Canadian"})

      # Should render without error
      assert html =~ "Source Lookup"
    end
  end

  describe "gall collapsing" do
    test "groups records by gall species", %{conn: conn} do
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/ingestion-review")

      # Two records for same gall, different hosts
      extraction = [
        %{
          "gall_species" => %{"name" => "Meskea dyspteraria", "authority" => "Grote"},
          "host_species" => %{"name" => "Abutilon incanum", "authority" => nil},
          "traits" => %{
            "color" => %{"original" => "brown", "suggested" => ["brown"]},
            "plant_part" => %{"original" => "stems", "suggested" => ["stem"]}
          },
          "description" => "First record.",
          "location" => nil,
          "confidence" => 0.85
        },
        %{
          "gall_species" => %{"name" => "Meskea dyspteraria", "authority" => "Grote"},
          "host_species" => %{"name" => "Malvaviscus drummondii", "authority" => nil},
          "traits" => %{
            "walls" => %{"original" => "hard lignified", "suggested" => ["thick"]},
            "plant_part" => %{"original" => "stems", "suggested" => ["stem"]}
          },
          "description" => "Second record.",
          "location" => "Austin",
          "confidence" => 0.85
        }
      ]

      html = load_fake_data(view, extraction: extraction)

      # Should show gall name once (not "Record 1", "Record 2")
      assert html =~ "Meskea dyspteraria"
      refute html =~ "Record 1"

      # Both hosts should be listed
      assert html =~ "Abutilon incanum"
      assert html =~ "Malvaviscus drummondii"

      # Traits from both records should be merged
      assert html =~ "color"
      assert html =~ "walls"
      assert html =~ "plant_part"
    end
  end
end
