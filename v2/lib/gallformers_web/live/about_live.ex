defmodule GallformersWeb.AboutLive do
  @moduledoc """
  LiveView for the about page.

  Displays information about the Gallformers project, team, and site statistics.
  """
  use GallformersWeb, :live_view

  alias Gallformers.{Accounts, Hosts, Sources, Species, Taxonomy, Version}

  @impl true
  def mount(_params, _session, socket) do
    stats = get_site_stats()
    administrators = Accounts.list_users_for_about_page()

    {:ok,
     assign(socket,
       page_title: "About",
       page_description:
         "About Gallformers - Learn about the team behind the comprehensive database of plant galls and their causative organisms.",
       page_url: "/about",
       page_image: nil,
       page_json_ld: nil,
       stats: stats,
       administrators: administrators,
       gen_time: DateTime.utc_now() |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT"),
       show_easter_egg: false,
       app_version: Version.app_version(),
       api_version: Version.api_version()
     )}
  end

  @impl true
  def handle_event("toggle_easter_egg", _params, socket) do
    {:noreply, assign(socket, show_easter_egg: !socket.assigns.show_easter_egg)}
  end

  defp get_site_stats do
    %{
      galls: Species.count_galls(),
      hosts: Hosts.count_hosts(),
      sources: Sources.count_sources(),
      gall_families: count_families_for_taxoncode("gall"),
      gall_genera: count_genera_for_taxoncode("gall"),
      host_families: count_families_for_taxoncode("plant"),
      host_genera: count_genera_for_taxoncode("plant"),
      undescribed: count_undescribed_galls()
    }
  end

  defp count_families_for_taxoncode(_taxoncode) do
    # Simplified - count all families
    Taxonomy.list_families() |> length()
  end

  defp count_genera_for_taxoncode(_taxoncode) do
    # Simplified - count all genera
    Taxonomy.list_genera() |> length()
  end

  defp count_undescribed_galls do
    import Ecto.Query
    alias Gallformers.Repo
    alias Gallformers.Species.{Gall, GallSpecies, Species}

    from(s in Species,
      join: gs in GallSpecies,
      on: gs.species_id == s.id,
      join: g in Gall,
      on: gs.gall_id == g.id,
      where: g.undescribed == true,
      select: count(s.id)
    )
    |> Repo.one()
  end

  defp admin_name(assigns) do
    ~H"""
    <span>
      {display_name(@admin)}
      <%= if has_links?(@admin) do %>
        <span class="text-sm">
          (<.admin_links admin={@admin} />)
        </span>
      <% end %>
    </span>
    """
  end

  defp admin_links(assigns) do
    links = build_links(assigns.admin)
    assigns = assign(assigns, :links, links)

    ~H"""
    <%= for {label, url, index} <- Enum.with_index(@links, fn {l, u}, i -> {l, u, i} end) do %>
      <%= if index > 0 do %>
        ,
      <% end %>
      <.link
        href={url}
        target="_blank"
        rel="noreferrer"
        class="text-gf-maroon hover:underline"
      >
        {label}
      </.link>
    <% end %>
    """
  end

  defp build_links(admin) do
    []
    |> maybe_add_link(admin.inaturalist_url, "iNaturalist")
    |> maybe_add_link(admin.social_url, "Social")
    |> maybe_add_link(admin.personal_url, "Website")
    |> Enum.reverse()
  end

  defp maybe_add_link(links, nil, _label), do: links
  defp maybe_add_link(links, "", _label), do: links
  defp maybe_add_link(links, url, label), do: [{label, url} | links]

  defp display_name(admin) do
    cond do
      admin.display_name && admin.display_name != "" -> admin.display_name
      admin.nickname && admin.nickname != "" -> admin.nickname
      true -> "Anonymous"
    end
  end

  defp has_links?(admin) do
    (admin.inaturalist_url && admin.inaturalist_url != "") ||
      (admin.social_url && admin.social_url != "") ||
      (admin.personal_url && admin.personal_url != "")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div>
        <h1 class="text-3xl font-bold text-gf-maroon mb-8">About Us</h1>

        <div class="prose prose-lg max-w-none">
          <p class="text-gray-700 mb-4">
            Gallformers is the product of curious amateurs becoming obsessed. If you are here then you too have at
            least been touched, if not bitten, by the gall bug. It grows in you, but it is not a
            <.link href="/glossary#parasitism" class="text-gf-maroon hover:underline">parasite</.link>
            nor an <.link href="/glossary#inquiline" class="text-gf-maroon hover:underline">inquiline</.link>.
          </p>
          <p class="text-gray-700 mb-4">
            While you are here we hope that we can help you both ID an unknown plant gall as well as to learn about
            galls. Whether your interests are very casual, you are a burgeoning scientist, or even a full-fledged
            <.link href="/glossary#cecidiology" class="text-gf-maroon hover:underline">
              cecidiologist
            </.link>
            we strive to provide useful tools.
          </p>
          <p class="text-gray-700 mb-4">
            This site is open source and you can view all of the code/data and if so inclined even open a pull
            request on <.link
              href="https://github.com/jeffdc/gallformers"
              target="_blank"
              rel="noreferrer"
              class="text-gf-maroon hover:underline"
            >
              GitHub
            </.link>.
            Any and all help is greatly appreciated!
          </p>
          <p class="text-gray-700 mb-6">
            We have a
            <.link
              href="https://www.patreon.com/gallformers"
              target="_blank"
              rel="noreferrer"
              class="text-gf-maroon hover:underline"
            >
              Patreon
            </.link>
            account where you can donate to help cover the costs of building and operating the site.
          </p>

          <h2 class="text-2xl font-semibold text-gray-800 mt-8 mb-4">Contacting Us</h2>
          <p class="text-gray-700 mb-6">
            You can contact us at
            <.link href="mailto:gallformers@gmail.com" class="text-gf-maroon hover:underline">
              gallformers@gmail.com
            </.link>
            or
            <.link
              href="https://twitter.com/gallformers"
              target="_blank"
              rel="noreferrer"
              class="text-gf-maroon hover:underline"
            >
              @gallformers
            </.link>
            on Twitter.
          </p>

          <h2 class="text-2xl font-semibold text-gray-800 mt-8 mb-4">Our Co-founders</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
            <div class="bg-white rounded-lg shadow-md p-6">
              <h3 class="text-lg font-semibold text-gray-800 mb-2">Adam Kranz</h3>
              <p class="text-gray-600 text-sm mb-4">
                Adam is an independent ecologist focused on gall inducing organisms in North America. He
                co-founded Gallformers.org as a community resource to help naturalists identify gall observations
                and to collect information on undescribed galls. His primary focus is on adding literature and
                information to the Gallformers database.
              </p>
              <div class="flex gap-4 text-sm">
                <.link
                  href="https://www.inaturalist.org/people/megachile"
                  target="_blank"
                  rel="noreferrer"
                  class="text-gf-maroon hover:underline"
                >
                  iNaturalist
                </.link>
                <.link
                  href="https://twitter.com/adam_kranz"
                  target="_blank"
                  rel="noreferrer"
                  class="text-gf-maroon hover:underline"
                >
                  Twitter
                </.link>
              </div>
            </div>
            <div class="bg-white rounded-lg shadow-md p-6">
              <h3 class="text-lg font-semibold text-gray-800 mb-2">Jeff Clark</h3>
              <p class="text-gray-600 text-sm mb-4">
                Jeff is a Software Engineer who stumbled upon galls and became obsessed. So much so that he
                co-founded this site, wrote all the code for this site, and is responsible for keeping it going,
                fixing it, and implementing new features, and paying the bills. If the site is broken, it is most
                likely his fault. He is also way too into Oaks and will (HOPEFULLY) soon start building an ID tool
                for them.
              </p>
              <div class="flex gap-4 text-sm">
                <.link
                  href="https://www.inaturalist.org/people/jeffdc"
                  target="_blank"
                  rel="noreferrer"
                  class="text-gf-maroon hover:underline"
                >
                  iNaturalist
                </.link>
                <.link
                  href="https://mastodon.social/@jeffdc"
                  target="_blank"
                  rel="noreferrer"
                  class="text-gf-maroon hover:underline"
                >
                  Mastodon
                </.link>
              </div>
            </div>
          </div>

          <h2 id="administrators" class="text-2xl font-semibold text-gray-800 mt-8 mb-4">
            Administrators
          </h2>
          <p class="text-gray-700 mb-4">
            We also have an ever growing list of people that help us out as site administrators, without whom the site
            would be far poorer. If you are interested in becoming an administrator <.link
              href="mailto:gallformers@gmail.com"
              class="text-gf-maroon hover:underline"
            >reach out</.link>.
          </p>
          <%= if @administrators != [] do %>
            <ul class="list-disc list-inside text-gray-700 mb-8 columns-1 md:columns-2 gap-8">
              <li :for={admin <- @administrators} class="break-inside-avoid mb-1">
                <.admin_name admin={admin} />
              </li>
            </ul>
          <% end %>

          <h2 class="text-2xl font-semibold text-gray-800 mt-8 mb-4">Current Site Stats</h2>
          <p class="text-gray-700 mb-2">As of <em>{@gen_time}</em> there are:</p>
          <ul class="list-disc list-inside text-gray-700 mb-6">
            <li>
              {@stats.galls} gallformers across {@stats.gall_families} families and {@stats.gall_genera} genera,
              of which {@stats.undescribed} are undescribed
            </li>
            <li>
              {@stats.hosts} hosts across {@stats.host_families} families and {@stats.host_genera} genera
            </li>
            <li>{@stats.sources} sources</li>
          </ul>

          <h2 class="text-2xl font-semibold text-gray-800 mt-8 mb-4">Funding</h2>
          <div class="flex items-center gap-4 mb-6">
            <.link href="https://www.nsf.gov" target="_blank" rel="noreferrer">
              <img
                src="/images/nsf-logo.svg"
                alt="National Science Foundation Logo"
                class="w-32 h-32"
              />
            </.link>
            <p class="text-gray-700">
              This site is supported in part by the National Science Foundation under <.link
                href="https://www.nsf.gov/awardsearch/showAward?AWD_ID=2418250&HistoricalAwards=false"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline"
              >
                Grant No. 2418250
              </.link>.
            </p>
          </div>

          <h2 class="text-2xl font-semibold text-gray-800 mt-8 mb-4">Citing Gallformers</h2>
          <p class="text-gray-700 mb-4">
            All of our original content is released under a
            <.link
              href="https://creativecommons.org/licenses/by/4.0/"
              target="_blank"
              rel="noreferrer"
              class="text-gf-maroon hover:underline"
            >
              CC-BY
            </.link>
            license.
          </p>
          <p class="text-gray-700 mb-4">
            Gallformers would be impossible without the many contributions from the scientific literature as well as
            the many individuals that have allowed usage of their wonderful photos. We have made every effort to
            verify and document the license for all content that we use. If you find anything that you think is
            incorrect please contact us:
            <.link href="mailto:gallformers@gmail.com" class="text-gf-maroon hover:underline">
              Email
            </.link>
            or <.link
              href="https://twitter.com/gallformers"
              target="_blank"
              rel="noreferrer"
              class="text-gf-maroon hover:underline"
            >
              Twitter
            </.link>.
          </p>
          <p class="text-gray-700 mb-4">
            If you are interested in using information on Gallformers in your own research please do. All we ask is
            that you cite Gallformers and that if you are using any content that is not original to Gallformers that
            you please cite the original source. When applicable, please cite the specific ID Notes containing the
            claim being cited.
          </p>

          <h3 class="text-lg font-semibold text-gray-800 mt-6 mb-2">Citation</h3>
          <div class="bg-gray-50 p-4 rounded-lg font-mono text-sm text-gray-700 mb-2">
            "Gallformers Contributors." Www.gallformers.org, www.gallformers.org. Accessed [date]
          </div>
          <div class="bg-gray-50 p-4 rounded-lg font-mono text-sm text-gray-700 mb-8">
            "Gallformers Contributors." "[<em>Species name</em>]" Notes on ID and Taxonomy,
            Www.gallformers.org/[url to specific species], www.gallformers.org. Accessed [date]
          </div>

          <h2 class="text-2xl font-semibold text-gray-800 mt-8 mb-4">Public API</h2>
          <p class="text-gray-700 mb-4">
            Gallformers provides a public API for programmatic access to our database. You can use it to search for
            galls, hosts, and species, as well as retrieve detailed information about specific entries.
          </p>
          <p class="text-gray-700 mb-6">
            View the full API documentation and try it out interactively at our
            <.link href="/api/docs" class="text-gf-maroon hover:underline">
              API Documentation
            </.link>
            page.
          </p>

          <%!-- Version Info --%>
          <div class="mt-12 text-center text-sm text-gray-500">
            App: {@app_version} | API: {@api_version}
          </div>

          <%!-- Easter Egg --%>
          <div class="mt-6 border-t pt-6">
            <button
              phx-click="toggle_easter_egg"
              class="text-gray-500 hover:text-gray-700 text-sm"
            >
              {if @show_easter_egg, do: "Hide", else: "Dare You Click?"}
            </button>
            <%= if @show_easter_egg do %>
              <div class="mt-4 flex justify-center">
                <img
                  src="/images/gallmemaybe.jpg"
                  alt="Gall Me Maybe"
                  class="max-w-xs rounded-lg shadow-lg"
                />
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
