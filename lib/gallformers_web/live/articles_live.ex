defmodule GallformersWeb.ArticlesLive do
  @moduledoc """
  LiveView for the articles index page.

  Displays published reference articles with tag filtering.
  """
  use GallformersWeb, :live_view

  alias Gallformers.Articles

  @impl true
  def mount(_params, _session, socket) do
    # Only show tags from published articles on the public index
    tags = Articles.list_tags(published_only: true)

    {:ok,
     assign(socket,
       page_title: "Articles",
       page_description:
         "Gallformers Articles - in-depth articles on gall biology, identification guides, and scientific literature.",
       page_url: "/articles",
       page_image: nil,
       page_json_ld: nil,
       tags: tags,
       selected_tag: nil,
       articles: []
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    selected_tag = params["tag"]

    articles =
      if selected_tag do
        Articles.list_articles(published_only: true, tag: selected_tag)
      else
        Articles.list_published_articles()
      end

    {:noreply, assign(socket, selected_tag: selected_tag, articles: articles)}
  end

  # Returns article description if available, otherwise generates a preview from content
  defp article_preview(article) do
    if article.description && article.description != "" do
      article.description
    else
      content_preview(article.content)
    end
  end

  defp content_preview(content) when is_binary(content) do
    content
    |> strip_markdown()
    |> String.slice(0, 200)
    |> String.trim()
    |> then(fn preview ->
      if String.length(content) > 200, do: preview <> "...", else: preview
    end)
  end

  defp content_preview(_), do: ""

  # Returns the date to display (published_at if available, otherwise inserted_at)
  defp display_date(article) do
    article.published_at || article.inserted_at
  end

  # Strip common markdown syntax for plain text preview
  defp strip_markdown(text) do
    text
    # Remove headings (# Header)
    |> String.replace(~r/^\#{1,6}\s+/m, "")
    # Remove bold (**text** or __text__)
    |> String.replace(~r/\*\*([^*]+)\*\*/, "\\1")
    |> String.replace(~r/__([^_]+)__/, "\\1")
    # Remove italic (*text* or _text_)
    |> String.replace(~r/(?<!\*)\*([^*]+)\*(?!\*)/, "\\1")
    |> String.replace(~r/(?<!_)_([^_]+)_(?!_)/, "\\1")
    # Remove links [text](url)
    |> String.replace(~r/\[([^\]]+)\]\([^)]+\)/, "\\1")
    # Remove images ![alt](url)
    |> String.replace(~r/!\[[^\]]*\]\([^)]+\)/, "")
    # Remove inline code `code`
    |> String.replace(~r/`([^`]+)`/, "\\1")
    # Remove blockquotes
    |> String.replace(~r/^>\s*/m, "")
    # Collapse multiple spaces/newlines
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-4xl">
        <h1 class="text-3xl font-bold text-gf-maroon mb-4">Gallformers Articles</h1>

        <p class="text-gray-700 mb-6">
          In-depth articles on gall biology, identification guides, and scientific literature.
        </p>

        <%!-- Tag filter chips --%>
        <%= if @tags != [] do %>
          <div class="mb-6">
            <div class="flex flex-wrap gap-2">
              <.link
                patch={~p"/articles"}
                class={[
                  "px-3 py-1 rounded-full text-sm font-medium transition-colors",
                  if(@selected_tag == nil,
                    do: "bg-gf-maroon text-white",
                    else: "bg-gray-200 text-gray-700 hover:bg-gray-300"
                  )
                ]}
              >
                All
              </.link>
              <.link
                :for={tag_info <- @tags}
                patch={~p"/articles?tag=#{tag_info.tag}"}
                class={[
                  "px-3 py-1 rounded-full text-sm font-medium transition-colors",
                  if(@selected_tag == tag_info.tag,
                    do: "bg-gf-maroon text-white",
                    else: "bg-gray-200 text-gray-700 hover:bg-gray-300"
                  )
                ]}
              >
                {tag_info.tag} ({tag_info.count})
              </.link>
            </div>
          </div>
        <% end %>

        <%!-- Articles list --%>
        <%= if @articles == [] do %>
          <div class="bg-gray-50 rounded-lg p-8 text-center">
            <div class="mb-4">
              <svg
                class="w-16 h-16 mx-auto text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
                />
              </svg>
            </div>
            <p class="text-gray-600 mb-4">
              <%= if @selected_tag do %>
                No articles found with tag "{@selected_tag}".
              <% else %>
                No articles available yet.
              <% end %>
            </p>
            <%= if @selected_tag do %>
              <.link
                patch={~p"/articles"}
                class="hover:underline"
              >
                View all articles
              </.link>
            <% end %>
          </div>
        <% else %>
          <div class="space-y-6">
            <.link
              :for={article <- @articles}
              navigate={~p"/articles/#{article.slug}"}
              class="block group"
            >
              <article class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
                <h2 class="text-xl font-semibold text-gf-maroon group-hover:underline mb-2">
                  {article.title}
                </h2>
                <div class="text-sm text-gray-500 mb-3">
                  <span>By {article.author}</span>
                  <span class="mx-2">•</span>
                  <span>{format_date(display_date(article))}</span>
                </div>
                <div :if={article.tags != []} class="flex flex-wrap gap-2 mb-3">
                  <span
                    :for={tag <- article.tags}
                    class="px-2 py-0.5 bg-gray-100 text-gray-600 text-xs rounded"
                  >
                    {tag}
                  </span>
                </div>
                <p class="text-gray-600">
                  {article_preview(article)}
                </p>
              </article>
            </.link>
          </div>

          <div class="mt-6 text-sm text-gray-500">
            Showing {length(@articles)} article{if length(@articles) != 1, do: "s", else: ""}
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
