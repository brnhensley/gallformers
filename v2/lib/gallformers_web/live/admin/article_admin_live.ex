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

  # Import the discard_confirm_modal component
  import GallformersWeb.Admin.FormHelpers, only: [discard_confirm_modal: 1]

  alias Gallformers.Accounts.Auth0User
  alias Gallformers.Articles
  alias Gallformers.Articles.Article
  alias Gallformers.Images
  alias Gallformers.Markdown

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]
    articles = Articles.list_articles()
    all_tags = Articles.list_all_tags()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:page_title, "Articles")
      |> assign(:articles, articles)
      |> assign(:filtered_articles, articles)
      |> assign(:search_query, "")
      |> assign(:tag_filter, "")
      |> assign(:status_filter, "")
      |> assign(:all_tags, all_tags)
      |> assign(:editing_article, nil)
      |> assign(:form, nil)
      |> assign(:form_dirty, false)
      |> assign(:show_discard_confirm, false)
      |> assign(:delete_article, nil)
      |> assign(:preview_content, nil)
      |> assign(:active_tab, :edit)
      |> assign(:show_image_browser, false)
      |> assign(:article_images, [])
      # Tag dropdown state
      |> assign(:form_tags, [])
      |> assign(:tag_search_query, "")
      |> assign(:tag_dropdown_open, false)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Articles">
      <div class="space-y-6">
        <%!-- Info banner --%>
        <div class="gf-admin-info">
          <.icon name="ph-info" class="h-5 w-5 text-blue-400 mr-2 flex-shrink-0" />
          <p>
            Reference articles provide educational content about galls, identification guides, and research resources.
            Articles support markdown formatting and glossary term auto-linking.
          </p>
        </div>

        <%!-- Header with filters and new button --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex flex-1 gap-3 max-w-2xl">
            <form phx-change="search" phx-submit="search" id="article-search-form" class="flex-1">
              <.search_input
                id="article-search"
                name="query"
                value={@search_query}
                placeholder="Filter by title or author..."
                phx-debounce="300"
              />
            </form>
            <form phx-change="filter_tag" id="article-tag-filter" class="w-48">
              <.input
                type="select"
                name="tag"
                prompt="All Tags"
                options={Enum.map(@all_tags, &{&1, &1})}
                value={@tag_filter}
              />
            </form>
            <form phx-change="filter_status" id="article-status-filter" class="w-40">
              <.input
                type="select"
                name="status"
                prompt="All Status"
                options={[{"Published", "published"}, {"Draft", "draft"}]}
                value={@status_filter}
              />
            </form>
          </div>
          <button type="button" phx-click="new_article" class="gf-btn gf-btn-primary">
            New Article
          </button>
        </div>

        <%!-- Articles Table --%>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <%= if @filtered_articles == [] do %>
            <div class="p-8 text-center text-gray-500">
              <.icon name="ph-article" class="h-12 w-12 mx-auto text-gray-300 mb-4" />
              <%= if @articles == [] do %>
                <p>No articles yet. Create your first article to get started.</p>
              <% else %>
                <p>No articles match your filters. Try a different search term or tag.</p>
              <% end %>
            </div>
          <% else %>
            <table class="gf-table gf-table-dark gf-table-compact">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Author</th>
                  <th>Status</th>
                  <th>Tags</th>
                  <th>Updated</th>
                  <th class="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for article <- @filtered_articles do %>
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
                    <td class="text-gray-600 text-sm">{format_date(article.updated_at, :short)}</td>
                    <td class="text-right">
                      <.table_actions>
                        <.action_button
                          icon="ph-pencil-simple"
                          label="Edit"
                          variant="primary"
                          phx-click="edit_article"
                          phx-value-id={article.id}
                        />
                        <.action_button
                          icon="ph-arrow-square-out"
                          label={if article.is_published, do: "View", else: "Preview"}
                          href={~p"/ref/#{article.slug}"}
                          target="_blank"
                        />
                        <.action_button
                          icon="ph-trash"
                          label="Delete"
                          variant="danger"
                          phx-click="confirm_delete"
                          phx-value-id={article.id}
                        />
                      </.table_actions>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>

        <p class="text-sm text-gray-500">
          Showing {length(@filtered_articles)} of {length(@articles)} article{if length(@articles) !=
                                                                                   1,
                                                                                 do: "s",
                                                                                 else: ""}
        </p>
      </div>

      <%!-- Edit/Create Modal --%>
      <.modal
        :if={@form}
        id="article-modal"
        show
        on_cancel={JS.push("request_cancel")}
        class="!max-w-[80vw]"
      >
        <:header>
          <span>{if @editing_article.id, do: "Edit Article", else: "New Article"}</span>
          <%= if @editing_article.id do %>
            <a
              href={~p"/ref/#{@editing_article.slug}"}
              target="_blank"
              title="View public page"
              class="ml-3 text-gf-maroon hover:text-gf-autumn transition-colors"
            >
              <.icon name="ph-eye" class="h-5 w-5 inline" />
            </a>
          <% end %>
        </:header>
        <:body>
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

          <div class="h-[600px]">
            <%= if @active_tab == :edit do %>
              <.form
                for={@form}
                id="article-form"
                phx-submit="save_article"
                phx-change="validate"
                class="h-full flex flex-col space-y-4"
              >
                <div>
                  <.input field={@form[:title]} label="Title" required />
                </div>
                <div>
                  <.input
                    field={@form[:slug]}
                    label="Slug"
                    placeholder="auto-generated from title if blank"
                  />
                </div>
                <div>
                  <.input field={@form[:author]} label="Author" required />
                </div>
                <div>
                  <.input
                    type="textarea"
                    field={@form[:description]}
                    label="Description"
                    placeholder="Brief summary for article previews and SEO"
                    rows={2}
                  />
                  <p class="mt-1 text-xs text-gray-500">
                    Optional. Used for article previews and search engine descriptions.
                  </p>
                </div>
                <div class="flex-1 flex flex-col min-h-0">
                  <label class="gf-label">
                    Content (Markdown)
                  </label>
                  <textarea
                    name={@form[:content].name}
                    id={@form[:content].id}
                    class="flex-1 w-full rounded-md border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon font-mono text-sm resize-none"
                    required
                  >{Phoenix.HTML.Form.input_value(@form, :content)}</textarea>
                  <div class="mt-2 flex items-center justify-between">
                    <p class="text-xs text-gray-500">
                      Supports markdown formatting. Glossary terms are auto-linked.
                    </p>
                    <%!-- Image Upload & Browse --%>
                    <%= if @editing_article.id do %>
                      <div class="flex items-center gap-2">
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
                            class="gf-btn gf-btn-secondary text-sm"
                          >
                            Upload Image
                          </button>
                          <input
                            data-file-input
                            type="file"
                            accept="image/jpeg,image/png"
                            class="hidden"
                          />
                          <span data-status class="text-sm"></span>
                        </div>
                        <button
                          type="button"
                          phx-click="open_image_browser"
                          class="gf-btn gf-btn-secondary text-sm"
                        >
                          Browse Images
                        </button>
                      </div>
                    <% else %>
                      <p class="text-xs text-gray-400">Save article first to add images</p>
                    <% end %>
                  </div>
                </div>
                <div>
                  <.multi_select_dropdown
                    id="article-tags"
                    label="Tags"
                    type={:tags}
                    options={Enum.map(@all_tags, fn tag -> %{id: tag, tag: tag} end)}
                    selected={Enum.map(@form_tags, fn tag -> %{id: tag, tag: tag} end)}
                    search_query={@tag_search_query}
                    dropdown_open={@tag_dropdown_open}
                    item_id={:id}
                    item_label={:tag}
                    placeholder="Select or type tags..."
                    on_search="tag_search"
                    on_add="add_tag"
                    on_remove="remove_tag"
                    on_open="open_tag_dropdown"
                    on_close="close_tag_dropdown"
                  />
                  <p class="mt-1 text-xs text-gray-500">
                    Select existing tags or type a new tag and press Enter
                  </p>
                </div>
                <.input type="checkbox" field={@form[:is_published]} label="Published" />
              </.form>
            <% else %>
              <%!-- Preview Tab --%>
              <div class="prose prose-sm max-w-none h-full overflow-auto border border-gray-200 rounded-md p-4">
                <%= if @preview_content do %>
                  {Phoenix.HTML.raw(@preview_content)}
                <% else %>
                  <p class="text-gray-500 italic">Enter content to see preview.</p>
                <% end %>
              </div>
            <% end %>
          </div>
        </:body>
        <:footer>
          <button
            type="button"
            phx-click="request_cancel"
            class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            form="article-form"
            disabled={not @form_dirty}
            class={[
              "px-4 py-2 rounded-md",
              if(@form_dirty,
                do: "bg-gf-maroon text-white hover:bg-gf-maroon/90",
                else: "bg-gray-300 text-gray-500 cursor-not-allowed"
              )
            ]}
          >
            {if @editing_article.id, do: "Save Changes", else: "Create Article"}
          </button>
        </:footer>
      </.modal>

      <%!-- Delete Confirmation Modal --%>
      <.modal :if={@delete_article} id="delete-modal" show on_cancel={JS.push("cancel_delete")}>
        <:header>Delete Article</:header>
        <:body>
          <p class="text-gray-600 mb-4">
            Are you sure you want to delete "<strong>{@delete_article.title}</strong>"? This action cannot be undone.
          </p>
        </:body>
        <:footer>
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
        </:footer>
      </.modal>

      <%!-- Discard Changes Confirmation Modal --%>
      <.discard_confirm_modal show={@show_discard_confirm} />

      <%!-- Image Browser Modal --%>
      <.modal
        :if={@show_image_browser}
        id="image-browser-modal"
        show
        on_cancel={JS.push("close_image_browser")}
        class="!max-w-[70vw]"
      >
        <:header>Browse Article Images</:header>
        <:body>
          <p class="text-sm text-gray-500 mb-4">
            Click an image to insert its markdown link at the cursor position in the content editor.
          </p>

          <%= if @article_images == [] do %>
            <div class="p-8 text-center text-gray-500">
              <.icon name="ph-images" class="h-12 w-12 mx-auto text-gray-300 mb-4" />
              <p>No images found. Upload some images first.</p>
            </div>
          <% else %>
            <div class="max-h-[60vh] overflow-y-auto">
              <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
                <%= for image <- @article_images do %>
                  <button
                    type="button"
                    phx-click="select_image"
                    phx-value-url={image.url}
                    phx-value-name={image.name}
                    class="group relative aspect-square bg-gray-100 rounded-lg overflow-hidden border-2 border-transparent hover:border-gf-maroon focus:border-gf-maroon focus:outline-none"
                  >
                    <img
                      src={image.url}
                      alt={image.name}
                      class="w-full h-full object-cover"
                      loading="lazy"
                    />
                    <div class="absolute inset-0 bg-black/0 group-hover:bg-black/30 transition-colors flex items-center justify-center">
                      <span class="text-white text-sm font-medium opacity-0 group-hover:opacity-100 transition-opacity">
                        Select
                      </span>
                    </div>
                    <div class="absolute bottom-0 left-0 right-0 bg-black/60 px-2 py-1">
                      <p class="text-white text-xs truncate">{image.folder}</p>
                    </div>
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>
        </:body>
        <:footer>
          <button
            type="button"
            phx-click="close_image_browser"
            class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Close
          </button>
        </:footer>
      </.modal>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, socket |> assign(:search_query, query) |> apply_filters()}
  end

  @impl true
  def handle_event("filter_tag", %{"tag" => tag}, socket) do
    {:noreply, socket |> assign(:tag_filter, tag) |> apply_filters()}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, socket |> assign(:status_filter, status) |> apply_filters()}
  end

  @impl true
  def handle_event("new_article", _params, socket) do
    # Pre-populate author from logged in user
    author = Auth0User.display_name(socket.assigns.current_user)

    article = %Article{author: author}
    changeset = Articles.change_article(article, %{author: author})

    socket =
      socket
      |> assign(:editing_article, article)
      |> assign(:form, to_form(changeset))
      |> assign(:form_dirty, false)
      |> assign(:preview_content, nil)
      |> assign(:active_tab, :edit)
      |> assign(:form_tags, [])
      |> assign(:tag_search_query, "")
      |> assign(:tag_dropdown_open, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_article", %{"id" => id}, socket) do
    article = Articles.get_article!(String.to_integer(id))
    changeset = Articles.change_article(article, %{})

    socket =
      socket
      |> assign(:editing_article, article)
      |> assign(:form, to_form(changeset))
      |> assign(:form_dirty, false)
      |> assign(:preview_content, render_preview(article.content))
      |> assign(:active_tab, :edit)
      |> assign(:form_tags, article.tags || [])
      |> assign(:tag_search_query, "")
      |> assign(:tag_dropdown_open, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"article" => params}, socket) do
    article = socket.assigns.editing_article
    # Include current form_tags in params for validation
    params_with_tags = Map.put(params, "tags", socket.assigns.form_tags)

    changeset =
      article
      |> Articles.change_article(normalize_params(params_with_tags))
      |> Map.put(:action, :validate)

    preview_content = render_preview(params["content"])

    socket =
      socket
      |> assign(:form, to_form(changeset))
      |> assign(:form_dirty, true)
      |> assign(:preview_content, preview_content)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_article", %{"article" => params}, socket) do
    article = socket.assigns.editing_article
    # Include current form_tags in params
    params_with_tags = Map.put(params, "tags", socket.assigns.form_tags)
    params = normalize_params(params_with_tags)

    result =
      if article.id do
        Articles.update_article(article, params)
      else
        Articles.create_article(params)
      end

    case result do
      {:ok, _saved} ->
        articles = Articles.list_articles()
        all_tags = Articles.list_all_tags()

        socket =
          socket
          |> assign(:articles, articles)
          |> assign(:all_tags, all_tags)
          |> assign(:editing_article, nil)
          |> assign(:form, nil)
          |> assign(:form_tags, [])
          |> assign(:tag_search_query, "")
          |> assign(:tag_dropdown_open, false)
          |> apply_filters()
          |> put_flash(:info, if(article.id, do: "Article updated.", else: "Article created."))

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:form, to_form(changeset))
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
      |> assign(:form_dirty, false)
      |> assign(:preview_content, nil)
      |> assign(:form_tags, [])
      |> assign(:tag_search_query, "")
      |> assign(:tag_dropdown_open, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("request_cancel", _params, socket) do
    # Ignore cancel request if the image browser is open - the user is interacting
    # with the nested modal, not trying to close the article modal
    if socket.assigns.show_image_browser do
      {:noreply, socket}
    else
      if socket.assigns.form_dirty do
        {:noreply, assign(socket, :show_discard_confirm, true)}
      else
        {:noreply,
         socket
         |> assign(:editing_article, nil)
         |> assign(:form, nil)
         |> assign(:form_dirty, false)
         |> assign(:preview_content, nil)
         |> assign(:form_tags, [])
         |> assign(:tag_search_query, "")
         |> assign(:tag_dropdown_open, false)}
      end
    end
  end

  @impl true
  def handle_event("cancel_discard", _params, socket) do
    {:noreply, assign(socket, :show_discard_confirm, false)}
  end

  @impl true
  def handle_event("confirm_discard", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_article, nil)
     |> assign(:form, nil)
     |> assign(:form_dirty, false)
     |> assign(:show_discard_confirm, false)
     |> assign(:preview_content, nil)
     |> assign(:form_tags, [])
     |> assign(:tag_search_query, "")
     |> assign(:tag_dropdown_open, false)}
  end

  @impl true
  def handle_event("open_image_browser", _params, socket) do
    images = Images.list_article_images()
    {:noreply, socket |> assign(:article_images, images) |> assign(:show_image_browser, true)}
  end

  @impl true
  def handle_event("close_image_browser", _params, socket) do
    {:noreply, assign(socket, :show_image_browser, false)}
  end

  # Tag dropdown event handlers
  @impl true
  def handle_event("tag_search", %{"value" => value}, socket) do
    {:noreply, assign(socket, :tag_search_query, value)}
  end

  @impl true
  def handle_event("open_tag_dropdown", _params, socket) do
    {:noreply, assign(socket, :tag_dropdown_open, true)}
  end

  @impl true
  def handle_event("close_tag_dropdown", _params, socket) do
    # If the user typed a new tag that doesn't exist, add it
    search_query = String.trim(socket.assigns.tag_search_query)
    form_tags = socket.assigns.form_tags

    socket =
      if search_query != "" and search_query not in form_tags do
        socket
        |> assign(:form_tags, form_tags ++ [search_query])
        |> assign(:form_dirty, true)
      else
        socket
      end

    socket =
      socket
      |> assign(:tag_dropdown_open, false)
      |> assign(:tag_search_query, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_tag", %{"id" => tag}, socket) do
    form_tags = socket.assigns.form_tags

    socket =
      if tag not in form_tags do
        socket
        |> assign(:form_tags, form_tags ++ [tag])
        |> assign(:form_dirty, true)
      else
        socket
      end

    {:noreply, assign(socket, :tag_search_query, "")}
  end

  @impl true
  def handle_event("remove_tag", %{"id" => tag}, socket) do
    form_tags = Enum.reject(socket.assigns.form_tags, &(&1 == tag))

    {:noreply,
     socket
     |> assign(:form_tags, form_tags)
     |> assign(:form_dirty, true)}
  end

  @impl true
  def handle_event("select_image", %{"url" => url, "name" => name}, socket) do
    # Generate markdown for the image
    markdown = "![#{name}](#{url})"

    # Push event to client to insert at cursor position
    socket =
      socket
      |> push_event("insert_image_markdown", %{markdown: markdown})
      |> assign(:show_image_browser, false)
      |> assign(:form_dirty, true)

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
        all_tags = Articles.list_all_tags()

        socket =
          socket
          |> assign(:articles, articles)
          |> assign(:all_tags, all_tags)
          |> assign(:delete_article, nil)
          |> apply_filters()
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
          image_url = Images.article_image_url(path)

          {:noreply,
           push_event(socket, "article_presigned_url", %{
             url: url,
             path: path,
             content_type: type,
             image_url: image_url
           })}

        {:error, reason} ->
          {:noreply,
           push_event(socket, "article_upload_error", %{
             message: "Failed to get upload URL: #{inspect(reason)}"
           })}
      end
    else
      {:noreply,
       push_event(socket, "article_upload_error", %{
         message: "Save article first before uploading images"
       })}
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

  # Normalize form params and handle is_published checkbox
  defp normalize_params(params) do
    # Tags is already a list from form_tags assign
    tags = params["tags"] || []

    params
    |> Map.put("tags", tags)
    |> Map.put("is_published", params["is_published"] == "true")
  end

  defp render_preview(nil), do: nil
  defp render_preview(""), do: nil

  defp render_preview(content) do
    {:ok, html} = Markdown.render(content)
    html
  end

  defp apply_filters(socket) do
    articles = socket.assigns.articles
    search_query = socket.assigns.search_query
    tag_filter = socket.assigns.tag_filter
    status_filter = socket.assigns.status_filter

    filtered =
      articles
      |> filter_by_search(search_query)
      |> filter_by_tag(tag_filter)
      |> filter_by_status(status_filter)

    assign(socket, :filtered_articles, filtered)
  end

  defp filter_by_search(articles, ""), do: articles

  defp filter_by_search(articles, query) do
    query_lower = String.downcase(query)

    Enum.filter(articles, fn article ->
      String.contains?(String.downcase(article.title || ""), query_lower) ||
        String.contains?(String.downcase(article.author || ""), query_lower)
    end)
  end

  defp filter_by_tag(articles, ""), do: articles

  defp filter_by_tag(articles, tag) do
    Enum.filter(articles, fn article ->
      tag in (article.tags || [])
    end)
  end

  defp filter_by_status(articles, ""), do: articles

  defp filter_by_status(articles, "published") do
    Enum.filter(articles, fn article -> article.is_published end)
  end

  defp filter_by_status(articles, "draft") do
    Enum.filter(articles, fn article -> not article.is_published end)
  end
end
