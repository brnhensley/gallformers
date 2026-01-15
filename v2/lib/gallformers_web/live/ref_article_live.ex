defmodule GallformersWeb.RefArticleLive do
  @moduledoc """
  LiveView for individual reference article pages.

  Displays a single article with rendered markdown content, metadata,
  and related articles (by shared tags).
  """
  use GallformersWeb, :live_view

  alias Gallformers.Articles
  alias Gallformers.Markdown

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Articles.get_article_by_slug(slug) do
      nil ->
        {:ok,
         assign(socket,
           page_title: "Article Not Found",
           page_description: "The requested article was not found.",
           page_url: nil,
           page_image: nil,
           page_json_ld: nil,
           page_noindex: true,
           article: nil,
           related_articles: [],
           error: "Article not found"
         )}

      article ->
        # Only show published articles to non-admin users
        if article.is_published do
          load_article(socket, article)
        else
          {:ok,
           assign(socket,
             page_title: "Article Not Found",
             page_description: "The requested article was not found.",
             page_url: nil,
             page_image: nil,
             page_json_ld: nil,
             page_noindex: true,
             article: nil,
             related_articles: [],
             error: "Article not found"
           )}
        end
    end
  end

  defp load_article(socket, article) do
    # Find related articles (same tags, excluding self) - single query
    related_articles = Articles.list_related_articles(article, limit: 5)

    # Render markdown content
    rendered_content = Markdown.render!(article.content)

    {:ok,
     assign(socket,
       page_title: article.title,
       page_description: content_description(article.content),
       page_url: "/ref/#{article.slug}",
       page_image: nil,
       page_json_ld: article_json_ld(article),
       page_noindex: false,
       article: article,
       rendered_content: rendered_content,
       related_articles: related_articles,
       error: nil
     )}
  end

  defp content_description(content) when is_binary(content) do
    content
    |> String.replace(~r/[#*_`\[\]()]/, "")
    |> String.slice(0, 160)
    |> String.trim()
    |> then(fn desc ->
      if String.length(content) > 160, do: desc <> "...", else: desc
    end)
  end

  defp content_description(_), do: "Reference article on Gallformers"

  defp article_json_ld(article) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Article",
      "headline" => article.title,
      "author" => %{
        "@type" => "Person",
        "name" => article.author
      },
      "datePublished" => NaiveDateTime.to_iso8601(article.inserted_at),
      "dateModified" => NaiveDateTime.to_iso8601(article.updated_at),
      "publisher" => %{
        "@type" => "Organization",
        "name" => "Gallformers",
        "url" => "https://gallformers.org"
      }
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-4xl">
        <%= if @error do %>
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
                  d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M12 12h.01M12 12h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            </div>
            <h1 class="text-2xl font-bold text-gray-700 mb-2">Article Not Found</h1>
            <p class="text-gray-600 mb-4">{@error}</p>
            <.link href={~p"/refindex"} class="text-gf-maroon hover:underline">
              Browse all articles
            </.link>
          </div>
        <% else %>
          <%!-- Back link --%>
          <div class="mb-6">
            <.link
              href={~p"/refindex"}
              class="text-gf-maroon hover:underline inline-flex items-center gap-1"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 19l-7-7 7-7"
                />
              </svg>
              Back to Reference Library
            </.link>
          </div>

          <%!-- Article header --%>
          <header class="mb-8">
            <h1 class="text-3xl font-bold text-gf-maroon mb-4">{@article.title}</h1>
            <div class="flex flex-wrap items-center gap-4 text-gray-600">
              <span>By {@article.author}</span>
              <span>•</span>
              <span>{format_date(@article.inserted_at)}</span>
              <%= if @article.updated_at != @article.inserted_at do %>
                <span class="text-sm text-gray-500">
                  (Updated {format_date(@article.updated_at)})
                </span>
              <% end %>
            </div>
            <%= if @article.tags != [] do %>
              <div class="flex flex-wrap gap-2 mt-4">
                <%= for tag <- @article.tags do %>
                  <.link
                    href={~p"/refindex?tag=#{tag}"}
                    class="px-3 py-1 bg-gray-100 text-gray-700 text-sm rounded-full hover:bg-gray-200 transition-colors"
                  >
                    {tag}
                  </.link>
                <% end %>
              </div>
            <% end %>
          </header>

          <%!-- Article content --%>
          <article class="prose prose-lg max-w-none">
            {Phoenix.HTML.raw(@rendered_content)}
          </article>

          <%!-- Related articles --%>
          <%= if @related_articles != [] do %>
            <aside class="mt-12 pt-8 border-t border-gray-200">
              <h2 class="text-xl font-semibold text-gray-800 mb-4">Related Articles</h2>
              <div class="space-y-4">
                <%= for related <- @related_articles do %>
                  <.link
                    navigate={~p"/ref/#{related.slug}"}
                    class="block p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
                  >
                    <h3 class="font-medium text-gf-maroon hover:underline">{related.title}</h3>
                    <p class="text-sm text-gray-500 mt-1">By {related.author}</p>
                  </.link>
                <% end %>
              </div>
            </aside>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
