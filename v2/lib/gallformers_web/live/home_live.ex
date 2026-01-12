defmodule GallformersWeb.HomeLive do
  @moduledoc """
  LiveView for the home page.

  Displays a welcome message, information about galls, navigation links,
  a random gall from the database, and ways to help the project.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Species

  @impl true
  def mount(_params, _session, socket) do
    random_gall = Species.random_gall()

    {:ok,
     assign(socket,
       page_title: "Gallformers - Plant Gall Identification",
       random_gall: random_gall
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%!-- Hero Section --%>
      <div class="text-center mb-8">
        <h1 class="text-3xl font-bold text-gf-maroon mb-2">Welcome to Gallformers</h1>
        <p class="text-lg text-gf-autumn">
          The place to identify and learn about galls on plants in the US and Canada.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- What is a Gall --%>
        <.card title="What the heck is a gall?!">
          <p class="text-gray-700 leading-relaxed">
            Plant galls are abnormal growths of plant tissues, similar to tumors or warts in animals,
            that have an external cause--such as an insect, mite, nematode, virus, fungus, bacterium,
            or even another plant species. Growths caused by genetic mutations are not galls. Nor are
            lerps and other constructions on a plant that do not contain plant tissue. Plant galls are
            often complex structures that allow the insect or mite that caused the gall to be identified
            even if that insect or mite is not visible.
          </p>
        </.card>

        <%!-- Stuff You Can Do --%>
        <.card title="Stuff you can do.">
          <ul class="space-y-2">
            <li>
              <.link href="/id" class="text-gf-maroon hover:underline font-medium">
                Identify Galls
              </.link>
            </li>
            <li>
              <.link href="/refindex" class="text-gf-maroon hover:underline font-medium">
                Learn More About Galls
              </.link>
            </li>
            <li>
              <.link href="/explore" class="text-gf-maroon hover:underline font-medium">
                Explore the Data
              </.link>
            </li>
          </ul>
        </.card>
      </div>

      <%!-- Random Gall and Help Section --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
        <%!-- Random Gall --%>
        <div class="bg-white rounded border border-gray-200 shadow-sm">
          <%= if @random_gall do %>
            <.link href={"/gall/#{@random_gall.id}"} class="block">
              <img
                src={@random_gall.image_url}
                alt={@random_gall.name}
                class="w-full h-48 object-cover"
              />
            </.link>
            <div class="p-4">
              <p class="text-gray-700">
                Here is a random gall from our database.
                <%= if @random_gall.undescribed do %>
                  This one is an undescribed species called
                <% else %>
                  This one is called
                <% end %>
                <.link href={"/gall/#{@random_gall.id}"} class="text-gf-maroon hover:underline">
                  <em>{@random_gall.name}</em>
                </.link>.
              </p>
              <%= if @random_gall.image_creator do %>
                <p class="text-xs text-gray-500 mt-2">
                  Photo: {@random_gall.image_creator}
                  <%= if @random_gall.image_license do %>
                    ({@random_gall.image_license})
                  <% end %>
                </p>
              <% end %>
            </div>
          <% else %>
            <div class="p-6 text-center text-gray-600">
              <p>No galls found in the database.</p>
            </div>
          <% end %>
        </div>

        <%!-- Help Us Out --%>
        <.card title="Help Us Out">
          <p class="text-gray-700 mb-4">
            If you find gallformers.org useful and you are interested in helping us out there are a few
            ways you can do so:
          </p>
          <ul class="space-y-2">
            <li>
              <.link
                href="https://www.patreon.com/gallformers"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline font-medium"
              >
                Help cover operational costs via donations to our Patreon
              </.link>
            </li>
            <li>
              <.link href="/about#administrators" class="text-gf-maroon hover:underline font-medium">
                Help add and maintain our data as an Administrator
              </.link>
            </li>
            <li>
              <.link
                href="https://github.com/jeffdc/gallformers"
                target="_blank"
                rel="noreferrer"
                class="text-gf-maroon hover:underline font-medium"
              >
                Help fix bugs and add new features
              </.link>
            </li>
          </ul>
        </.card>
      </div>
    </Layouts.app>
    """
  end

  # A simple card component with a title and content.
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp card(assigns) do
    ~H"""
    <div class="bg-white rounded border border-gray-200 shadow-sm">
      <div class="px-4 py-3 border-b border-gray-200">
        <h2 class="text-xl font-semibold text-gf-maroon">{@title}</h2>
      </div>
      <div class="p-4">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
