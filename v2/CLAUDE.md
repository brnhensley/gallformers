# V2 Development - Agent Instructions

## Scope

You are working on the **Gallformers V2 rewrite** using Phoenix LiveView. All v2 code lives in this directory (`v2/`).

The v2 stack is:
- **Phoenix 1.8** with LiveView - Full-stack web framework
- **Ecto** with ecto_sqlite3 - Database ORM
- **SQLite** - Database (shared with v1 during development)
- **Tailwind CSS** - Styling (v4 syntax)
- **Fly.io** - Production hosting

## Isolation Rules

- **DO NOT** modify code outside of `v2/`
- **DO NOT** add dependencies on v1 code (`pages/`, `libs/`, `components/`)
- **DO NOT** modify the root `CLAUDE.md`, `package.json`, or other v1 configuration files
- You **MAY** search and read v1 code to understand existing behavior
- You **MAY** use shared resources (`prisma/`, `migrations/`, `ref/`)

## When Replicating v1 Functionality

1. Search/read the relevant v1 code OR `v2_old/` code to understand the behavior
2. Document the behavior you need to replicate
3. Implement fresh code in v2
4. **NEVER** modify v1 files

## Porting from v2_old

The `v2_old/` directory contains the previous Go + SvelteKit implementation. Use it as reference:
- **API patterns**: `v2_old/api/internal/handlers/` - See existing endpoint patterns
- **Database queries**: `v2_old/api/internal/db/queries/` - SQL queries to port to Ecto
- **UI components**: `v2_old/web/src/` - Svelte components to port to LiveView
- **Styling**: `v2_old/web/src/app.css` - Tailwind theme and custom styles

## Development Commands

```bash
# From v2/ directory:
mix setup                  # Install deps, setup DB, build assets
mix phx.server             # Start dev server at http://localhost:4000
mix test                   # Run all tests
mix format                 # Format code
mix credo --strict         # Run code quality checks
mix precommit              # Run all checks before committing

# Database
mix ecto.migrate           # Run migrations
mix ecto.rollback          # Rollback last migration
mix ecto.reset             # Drop, create, migrate, seed

# Assets
mix assets.build           # Build CSS/JS
mix assets.deploy          # Build for production
```

## Database Access

- Local dev: Uses `DATABASE_PATH` env var (typically `../prisma/gallformers.sqlite`)
- Production: Database on Fly.io volume at `/data/gallformers.sqlite`

## Project Structure

```
v2/
├── CLAUDE.md             # This file - agent instructions
├── mix.exs               # Elixir dependencies and project config
├── mix.lock              # Locked dependency versions
│
├── config/               # Application configuration
│   ├── config.exs        # Shared config
│   ├── dev.exs           # Development config
│   ├── test.exs          # Test config
│   ├── prod.exs          # Production config
│   └── runtime.exs       # Runtime config (secrets, env vars)
│
├── lib/
│   ├── gallformers/      # Business logic (contexts)
│   │   ├── application.ex
│   │   ├── repo.ex       # Ecto Repo
│   │   └── *.ex          # Domain contexts (Species, Hosts, etc.)
│   │
│   └── gallformers_web/  # Web layer
│       ├── components/   # Reusable components
│       │   ├── core_components.ex
│       │   └── layouts.ex
│       ├── controllers/  # Non-LiveView controllers
│       ├── live/         # LiveView modules
│       ├── endpoint.ex   # Phoenix endpoint
│       └── router.ex     # Routes
│
├── priv/
│   ├── repo/migrations/  # Ecto migrations
│   └── static/           # Static assets (compiled)
│
├── assets/
│   ├── css/app.css       # Tailwind styles
│   ├── js/app.js         # JavaScript entry point
│   └── vendor/           # Third-party JS
│
└── test/                 # Tests mirror lib/ structure
```

## Styling (Tailwind CSS)

### Custom Colors

Colors are defined in `assets/css/app.css` via `@theme`. Use these classes:

| Class | Hex | Use for |
|-------|-----|---------|
| `text-gf-maroon` / `bg-gf-maroon` | #661419 | Headings, links, primary accent |
| `text-gf-sky-blue` / `bg-gf-sky-blue` | #c1e0f3 | Header background |
| `text-gf-autumn` / `bg-gf-autumn` | #bc6428 | Subtitles, secondary text |
| `bg-cadet-blue` | #96adc8 | Table headers |
| `bg-canary` | #f8f991 | Selected/highlighted rows |

### Page Styling Patterns

**Page titles:**
```heex
<h1 class="text-2xl font-bold text-gf-maroon mb-4">Page Title</h1>
```

**Links:**
```heex
<.link href="..." class="text-gf-maroon hover:underline">Link text</.link>
```

**Cards (v1-style):**
```heex
<div class="bg-white rounded border border-gray-200 shadow-sm">
  <div class="px-4 py-3 border-b border-gray-200">
    <h2 class="text-xl font-semibold text-gf-maroon">Card Title</h2>
  </div>
  <div class="p-4">
    Content here
  </div>
</div>
```

**Page container:**
```heex
<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
  <!-- page content -->
</div>
```

### Global Styles

Applied automatically via layouts:
- **Font**: League Spartan (falls back to system fonts)
- **Header**: Sky blue background, maroon navigation
- **Footer**: Light gray background, maroon links

---

## Phoenix Guidelines

### Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `GallformersWeb.Layouts` module is aliased in `gallformers_web.ex`, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available
- If you override the default input classes, no default classes are inherited, so your custom classes must fully style the input

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive interfaces
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`
- **Never** use `@apply` when writing raw CSS
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline `<script>` tags within templates**

---

## Elixir Guidelines

- Elixir lists **do not support index-based access via the access syntax**. Use `Enum.at`, pattern matching, or `List` functions instead
- Elixir variables are immutable but can be rebound. For block expressions like `if`, `case`, `cond`, etc., you *must* bind the result of the expression to a variable
- **Never** nest multiple modules in the same file as it can cause cyclic dependencies
- **Never** use map access syntax (`changeset[:field]`) on structs. Use `my_struct.field` or `Ecto.Changeset.get_field/2`
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should end in a question mark, not start with `is_`

---

## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates
- `Ecto.Schema` fields always use the `:string` type, even for `:text` columns
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields set programmatically (like `user_id`) must not be in `cast` calls - set them explicitly
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migrations

---

## Phoenix HTML Guidelines

- Phoenix templates **always** use `~H` or .html.heex files (HEEx), **never** use `~E`
- **Always** use `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` to build forms
- **Always** use `to_form/2` for forms: `assign(socket, form: to_form(...))`
- **Always** add unique DOM IDs to key elements (forms, buttons, etc.)
- HEEx class attrs support lists with conditional classes:

```heex
<a class={[
  "px-2 text-white",
  @some_flag && "py-5",
  if(@other_condition, do: "border-red-500", else: "border-blue-100")
]}>Text</a>
```

- **Never** use `<% Enum.each %>` for generating template content, use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`
- Use `{...}` for interpolation in attributes and tag bodies. Use `<%= %>` only for block constructs (if, cond, case, for)

---

## Phoenix LiveView Guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions. Use `<.link navigate={href}>` and `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` in LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `GallformersWeb.WeatherLive`, with a `Live` suffix

### LiveView Streams

- **Always** use LiveView streams for collections to avoid memory issues:
  - Basic append: `stream(socket, :messages, [new_msg])`
  - Reset stream: `stream(socket, :messages, [new_msg], reset: true)`
  - Prepend: `stream(socket, :messages, [new_msg], at: -1)`
  - Delete: `stream_delete(socket, :messages, msg)`

- Template must set `phx-update="stream"` on parent and use `@streams.stream_name`:

```heex
<div id="messages" phx-update="stream">
  <div :for={{id, msg} <- @streams.messages} id={id}>
    {msg.text}
  </div>
</div>
```

- LiveView streams are *not* enumerable. To filter, refetch data and re-stream with `reset: true`

### LiveView JavaScript Interop

- Anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set `phx-update="ignore"`
- **Always** provide a unique DOM id alongside `phx-hook`

#### Inline Colocated JS Hooks

**Never** write raw embedded `<script>` tags. Use colocated hooks:

```heex
<input type="text" id="phone" phx-hook=".PhoneNumber" />
<script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
  export default {
    mounted() {
      this.el.addEventListener("input", e => {
        // format phone number
      })
    }
  }
</script>
```

- Colocated hooks names **MUST** start with a `.` prefix, i.e. `.PhoneNumber`

#### External phx-hook

Place in `assets/js/` and pass to LiveSocket:

```javascript
const MyHook = {
  mounted() { ... }
}
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { MyHook }
});
```

### Form Handling

**Always** use `to_form/2` and the `<.input>` component:

```heex
<.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
  <.input field={@form[:field]} type="text" />
</.form>
```

- You are **FORBIDDEN** from accessing the changeset directly in the template
- **Never** use `<.form let={f} ...>`, **always use `<.form for={@form} ...>`**

---

## Test Guidelines

- **Always use `start_supervised!/1`** to start processes in tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests. Use `Process.monitor/1` instead
- Use `Phoenix.LiveViewTest` and `LazyHTML` for LiveView tests
- **Always** reference key element IDs in tests: `assert has_element?(view, "#my-form")`
- **Never** test against raw HTML, **always** use `element/2`, `has_element/2`, etc.

---

## Important Notes

- The v1 site (Next.js on Digital Ocean) continues running until cutover
- All v2 work must stay within the `v2/` directory
- Use the beads workflow for issue tracking (`bd` commands)
