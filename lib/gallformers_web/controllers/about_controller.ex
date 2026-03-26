defmodule GallformersWeb.AboutController do
  use GallformersWeb, :controller

  alias Gallformers.{Accounts, Galls, Sources, Taxonomy, Version}
  alias Gallformers.Plants

  def show(conn, _params) do
    stats = get_site_stats()
    administrators = Accounts.list_users_for_about_page()

    conn
    |> assign(:page_title, "About")
    |> assign(
      :page_description,
      "About Gallformers - Learn about the team behind the comprehensive database of plant galls and their causative organisms."
    )
    |> assign(:page_url, "/about")
    |> assign(:stats, stats)
    |> assign(:administrators, administrators)
    |> assign(
      :gen_time,
      DateTime.utc_now() |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")
    )
    |> assign(:app_version, Version.app_version())
    |> assign(:api_version, Version.api_version())
    |> render(:show)
  end

  defp get_site_stats do
    %{
      galls: Galls.count_galls(),
      hosts: Plants.count_hosts(),
      sources: Sources.count_sources(),
      gall_families: Taxonomy.count_families_for_taxoncode("gall"),
      gall_genera: Taxonomy.count_genera_for_taxoncode("gall"),
      host_families: Taxonomy.count_families_for_taxoncode("plant"),
      host_genera: Taxonomy.count_genera_for_taxoncode("plant"),
      undescribed: Galls.count_undescribed_galls()
    }
  end
end
