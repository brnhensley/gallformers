defmodule GallformersWeb.FormComponents do
  @moduledoc """
  Form-related components for the Gallformers application.

  Provides enhanced form inputs, multi-select controls, and other
  form-related UI elements that extend Phoenix's core form components.
  """
  use Phoenix.Component
  use Gettext, backend: GallformersWeb.Gettext

  import GallformersWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a button with multiple variants.

  This extends the core button component with additional variants
  matching the v2_old Svelte implementation.

  ## Variants

    * `primary` - Maroon background, white text (default)
    * `secondary` - White background, gray text, gray border
    * `danger` - Red background, white text
    * `warning` - Yellow background, white text
    * `ghost` - Transparent background, maroon text

  ## Examples

      <.btn>Default Button</.btn>
      <.btn variant="primary">Primary</.btn>
      <.btn variant="secondary">Secondary</.btn>
      <.btn variant="danger">Delete</.btn>
      <.btn variant="ghost">Cancel</.btn>
      <.btn variant="primary" size="sm">Small</.btn>
      <.btn variant="primary" size="lg">Large</.btn>
      <.btn navigate={~p"/home"}>Go Home</.btn>
  """
  attr :variant, :string,
    default: "primary",
    values: ~w(primary secondary danger warning ghost),
    doc: "button style variant"

  attr :size, :string,
    default: "md",
    values: ~w(sm md lg),
    doc: "button size"

  attr :class, :any, default: nil, doc: "additional CSS classes"

  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type form)

  slot :inner_block, required: true

  def btn(%{rest: rest} = assigns) do
    variant_classes = %{
      "primary" => "bg-gf-maroon text-white hover:bg-gf-maroon/90 focus:ring-gf-maroon",
      "secondary" =>
        "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-gray-500",
      "danger" => "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500",
      "warning" => "bg-yellow-500 text-white hover:bg-yellow-600 focus:ring-yellow-500",
      "ghost" => "text-gf-maroon hover:bg-gf-maroon/10 focus:ring-gf-maroon"
    }

    size_classes = %{
      "sm" => "px-2.5 py-1 text-sm",
      "md" => "px-4 py-2 text-sm",
      "lg" => "px-6 py-3 text-base"
    }

    base_classes =
      "inline-flex items-center justify-center rounded-md font-medium transition-colors " <>
        "focus:outline-none focus:ring-2 focus:ring-offset-2 " <>
        "disabled:opacity-50 disabled:cursor-not-allowed"

    assigns =
      assigns
      |> assign(:variant_class, Map.fetch!(variant_classes, assigns.variant))
      |> assign(:size_class, Map.fetch!(size_classes, assigns.size))
      |> assign(:base_classes, base_classes)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={[@base_classes, @variant_class, @size_class, @class]} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={[@base_classes, @variant_class, @size_class, @class]} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders a multi-select component with pill-style toggle buttons.

  ## Examples

      <.multi_select
        id="shapes"
        label="Select Shapes"
        options={[%{value: "round", label: "Round"}, %{value: "oval", label: "Oval"}]}
        selected={@selected_shapes}
        on_toggle="toggle_shape"
      />
  """
  attr :id, :string, required: true, doc: "unique id for the component"
  attr :label, :string, default: nil, doc: "optional label"
  attr :options, :list, required: true, doc: "list of %{value: _, label: _} maps"
  attr :selected, :list, default: [], doc: "list of selected values"
  attr :on_toggle, :string, required: true, doc: "event name for toggle"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def multi_select(assigns) do
    ~H"""
    <div id={@id} class={@class}>
      <label :if={@label} class="block text-base font-medium text-gray-700 mb-2">
        {@label}
      </label>
      <div class="flex flex-wrap gap-2">
        <button
          :for={option <- @options}
          type="button"
          phx-click={@on_toggle}
          phx-value-value={option.value}
          class={[
            "px-3 py-1 rounded-full text-sm border transition-colors",
            (option.value in @selected || to_string(option.value) in @selected) &&
              "bg-gf-maroon text-white border-gf-maroon",
            !(option.value in @selected || to_string(option.value) in @selected) &&
              "bg-white text-gray-700 border-gray-300 hover:border-gf-maroon"
          ]}
        >
          {option.label}
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a search input with icon.

  ## Examples

      <.search_input
        id="species-search"
        name="query"
        value={@query}
        placeholder="Search species..."
        phx-change="search"
      />
  """
  attr :id, :string, required: true, doc: "unique id for the input"
  attr :name, :string, required: true, doc: "input name"
  attr :value, :string, default: "", doc: "current value"
  attr :placeholder, :string, default: "Search...", doc: "placeholder text"
  attr :class, :any, default: nil, doc: "additional CSS classes"
  attr :rest, :global, include: ~w(phx-change phx-submit phx-debounce form data-typeahead-input)

  def search_input(assigns) do
    ~H"""
    <div class={["relative", @class]}>
      <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
        <.icon name="ph-magnifying-glass" class="size-5 text-gray-400" />
      </div>
      <input
        type="search"
        id={@id}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-gf-maroon focus:border-gf-maroon sm:text-sm"
        {@rest}
      />
    </div>
    """
  end

  @doc """
  Renders a form field wrapper with label and error display.

  This is a simpler alternative to the full input component when you
  need more control over the actual input element.

  ## Examples

      <.field_wrapper label="Species Name" error={@errors[:name]}>
        <input type="text" name="name" class="..." />
      </.field_wrapper>
  """
  attr :label, :string, required: true, doc: "field label"
  attr :error, :any, default: nil, doc: "error message or nil"
  attr :required, :boolean, default: false, doc: "whether the field is required"
  attr :hint, :string, default: nil, doc: "optional hint text"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  slot :inner_block, required: true

  def field_wrapper(assigns) do
    ~H"""
    <div class={["mb-4", @class]}>
      <label class="block text-base font-medium text-gray-700 mb-1">
        {@label}
        <span :if={@required} class="text-red-500">*</span>
      </label>
      {render_slot(@inner_block)}
      <p :if={@hint && !@error} class="mt-1 text-sm text-gray-500">
        {@hint}
      </p>
      <p :if={@error} class="mt-1 text-sm text-red-500 flex items-center gap-1">
        <.icon name="ph-warning-circle" class="size-4" />
        {@error}
      </p>
    </div>
    """
  end

  @doc """
  Renders a toggle switch.

  ## Examples

      <.toggle
        id="auto-save"
        name="auto_save"
        checked={@auto_save}
        label="Enable auto-save"
      />
  """
  attr :id, :string, required: true, doc: "unique id for the toggle"
  attr :name, :string, required: true, doc: "form input name"
  attr :checked, :boolean, default: false, doc: "whether the toggle is on"
  attr :label, :string, default: nil, doc: "optional label"
  attr :disabled, :boolean, default: false, doc: "whether the toggle is disabled"
  attr :class, :any, default: nil, doc: "additional CSS classes"
  attr :rest, :global

  def toggle(assigns) do
    ~H"""
    <label class={["inline-flex items-center cursor-pointer", @disabled && "opacity-50", @class]}>
      <input type="hidden" name={@name} value="false" />
      <div class="relative">
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          disabled={@disabled}
          class="sr-only peer"
          {@rest}
        />
        <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-gf-maroon/50 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-gf-maroon">
        </div>
      </div>
      <span :if={@label} class="ml-3 text-base font-medium text-gray-700">{@label}</span>
    </label>
    """
  end

  @doc """
  Renders a radio button group.

  ## Examples

      <.radio_group
        id="abundance"
        name="abundance"
        label="Abundance"
        options={[%{value: "common", label: "Common"}, %{value: "rare", label: "Rare"}]}
        value={@abundance}
      />
  """
  attr :id, :string, required: true, doc: "unique id for the group"
  attr :name, :string, required: true, doc: "form input name"
  attr :label, :string, default: nil, doc: "group label"
  attr :options, :list, required: true, doc: "list of %{value: _, label: _} maps"
  attr :value, :any, default: nil, doc: "currently selected value"
  attr :class, :any, default: nil, doc: "additional CSS classes"
  attr :rest, :global, include: ~w(phx-change form)

  def radio_group(assigns) do
    ~H"""
    <fieldset id={@id} class={@class}>
      <legend :if={@label} class="text-base font-medium text-gray-700 mb-2">{@label}</legend>
      <div class="space-y-2">
        <label :for={option <- @options} class="flex items-center">
          <input
            type="radio"
            name={@name}
            value={option.value}
            checked={@value == option.value || to_string(@value) == to_string(option.value)}
            class="h-4 w-4 text-gf-maroon focus:ring-gf-maroon border-gray-300"
            {@rest}
          />
          <span class="ml-2 text-sm text-gray-700">{option.label}</span>
          <span :if={option[:description]} class="ml-1 text-sm text-gray-500">
            - {option.description}
          </span>
        </label>
      </div>
    </fieldset>
    """
  end

  @doc """
  Renders a file upload dropzone.

  ## Examples

      <.file_dropzone
        id="images"
        upload={@uploads.images}
        label="Upload Images"
        accept=".jpg,.jpeg,.png,.gif"
      />
  """
  attr :id, :string, required: true, doc: "unique id for the dropzone"
  attr :upload, :any, required: true, doc: "Phoenix.LiveView upload configuration"
  attr :label, :string, default: "Drop files here or click to browse", doc: "dropzone label"
  attr :accept, :string, default: nil, doc: "accepted file types"
  attr :class, :any, default: nil, doc: "additional CSS classes"

  def file_dropzone(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md",
        "hover:border-gf-maroon transition-colors cursor-pointer",
        @class
      ]}
      phx-drop-target={@upload.ref}
    >
      <div class="space-y-1 text-center">
        <.icon name="ph-cloud-arrow-up" class="mx-auto size-12 text-gray-400" />
        <div class="flex text-sm text-gray-600">
          <label class="relative cursor-pointer rounded-md font-medium text-gf-maroon hover:text-gf-maroon/80">
            <span>{gettext("Upload a file")}</span>
            <.live_file_input upload={@upload} class="sr-only" />
          </label>
          <p class="pl-1">{gettext("or drag and drop")}</p>
        </div>
        <p class="text-xs text-gray-500">{@label}</p>
      </div>
    </div>
    """
  end

  @doc """
  Renders a form submit button with loading state.

  ## Examples

      <.submit_button phx-disable-with="Saving...">Save</.submit_button>
      <.submit_button variant="danger" phx-disable-with="Deleting...">Delete</.submit_button>
  """
  attr :variant, :string, default: "primary", values: ~w(primary danger), doc: "button variant"
  attr :class, :any, default: nil, doc: "additional CSS classes"
  attr :rest, :global, include: ~w(disabled form phx-disable-with)

  slot :inner_block, required: true

  def submit_button(assigns) do
    variant_classes = %{
      "primary" => "bg-gf-maroon text-white hover:bg-gf-maroon/90 focus:ring-gf-maroon",
      "danger" => "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500"
    }

    assigns = assign(assigns, :variant_class, Map.fetch!(variant_classes, assigns.variant))

    ~H"""
    <button
      type="submit"
      class={[
        "inline-flex items-center justify-center px-4 py-2 rounded-md font-medium text-sm transition-colors",
        "focus:outline-none focus:ring-2 focus:ring-offset-2",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        "phx-submit-loading:opacity-75 phx-submit-loading:cursor-wait",
        @variant_class,
        @class
      ]}
      {@rest}
    >
      <.icon
        name="ph-arrows-clockwise"
        class="size-4 mr-2 animate-spin hidden phx-submit-loading:inline-block"
      />
      {render_slot(@inner_block)}
    </button>
    """
  end
end
