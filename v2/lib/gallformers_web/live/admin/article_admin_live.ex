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

  require Logger

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
    article_options = Articles.list_article_options()

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
      |> assign(:article_options, article_options)
      |> assign(:editing_article, nil)
      |> assign(:form, nil)
      |> assign(:form_dirty, false)
      |> assign(:show_discard_confirm, false)
      |> assign(:delete_article, nil)
      |> assign(:preview_content, nil)
      |> assign(:active_tab, :edit)
      |> assign(:show_image_browser, false)
      |> assign(:article_images, [])
      |> assign(:image_browser_filter, "")
      # Image insert modal state
      |> assign(:show_image_insert_modal, false)
      |> assign(:selected_image, nil)
      |> assign(:image_insert_form, nil)
      # Image delete confirmation state
      |> assign(:image_to_delete, nil)
      |> assign(:image_references, [])
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
                        class="font-medium hover:underline text-left"
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

          <div class="max-h-[600px] overflow-y-auto">
            <%= if @active_tab == :edit do %>
              <.form
                for={@form}
                id="article-form"
                phx-submit="save_article"
                phx-change="validate"
                class="space-y-4"
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
                <div>
                  <label class="gf-label">
                    Content (Markdown)
                  </label>
                  <textarea
                    name={@form[:content].name}
                    id={@form[:content].id}
                    class="w-full rounded-md border border-gray-300 shadow-sm focus:border-gf-maroon focus:ring-gf-maroon font-mono text-sm resize-y min-h-[300px]"
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

          <%!-- Image Browser Panel (inside article modal) --%>
          <div :if={@show_image_browser} class="absolute inset-0 bg-white z-10 flex flex-col">
            <div class="flex items-center justify-between p-4 border-b border-gray-200">
              <h3 class="text-lg font-semibold text-gray-900">Browse Article Images</h3>
              <button
                type="button"
                phx-click="close_image_browser"
                class="text-gray-400 hover:text-gray-600"
              >
                <.icon name="ph-x" class="h-6 w-6" />
              </button>
            </div>
            <div class="flex-1 overflow-y-auto p-4">
              <div class="flex items-center justify-between mb-4">
                <p class="text-sm text-gray-500">
                  Click an image to insert it at the cursor position.
                </p>
                <form phx-change="filter_images_by_article" id="image-article-filter" class="w-64">
                  <.input
                    type="select"
                    name="article_id"
                    prompt="All Articles"
                    options={Enum.map(@article_options, fn {id, title} -> {title, id} end)}
                    value={@image_browser_filter}
                  />
                </form>
              </div>

              <%= if @article_images == [] do %>
                <div class="p-8 text-center text-gray-500">
                  <.icon name="ph-images" class="h-12 w-12 mx-auto text-gray-300 mb-4" />
                  <%= if @image_browser_filter == "" do %>
                    <p>No images found. Upload some images first.</p>
                  <% else %>
                    <p>
                      No images for this article. Try selecting a different article or "All Articles".
                    </p>
                  <% end %>
                </div>
              <% else %>
                <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
                  <%= for image <- @article_images do %>
                    <div class="group relative aspect-square bg-gray-100 rounded-lg overflow-hidden border-2 border-transparent hover:border-gf-maroon">
                      <img
                        src={image.url}
                        alt={image.name}
                        class="w-full h-full object-cover"
                        loading="lazy"
                      />
                      <div class="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-colors flex items-center justify-center gap-2">
                        <button
                          type="button"
                          phx-click="select_image"
                          phx-value-url={image.url}
                          phx-value-name={image.name}
                          class="opacity-0 group-hover:opacity-100 transition-opacity px-3 py-1.5 bg-gf-maroon text-white text-sm font-medium rounded hover:bg-gf-maroon/80"
                        >
                          Insert
                        </button>
                        <button
                          type="button"
                          phx-click="confirm_delete_image"
                          phx-value-url={image.url}
                          phx-value-path={image.path}
                          phx-value-name={image.name}
                          class="opacity-0 group-hover:opacity-100 transition-opacity px-3 py-1.5 bg-red-600 text-white text-sm font-medium rounded hover:bg-red-700"
                        >
                          Delete
                        </button>
                      </div>
                      <div class="absolute bottom-0 left-0 right-0 bg-black/60 px-2 py-1">
                        <p class="text-white text-xs truncate">
                          {get_article_title(@article_options, image.article_id) || image.folder}
                        </p>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
            <div class="p-4 border-t border-gray-200 flex justify-end">
              <button
                type="button"
                phx-click="close_image_browser"
                class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
              >
                Close
              </button>
            </div>

            <%!-- Image Insert Panel (overlay within image browser) --%>
            <div
              :if={@show_image_insert_modal && @selected_image}
              class="absolute inset-0 bg-black/50 flex items-center justify-center z-20"
            >
              <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
                <div class="flex items-center justify-between p-4 border-b border-gray-200">
                  <h4 class="text-lg font-semibold text-gray-900">Insert Image</h4>
                  <button
                    type="button"
                    phx-click="close_image_insert_modal"
                    class="text-gray-400 hover:text-gray-600"
                  >
                    <.icon name="ph-x" class="h-5 w-5" />
                  </button>
                </div>
                <div class="p-4 space-y-4">
                  <div class="flex justify-center bg-gray-100 rounded-lg p-4">
                    <img
                      src={@selected_image.url}
                      alt="Preview"
                      class="max-h-48 object-contain rounded"
                    />
                  </div>
                  <.form
                    for={@image_insert_form}
                    id="image-insert-form"
                    phx-submit="insert_image"
                    phx-change="validate_image_insert"
                    class="space-y-4"
                  >
                    <div>
                      <.input
                        field={@image_insert_form[:alt_text]}
                        label="Alt Text"
                        placeholder="Describe the image for accessibility"
                        required
                      />
                      <p class="mt-1 text-xs text-gray-500">
                        Required. Describes the image for screen readers.
                      </p>
                    </div>
                    <div>
                      <.input
                        field={@image_insert_form[:caption]}
                        label="Caption (Optional)"
                        placeholder="Optional visible caption below the image"
                      />
                    </div>
                    <div>
                      <label class="gf-label">Display Size</label>
                      <div class="mt-2 space-y-2">
                        <div class="flex flex-wrap gap-2">
                          <label class="inline-flex items-center">
                            <input
                              type="radio"
                              name={@image_insert_form[:size_preset].name}
                              value="small"
                              checked={
                                Phoenix.HTML.Form.input_value(@image_insert_form, :size_preset) ==
                                  "small"
                              }
                              class="mr-2"
                            /> Small (200px)
                          </label>
                          <label class="inline-flex items-center">
                            <input
                              type="radio"
                              name={@image_insert_form[:size_preset].name}
                              value="medium"
                              checked={
                                Phoenix.HTML.Form.input_value(@image_insert_form, :size_preset) ==
                                  "medium"
                              }
                              class="mr-2"
                            /> Medium (400px)
                          </label>
                          <label class="inline-flex items-center">
                            <input
                              type="radio"
                              name={@image_insert_form[:size_preset].name}
                              value="large"
                              checked={
                                Phoenix.HTML.Form.input_value(@image_insert_form, :size_preset) ==
                                  "large"
                              }
                              class="mr-2"
                            /> Large (600px)
                          </label>
                          <label class="inline-flex items-center">
                            <input
                              type="radio"
                              name={@image_insert_form[:size_preset].name}
                              value="full"
                              checked={
                                Phoenix.HTML.Form.input_value(@image_insert_form, :size_preset) ==
                                  "full"
                              }
                              class="mr-2"
                            /> Full Width
                          </label>
                          <label class="inline-flex items-center">
                            <input
                              type="radio"
                              name={@image_insert_form[:size_preset].name}
                              value="custom"
                              checked={
                                Phoenix.HTML.Form.input_value(@image_insert_form, :size_preset) ==
                                  "custom"
                              }
                              class="mr-2"
                            /> Custom
                          </label>
                        </div>
                        <%= if Phoenix.HTML.Form.input_value(@image_insert_form, :size_preset) == "custom" do %>
                          <div class="flex items-center gap-2">
                            <.input
                              field={@image_insert_form[:custom_width]}
                              type="number"
                              placeholder="Width in pixels"
                              min="50"
                              max="2000"
                              class="w-32"
                            />
                            <span class="text-sm text-gray-500">pixels</span>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </.form>
                </div>
                <div class="p-4 border-t border-gray-200 flex justify-end gap-2">
                  <button
                    type="button"
                    phx-click="close_image_insert_modal"
                    class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    form="image-insert-form"
                    class="px-4 py-2 bg-gf-maroon text-white rounded-md hover:bg-gf-maroon/90"
                  >
                    Insert Image
                  </button>
                </div>
              </div>
            </div>

            <%!-- Image Delete Confirmation Panel (overlay within image browser) --%>
            <div
              :if={@image_to_delete}
              class="absolute inset-0 bg-black/50 flex items-center justify-center z-20"
            >
              <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
                <div class="flex items-center justify-between p-4 border-b border-gray-200">
                  <h4 class="text-lg font-semibold text-gray-900">Delete Image</h4>
                  <button
                    type="button"
                    phx-click="cancel_delete_image"
                    class="text-gray-400 hover:text-gray-600"
                  >
                    <.icon name="ph-x" class="h-5 w-5" />
                  </button>
                </div>
                <div class="p-4 space-y-4">
                  <div class="flex justify-center bg-gray-100 rounded-lg p-4">
                    <img
                      src={@image_to_delete.url}
                      alt="Image to delete"
                      class="max-h-32 object-contain rounded"
                    />
                  </div>
                  <%= if @image_references == [] do %>
                    <p class="text-gray-600">
                      Are you sure you want to delete this image? This action cannot be undone.
                    </p>
                  <% else %>
                    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                      <div class="flex items-start gap-2">
                        <.icon name="ph-warning" class="h-5 w-5 text-yellow-600 mt-0.5" />
                        <div>
                          <p class="text-yellow-800 font-medium">
                            This image is referenced in {length(@image_references)} article{if length(
                                                                                                 @image_references
                                                                                               ) != 1,
                                                                                               do:
                                                                                                 "s",
                                                                                               else:
                                                                                                 ""}:
                          </p>
                          <ul class="mt-2 text-sm text-yellow-700 list-disc list-inside">
                            <%= for {_id, title} <- @image_references do %>
                              <li>{title}</li>
                            <% end %>
                          </ul>
                          <p class="mt-2 text-yellow-700 text-sm">
                            Deleting this image will break these references.
                          </p>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
                <div class="p-4 border-t border-gray-200 flex justify-end gap-2">
                  <button
                    type="button"
                    phx-click="cancel_delete_image"
                    class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    phx-click="delete_image"
                    class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
                  >
                    {if @image_references == [], do: "Delete", else: "Delete Anyway"}
                  </button>
                </div>
              </div>
            </div>
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
    cond do
      # Close innermost panel first
      socket.assigns.image_to_delete != nil ->
        {:noreply,
         socket
         |> assign(:image_to_delete, nil)
         |> assign(:image_references, [])}

      socket.assigns.show_image_insert_modal ->
        {:noreply,
         socket
         |> assign(:show_image_insert_modal, false)
         |> assign(:selected_image, nil)
         |> assign(:image_insert_form, nil)}

      socket.assigns.show_image_browser ->
        {:noreply, assign(socket, :show_image_browser, false)}

      # No panels open - handle modal close
      socket.assigns.form_dirty ->
        {:noreply, assign(socket, :show_discard_confirm, true)}

      true ->
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
    # Default to current article's images if editing an article
    article = socket.assigns.editing_article

    {images, filter} =
      if article && article.id do
        {Images.list_article_images_for_article(article.id), article.id}
      else
        {Images.list_article_images(), ""}
      end

    {:noreply,
     socket
     |> assign(:article_images, images)
     |> assign(:image_browser_filter, filter)
     |> assign(:show_image_browser, true)}
  end

  @impl true
  def handle_event("close_image_browser", _params, socket) do
    {:noreply, assign(socket, :show_image_browser, false)}
  end

  @impl true
  def handle_event("filter_images_by_article", %{"article_id" => ""}, socket) do
    images = Images.list_article_images()

    {:noreply,
     socket
     |> assign(:article_images, images)
     |> assign(:image_browser_filter, "")}
  end

  @impl true
  def handle_event("filter_images_by_article", %{"article_id" => article_id}, socket) do
    article_id = String.to_integer(article_id)
    images = Images.list_article_images_for_article(article_id)

    {:noreply,
     socket
     |> assign(:article_images, images)
     |> assign(:image_browser_filter, article_id)}
  end

  @impl true
  def handle_event(
        "confirm_delete_image",
        %{"url" => url, "path" => path, "name" => name},
        socket
      ) do
    # Check which articles reference this image
    references = Articles.find_articles_referencing_image(url)

    image_to_delete = %{url: url, path: path, name: name}

    {:noreply,
     socket
     |> assign(:image_to_delete, image_to_delete)
     |> assign(:image_references, references)}
  end

  @impl true
  def handle_event("cancel_delete_image", _params, socket) do
    {:noreply,
     socket
     |> assign(:image_to_delete, nil)
     |> assign(:image_references, [])}
  end

  @impl true
  def handle_event("delete_image", _params, socket) do
    image = socket.assigns.image_to_delete
    Logger.info("Deleting image: path=#{inspect(image.path)}, url=#{inspect(image.url)}")

    case Images.delete_article_image(image.path) do
      :ok ->
        # Refresh the image list
        images =
          case socket.assigns.image_browser_filter do
            "" -> Images.list_article_images()
            article_id -> Images.list_article_images_for_article(article_id)
          end

        {:noreply,
         socket
         |> assign(:article_images, images)
         |> assign(:image_to_delete, nil)
         |> assign(:image_references, [])
         |> put_flash(:info, "Image deleted.")}

      {:error, reason} ->
        Logger.error(
          "Failed to delete image: path=#{inspect(image.path)}, reason=#{inspect(reason)}"
        )

        error_message = format_s3_error(reason)

        {:noreply,
         socket
         |> assign(:image_to_delete, nil)
         |> assign(:image_references, [])
         |> put_flash(:error, error_message)}
    end
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
    # Open the image insert modal with default values
    selected_image = %{url: url, name: name}

    form =
      to_form(%{
        "alt_text" => "",
        "caption" => "",
        "size_preset" => "medium",
        "custom_width" => ""
      })

    socket =
      socket
      |> assign(:selected_image, selected_image)
      |> assign(:image_insert_form, form)
      |> assign(:show_image_insert_modal, true)
      |> assign(:show_image_browser, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_image_insert", params, socket) do
    # Just update the form with new values
    form = to_form(params)
    {:noreply, assign(socket, :image_insert_form, form)}
  end

  @impl true
  def handle_event("close_image_insert_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_image_insert_modal, false)
     |> assign(:selected_image, nil)
     |> assign(:image_insert_form, nil)}
  end

  @impl true
  def handle_event("insert_image", params, socket) do
    selected_image = socket.assigns.selected_image
    alt_text = String.trim(params["alt_text"] || "")
    caption = String.trim(params["caption"] || "")
    size_preset = params["size_preset"] || "medium"
    custom_width = params["custom_width"]

    # Validate alt text is provided
    if alt_text == "" do
      socket =
        socket
        |> put_flash(:error, "Alt text is required for accessibility")

      {:noreply, socket}
    else
      # Calculate width
      width =
        case size_preset do
          "small" -> 200
          "medium" -> 400
          "large" -> 600
          "full" -> nil
          "custom" -> parse_custom_width(custom_width)
        end

      # Generate HTML
      html = generate_image_html(selected_image.url, alt_text, caption, width)

      # Push event to client to insert at cursor position
      socket =
        socket
        |> push_event("insert_image_markdown", %{markdown: html})
        |> assign(:show_image_insert_modal, false)
        |> assign(:selected_image, nil)
        |> assign(:image_insert_form, nil)
        |> assign(:form_dirty, true)

      {:noreply, socket}
    end
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
      path = Images.generate_article_path(article.id, ext)

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
  def handle_event("article_image_uploaded", %{"path" => _path}, socket) do
    socket =
      socket
      |> put_flash(:info, "Image uploaded! Use 'Browse Images' to insert it.")

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

  # Image browser helpers

  defp format_s3_error({:http_error, 403, %{body: body}}) when is_binary(body) do
    cond do
      String.contains?(body, "AccessDenied") and String.contains?(body, "DeleteObject") ->
        "Permission denied: The S3 user doesn't have delete permissions. Contact an administrator."

      String.contains?(body, "AccessDenied") ->
        "Permission denied: Access to S3 was denied."

      true ->
        "Failed to delete image (403 Forbidden)"
    end
  end

  defp format_s3_error({:http_error, status, _}) do
    "Failed to delete image (HTTP #{status})"
  end

  defp format_s3_error(reason) do
    "Failed to delete image: #{inspect(reason)}"
  end

  defp get_article_title(_article_options, nil), do: nil

  defp get_article_title(article_options, article_id) do
    case Enum.find(article_options, fn {id, _title} -> id == article_id end) do
      {_, title} -> title
      nil -> nil
    end
  end

  # Image insert helpers

  defp parse_custom_width(nil), do: 400
  defp parse_custom_width(""), do: 400

  defp parse_custom_width(value) when is_binary(value) do
    case Integer.parse(value) do
      {width, _} when width >= 50 and width <= 2000 -> width
      _ -> 400
    end
  end

  defp parse_custom_width(_), do: 400

  defp generate_image_html(url, alt_text, caption, width) do
    # Escape special characters in alt text and caption
    escaped_alt = Phoenix.HTML.html_escape(alt_text) |> Phoenix.HTML.safe_to_string()
    width_attr = if width, do: " width=\"#{width}\"", else: ""

    if caption == "" do
      # Just an img tag
      "<img src=\"#{url}\" alt=\"#{escaped_alt}\"#{width_attr}>"
    else
      # Wrap in figure with figcaption
      escaped_caption = Phoenix.HTML.html_escape(caption) |> Phoenix.HTML.safe_to_string()

      """
      <figure>
        <img src="#{url}" alt="#{escaped_alt}"#{width_attr}>
        <figcaption>#{escaped_caption}</figcaption>
      </figure>
      """
      |> String.trim()
    end
  end
end
