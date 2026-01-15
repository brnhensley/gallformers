defmodule GallformersWeb.Admin.ArticleAdminLive do
  @moduledoc """
  Admin LiveView for managing reference articles.

  Features:
  - Article list with draft/published indicators
  - Create and edit articles with markdown preview
  - Delete with confirmation
  - Tag management
  """

  use GallformersWeb, :live_view

  alias Gallformers.Articles
  alias Gallformers.Articles.Article
  alias Gallformers.Images
  alias Gallformers.Markdown

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]
    articles = Articles.list_articles()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Article Management")
      |> assign(:articles, articles)
      |> assign(:editing_article, nil)
      |> assign(:form, nil)
      |> assign(:delete_article, nil)
      |> assign(:preview_content, nil)
      |> assign(:active_tab, :edit)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Article Management">
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold text-gf-maroon">Article Management</h1>
          <div class="flex items-center gap-4">
            <.link navigate="/admin" class="text-gf-maroon hover:underline">
              &larr; Back to Dashboard
            </.link>
            <button
              type="button"
              phx-click="new_article"
              class="px-4 py-2 bg-gf-maroon text-white rounded-md hover:bg-gf-maroon/90"
            >
              <.icon name="ph-plus" class="h-4 w-4 inline mr-1" /> New Article
            </button>
          </div>
        </div>

        <%!-- Articles Table --%>
        <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
          <%= if @articles == [] do %>
            <div class="p-8 text-center text-gray-500">
              <.icon name="ph-article" class="h-12 w-12 mx-auto text-gray-300 mb-4" />
              <p>No articles yet. Create your first article to get started.</p>
            </div>
          <% else %>
            <table class="gf-table">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Author</th>
                  <th>Status</th>
                  <th>Tags</th>
                  <th>Updated</th>
                  <th class="w-32">Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for article <- @articles do %>
                  <tr>
                    <td>
                      <button
                        type="button"
                        phx-click="edit_article"
                        phx-value-id={article.id}
                        class="font-medium text-gf-maroon hover:underline text-left"
                      >
                        {article.title}
                      </button>
                    </td>
                    <td class="text-gray-600">{article.author}</td>
                    <td>
                      <%= if article.is_published do %>
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                          Published
                        </span>
                      <% else %>
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800">
                          Draft
                        </span>
                      <% end %>
                    </td>
                    <td class="text-gray-600 text-sm">
                      <%= if article.tags != [] do %>
                        {Enum.join(article.tags, ", ")}
                      <% else %>
                        <span class="text-gray-400">—</span>
                      <% end %>
                    </td>
                    <td class="text-gray-600 text-sm">{format_date(article.updated_at)}</td>
                    <td>
                      <div class="flex items-center gap-2">
                        <.link
                          :if={article.is_published}
                          href={~p"/ref/#{article.slug}"}
                          target="_blank"
                          class="p-1 text-gray-500 hover:text-gf-maroon"
                          title="View"
                        >
                          <.icon name="ph-eye" class="h-4 w-4" />
                        </.link>
                        <button
                          type="button"
                          phx-click="edit_article"
                          phx-value-id={article.id}
                          class="p-1 text-gray-500 hover:text-gf-maroon"
                          title="Edit"
                        >
                          <.icon name="ph-pencil" class="h-4 w-4" />
                        </button>
                        <button
                          type="button"
                          phx-click="confirm_delete"
                          phx-value-id={article.id}
                          class="p-1 text-gray-500 hover:text-red-600"
                          title="Delete"
                        >
                          <.icon name="ph-trash" class="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>

        <div class="text-sm text-gray-500">
          {length(@articles)} article{if length(@articles) != 1, do: "s", else: ""}
        </div>
      </div>

      <%!-- Edit/Create Modal --%>
      <.modal :if={@form} id="article-modal" show on_cancel={JS.push("cancel_edit")} class="!max-w-[80vw]">
        <:title>{if @editing_article.id, do: "Edit Article", else: "New Article"}</:title>

        <%!-- Tabs --%>
        <div class="border-b border-gray-200 mb-4">
          <nav class="-mb-px flex space-x-8">
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="edit"
              class={[
                "py-2 px-1 border-b-2 font-medium text-sm",
                if(@active_tab == :edit,
                  do: "border-gf-maroon text-gf-maroon",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Edit
            </button>
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="preview"
              class={[
                "py-2 px-1 border-b-2 font-medium text-sm",
                if(@active_tab == :preview,
                  do: "border-gf-maroon text-gf-maroon",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Preview
            </button>
          </nav>
        </div>

        <div class="min-h-[500px]">
        <%= if @active_tab == :edit do %>
          <.form for={@form} id="article-form" phx-submit="save_article" phx-change="validate" class="space-y-4">
            <div>
              <.input field={@form[:title]} label="Title" required />
            </div>
            <div>
              <.input field={@form[:slug]} label="Slug" placeholder="auto-generated from title if blank" />
            </div>
            <div>
              <.input field={@form[:author]} label="Author" required />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Content (Markdown)</label>
              <textarea
                name={@form[:content].name}
                id={@form[:content].id}
                rows="12"
                class="w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon font-mono text-sm"
                required
              >{Phoenix.HTML.Form.input_value(@form, :content)}</textarea>
              <div class="mt-2 flex items-center justify-between">
                <p class="text-xs text-gray-500">
                  Supports markdown formatting. Glossary terms are auto-linked.
                </p>
                <%!-- Image Upload --%>
                <%= if @editing_article.id do %>
                  <div
                    id="article-image-upload"
                    phx-hook="ArticleImageUpload"
                    phx-update="ignore"
                    data-content-textarea={@form[:content].id}
                    class="flex items-center gap-2"
                  >
                    <button
                      type="button"
                      data-upload-trigger
                      class="inline-flex items-center gap-1 px-2 py-1 text-xs text-gray-600 border border-gray-300 rounded hover:bg-gray-50"
                    >
                      <.icon name="ph-image" class="h-3 w-3" /> Add Image
                    </button>
                    <input
                      data-file-input
                      type="file"
                      accept="image/jpeg,image/png"
                      class="hidden"
                    />
                    <span data-status class="text-sm"></span>
                  </div>
                <% else %>
                  <p class="text-xs text-gray-400">Save article first to upload images</p>
                <% end %>
              </div>
            </div>
            <div>
              <.input
                field={@form[:tags_input]}
                label="Tags"
                placeholder="biology, ecology, identification"
              />
              <p class="mt-1 text-xs text-gray-500">Comma-separated list of tags</p>
            </div>
            <div class="flex items-center gap-2">
              <input
                type="checkbox"
                name={@form[:is_published].name}
                id={@form[:is_published].id}
                value="true"
                checked={Phoenix.HTML.Form.input_value(@form, :is_published) == true}
                class="rounded border-gray-300 text-gf-maroon focus:ring-gf-maroon"
              />
              <label for={@form[:is_published].id} class="text-sm text-gray-700">
                Published
              </label>
            </div>
          </.form>
        <% else %>
          <%!-- Preview Tab --%>
          <div class="prose prose-sm max-w-none h-[500px] overflow-auto border border-gray-200 rounded-md p-4">
            <%= if @preview_content do %>
              {Phoenix.HTML.raw(@preview_content)}
            <% else %>
              <p class="text-gray-500 italic">Enter content to see preview.</p>
            <% end %>
          </div>
        <% end %>
        </div>

        <:actions>
          <button
            type="button"
            phx-click="cancel_edit"
            class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            form="article-form"
            class="px-4 py-2 bg-gf-maroon text-white rounded-md hover:bg-gf-maroon/90"
          >
            {if @editing_article.id, do: "Save Changes", else: "Create Article"}
          </button>
        </:actions>
      </.modal>

      <%!-- Delete Confirmation Modal --%>
      <.modal :if={@delete_article} id="delete-modal" show on_cancel={JS.push("cancel_delete")}>
        <:title>Delete Article</:title>
        <p class="text-gray-600 mb-4">
          Are you sure you want to delete "<strong>{@delete_article.title}</strong>"? This action cannot be undone.
        </p>
        <:actions>
          <button
            type="button"
            phx-click="cancel_delete"
            class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="button"
            phx-click="delete_article"
            phx-value-id={@delete_article.id}
            class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
          >
            Delete
          </button>
        </:actions>
      </.modal>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("new_article", _params, socket) do
    article = %Article{}
    changeset = Articles.change_article(article, %{})

    socket =
      socket
      |> assign(:editing_article, article)
      |> assign(:form, to_form(changeset_with_tags_input(changeset, article)))
      |> assign(:preview_content, nil)
      |> assign(:active_tab, :edit)

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_article", %{"id" => id}, socket) do
    article = Articles.get_article!(String.to_integer(id))
    changeset = Articles.change_article(article, %{})

    socket =
      socket
      |> assign(:editing_article, article)
      |> assign(:form, to_form(changeset_with_tags_input(changeset, article)))
      |> assign(:preview_content, render_preview(article.content))
      |> assign(:active_tab, :edit)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"article" => params}, socket) do
    article = socket.assigns.editing_article

    changeset =
      article
      |> Articles.change_article(normalize_params(params))
      |> Map.put(:action, :validate)

    preview_content = render_preview(params["content"])

    socket =
      socket
      |> assign(:form, to_form(changeset_with_tags_input(changeset, article, params["tags_input"])))
      |> assign(:preview_content, preview_content)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_article", %{"article" => params}, socket) do
    article = socket.assigns.editing_article
    params = normalize_params(params)

    result =
      if article.id do
        Articles.update_article(article, params)
      else
        Articles.create_article(params)
      end

    case result do
      {:ok, _saved} ->
        articles = Articles.list_articles()

        socket =
          socket
          |> assign(:articles, articles)
          |> assign(:editing_article, nil)
          |> assign(:form, nil)
          |> put_flash(:info, if(article.id, do: "Article updated.", else: "Article created."))

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:form, to_form(changeset_with_tags_input(changeset, article, params["tags_input"])))
          |> put_flash(:error, "Failed to save article. Check the form for errors.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    socket =
      socket
      |> assign(:editing_article, nil)
      |> assign(:form, nil)
      |> assign(:preview_content, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    article = Articles.get_article!(String.to_integer(id))
    {:noreply, assign(socket, :delete_article, article)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_article, nil)}
  end

  @impl true
  def handle_event("delete_article", %{"id" => id}, socket) do
    article = Articles.get_article!(String.to_integer(id))

    case Articles.delete_article(article) do
      {:ok, _} ->
        articles = Articles.list_articles()

        socket =
          socket
          |> assign(:articles, articles)
          |> assign(:delete_article, nil)
          |> put_flash(:info, "Article deleted.")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete article.")}
    end
  end

  # Image upload handlers
  @impl true
  def handle_event("request_article_image_url", %{"extension" => ext, "type" => type}, socket) do
    article = socket.assigns.editing_article

    if article && article.id do
      slug = article.slug || "article-#{article.id}"
      path = Images.generate_article_path(slug, ext)

      case Images.presigned_upload_url(path, type) do
        {:ok, url} ->
          {:noreply, push_event(socket, "article_presigned_url", %{url: url, path: path, content_type: type})}

        {:error, reason} ->
          {:noreply, push_event(socket, "article_upload_error", %{message: "Failed to get upload URL: #{inspect(reason)}"})}
      end
    else
      {:noreply, push_event(socket, "article_upload_error", %{message: "Save article first before uploading images"})}
    end
  end

  @impl true
  def handle_event("article_image_uploaded", %{"path" => path}, socket) do
    # Generate the CDN URL and show it to the user
    image_url = Images.article_image_url(path)
    markdown = "![Image](#{image_url})"

    socket =
      socket
      |> put_flash(:info, "Image uploaded! Markdown copied: #{markdown}")

    {:noreply, socket}
  end

  # Add tags_input virtual field to changeset for form binding
  defp changeset_with_tags_input(changeset, article, tags_input \\ nil) do
    tags_input = tags_input || Enum.join(article.tags || [], ", ")

    changeset
    |> Ecto.Changeset.put_change(:tags_input, tags_input)
  end

  # Convert tags_input string to tags array and handle is_published
  defp normalize_params(params) do
    tags =
      case params["tags_input"] do
        nil -> []
        "" -> []
        input -> input |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
      end

    params
    |> Map.put("tags", tags)
    |> Map.put("is_published", params["is_published"] == "true")
  end

  defp render_preview(nil), do: nil
  defp render_preview(""), do: nil

  defp render_preview(content) do
    case Markdown.render(content) do
      {:ok, html} -> html
      {:error, _} -> "<p class='text-red-500'>Error rendering markdown</p>"
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
