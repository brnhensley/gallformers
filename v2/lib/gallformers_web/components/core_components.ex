defmodule GallformersWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework.
  Here are useful references:

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: GallformersWeb.Gettext

  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :auto_dismiss, :integer, default: nil, doc: "auto-dismiss after this many milliseconds"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-hook={@auto_dismiss && "AutoDismiss"}
      data-dismiss-after={@auto_dismiss}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="gf-toast"
      {@rest}
    >
      <div class={[
        "gf-alert",
        @kind == :info && "gf-alert-info",
        @kind == :error && "gf-alert-error"
      ]}>
        <.icon :if={@kind == :info} name="ph-info" class="gf-alert-icon size-5 shrink-0" />
        <.icon :if={@kind == :error} name="ph-warning-circle" class="gf-alert-icon size-5 shrink-0" />
        <div class="flex-1 min-w-0">
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <button type="button" class="group shrink-0 cursor-pointer" aria-label={gettext("close")}>
          <.icon name="ph-x" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "gf-btn-primary", nil => "gf-btn-soft"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["gf-btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset">
      <label>
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <span class="label text-base font-medium text-gray-700">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "gf-checkbox"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset">
      <label>
        <span :if={@label} class="label mb-2 text-base font-medium text-gray-700">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "gf-select", @errors != [] && (@error_class || "gf-select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset">
      <label>
        <span :if={@label} class="label mb-2 text-base font-medium text-gray-700">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "gf-textarea",
            @errors != [] && (@error_class || "gf-textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset">
      <label>
        <span :if={@label} class="label mb-2 text-base font-medium text-gray-700">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "gf-input",
            @errors != [] && (@error_class || "gf-input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="ph-warning-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-gray-500">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>

      <.table id="users" rows={@users} variant="compact">
        <:col :let={user} label="id">{user.id}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :variant, :string,
    default: "default",
    values: ~w(default compact),
    doc: "table density variant"

  attr :zebra, :boolean, default: true, doc: "whether to show zebra striping"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class={[
      "gf-table",
      @variant == "compact" && "gf-table-compact",
      @zebra && "gf-table-zebra"
    ]}>
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="gf-list">
      <li :for={item <- @item} class="gf-list-row">
        <div class="gf-list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders an icon from the Gallformers icon library.

  Two icon sources are available:
  - `gf-*` prefix: Custom gallformers domain icons (gall, host, taxon, source, place)
  - `ph-*` prefix: Phosphor icons (MIT licensed)

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are bundled within your compiled app.css by the plugin
  in `assets/vendor/icons.js`.

  ## Examples

      <.icon name="ph-x" />
      <.icon name="ph-arrows-clockwise" class="ml-1 size-3 motion-safe:animate-spin" />
      <.icon name="gf-gall" class="size-6 text-gf-maroon" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "gf-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def icon(%{name: "ph-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a single-select typeahead component with server-side search.

  Displays a search input that shows results in a dropdown. When an item is selected,
  it displays the selection with a clear button. Includes full keyboard navigation
  via the Typeahead JS hook.

  ## Keyboard behavior
  - Arrow Down/Up: Navigate through results
  - Enter: Select highlighted item
  - Escape: Clear results or selection
  - Backspace/Delete on selection: Clear and focus input
  - Type on selection: Clear and start new search

  ## Events

  The component emits events using the provided event names:
  - `search_event` - when user types (params: %{"value" => query})
  - `select_event` - when user selects an option (params: %{"id" => id})
  - `clear_event` - when user clears the selection

  ## Examples

      <.typeahead
        id="host-picker"
        label="Host:"
        placeholder="Search hosts..."
        search_event="search_host"
        select_event="select_host"
        clear_event="clear_host"
        query={@host_query}
        results={@host_results}
        selected={@selected_host}
        display_fn={fn host -> host.name end}
      />
  """
  attr :id, :string, required: true, doc: "unique identifier for the component"
  attr :label, :string, required: true, doc: "label text"
  attr :placeholder, :string, default: "Search...", doc: "placeholder for the input"
  attr :search_event, :string, required: true, doc: "event name for search"
  attr :select_event, :string, required: true, doc: "event name for selection"
  attr :clear_event, :string, required: true, doc: "event name for clearing"
  attr :query, :string, required: true, doc: "current search query"
  attr :results, :list, required: true, doc: "list of search results"
  attr :selected, :any, default: nil, doc: "currently selected item"
  attr :display_fn, :any, required: true, doc: "function to display an item (fn item -> string)"
  attr :result_slot, :any, default: nil, doc: "optional slot for custom result rendering"
  attr :class, :string, default: "", doc: "additional CSS classes for the wrapper"

  slot :result, doc: "optional slot for custom result item rendering" do
    attr :item, :any
  end

  def typeahead(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="Typeahead"
      data-clear-event={@clear_event}
      data-search-event={@search_event}
      data-input-id={"#{@id}-input"}
      class={@class}
    >
      <label class="block text-base font-medium text-gray-700 mb-1">{@label}</label>
      <%= if @selected do %>
        <div
          id={"#{@id}-selected"}
          data-typeahead-selected
          class="flex items-center gap-2 p-2 bg-gray-50 rounded border focus:ring-2 focus:ring-gf-maroon focus:border-gf-maroon cursor-text"
          tabindex="0"
          role="combobox"
          aria-expanded="false"
          aria-label={"Selected: #{@display_fn.(@selected)}. Type to search, or press Escape to clear."}
        >
          <span class="flex-1 text-base italic">{@display_fn.(@selected)}</span>
          <button
            type="button"
            phx-click={@clear_event}
            class="text-gray-400 hover:text-gray-600"
            aria-label="Clear selection"
            tabindex="-1"
          >
            <.icon name="ph-x" class="size-4" />
          </button>
        </div>
      <% else %>
        <div class="relative">
          <input
            id={"#{@id}-input"}
            data-typeahead-input
            type="text"
            value={@query}
            phx-keyup={@search_event}
            phx-debounce="200"
            placeholder={@placeholder}
            class="w-full px-3 py-2 border border-gray-300 rounded-md text-base focus:ring-gf-maroon focus:border-gf-maroon"
            role="combobox"
            aria-expanded={length(@results) > 0}
            aria-controls={"#{@id}-results"}
            aria-autocomplete="list"
          />
          <div
            :if={length(@results) > 0}
            id={"#{@id}-results"}
            data-typeahead-results
            class="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto"
            role="listbox"
          >
            <button
              :for={item <- @results}
              type="button"
              data-typeahead-option
              phx-click={@select_event}
              phx-value-id={item.id}
              class="w-full text-left px-3 py-2 text-base hover:bg-gray-50 border-b border-gray-100 last:border-b-0"
              role="option"
            >
              <%= if @result != [] do %>
                {render_slot(@result, item)}
              <% else %>
                <span class="italic">{@display_fn.(item)}</span>
              <% end %>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a multi-select typeahead component.

  Displays selected items as removable tags, with a text input for filtering
  and a dropdown showing available options.

  ## Events

  The component emits events prefixed with the `name` attribute:
  - `{name}_search` - when user types in the input (params: %{"value" => query})
  - `{name}_focus` - when input receives focus
  - `{name}_blur` - when input loses focus
  - `{name}_select` - when user selects an option (params: %{"id" => id})
  - `{name}_remove` - when user removes a selected item (params: %{"id" => id})
  - `{name}_clear` - when user clicks the clear all button

  ## Examples

      <.multi_select_typeahead
        id="locations"
        name="location"
        label="Location(s):"
        placeholder="Locations"
        options={@filter_options.locations}
        selected={@filters.locations}
        option_label={:location}
        query={@location_query}
        focused={@location_focused}
      />
  """
  attr :id, :string, required: true, doc: "unique identifier for the component"
  attr :name, :string, required: true, doc: "name prefix for events"
  attr :label, :string, required: true, doc: "label text"
  attr :placeholder, :string, default: "", doc: "placeholder when no items selected"
  attr :options, :list, required: true, doc: "list of all available options"
  attr :selected, :list, required: true, doc: "list of selected option ids"
  attr :option_label, :atom, required: true, doc: "field name to display from option map"
  attr :query, :string, required: true, doc: "current search query"
  attr :focused, :boolean, required: true, doc: "whether the input is focused"

  def multi_select_typeahead(assigns) do
    option_label = assigns.option_label

    # Get selected option objects
    selected_options = Enum.filter(assigns.options, fn opt -> opt.id in assigns.selected end)

    # Filter available options based on query
    query_lower = String.downcase(assigns.query)

    filtered_options =
      assigns.options
      |> Enum.reject(fn opt -> opt.id in assigns.selected end)
      |> Enum.filter(fn opt ->
        label = Map.get(opt, option_label, "")
        assigns.query == "" or String.contains?(String.downcase(label), query_lower)
      end)

    assigns =
      assigns
      |> assign(:selected_options, selected_options)
      |> assign(:filtered_options, filtered_options)

    ~H"""
    <div
      id={"#{@id}-wrapper"}
      phx-hook="Typeahead"
      data-clear-event={"#{@name}_clear"}
      data-search-event={"#{@name}_search"}
      data-input-id={@id}
      class="mb-2"
    >
      <label class="block text-base font-medium text-gray-700 mb-1">{@label}</label>
      <div class="relative">
        <%!-- Selected tags and input --%>
        <div class="flex flex-wrap gap-1 p-2 border border-gray-300 rounded-md bg-white min-h-[42px]">
          <span
            :for={opt <- @selected_options}
            class="inline-flex items-center gap-1 px-2 py-0.5 bg-gray-100 text-gray-800 rounded text-sm"
          >
            {Map.get(opt, @option_label)}
            <button
              type="button"
              phx-click={"#{@name}_remove"}
              phx-value-id={to_string(opt.id)}
              class="text-gray-500 hover:text-gray-700"
            >
              <.icon name="ph-x" class="size-3" />
            </button>
          </span>
          <input
            type="text"
            id={@id}
            data-typeahead-input
            value={@query}
            phx-keyup={"#{@name}_search"}
            phx-focus={"#{@name}_focus"}
            phx-blur={"#{@name}_blur"}
            phx-debounce="100"
            placeholder={if @selected_options == [], do: @placeholder, else: ""}
            class="flex-1 min-w-[80px] border-0 p-0 text-base focus:ring-0 focus:outline-none"
            role="combobox"
            aria-expanded={@focused and length(@filtered_options) > 0}
            aria-controls={"#{@id}-results"}
            aria-autocomplete="list"
          />
          <%!-- Clear all button --%>
          <button
            :if={@selected_options != []}
            type="button"
            phx-click={"#{@name}_clear"}
            class="flex-shrink-0 text-gray-400 hover:text-gray-600 p-1"
            title="Clear all"
          >
            <.icon name="ph-x" class="size-4" />
          </button>
        </div>
        <%!-- Dropdown --%>
        <div
          :if={@focused and length(@filtered_options) > 0}
          id={"#{@id}-results"}
          data-typeahead-results
          class="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-48 overflow-auto"
          role="listbox"
          onmousedown="event.preventDefault()"
        >
          <div
            :for={opt <- @filtered_options}
            data-typeahead-option
            phx-click={"#{@name}_select"}
            phx-value-id={to_string(opt.id)}
            class="w-full text-left px-3 py-2 text-base hover:bg-gray-50 border-b border-gray-100 last:border-b-0 cursor-pointer"
            role="option"
          >
            {Map.get(opt, @option_label)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a data complete/in progress badge.

  Used on species (gall/host) and source pages to indicate data completeness.

  ## Examples

      <.data_complete_badge
        complete={true}
        complete_tooltip="All data has been entered."
        incomplete_tooltip="Data entry is still in progress."
      />
  """
  attr :complete, :boolean, required: true, doc: "whether the data is complete"
  attr :complete_tooltip, :string, required: true, doc: "tooltip when complete"
  attr :incomplete_tooltip, :string, required: true, doc: "tooltip when incomplete"

  def data_complete_badge(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex items-center px-2 py-1 text-xs font-medium rounded-full cursor-help",
        if(@complete,
          do: "bg-green-100 text-green-800",
          else: "bg-yellow-100 text-yellow-800"
        )
      ]}
      title={if @complete, do: @complete_tooltip, else: @incomplete_tooltip}
    >
      {if @complete, do: "Complete", else: "In Progress"}
    </span>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(GallformersWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(GallformersWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
