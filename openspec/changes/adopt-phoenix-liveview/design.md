# Design: Phoenix + LiveView Architecture

## Context

V2 was being built as a Go API + SvelteKit frontend. After evaluating alternatives (pure SPA, Go + HTMX, Phoenix), the decision is to adopt Phoenix with LiveView for a unified full-stack Elixir solution.

**Stakeholders**:
- Site admins (need instant feedback on changes)
- End users (need fast, reliable access to data)
- Developer (needs simple, maintainable architecture with excellent DX)

**Constraints**:
- Low traffic most of the time, occasionally bursty
- Primary use case is ID tool (interactive)
- SEO is nice-to-have, not critical
- No budget for expensive infrastructure
- Single maintainer with strong FP background

## Goals / Non-Goals

**Goals**:
- Admin changes visible immediately without any cache invalidation
- Server renders full HTML (good SEO, works without JS)
- Excellent developer experience (LiveView, hot reload, error pages)
- Single language/ecosystem (Elixir)
- Real-time capabilities built-in
- Type-safe with dialyzer (optional but available)

**Non-Goals**:
- Offline support (not needed for this use case)
- Sub-100ms page loads (acceptable if under 500ms)
- GraphQL API (REST is sufficient)

## Decisions

### Decision 1: Use Phoenix with LiveView

**What**: Full-stack Elixir with Phoenix framework and LiveView for interactive UI.

**Why**:
- LiveView: Server-rendered real-time UI without client-side JS framework
- Ecto: Excellent database layer with composable queries and changesets
- PubSub: Built-in real-time broadcast for admin updates
- Conventions: Strong conventions reduce decision fatigue
- Maintainer fit: FP background (Scala/Akka) transfers directly

**Example LiveView**:
```elixir
defmodule GallformersWeb.GlossaryLive do
  use GallformersWeb, :live_view

  def mount(_params, _session, socket) do
    entries = Glossary.list_entries()
    {:ok, assign(socket, entries: entries, sort_by: :word, sort_dir: :asc)}
  end

  def handle_event("sort", %{"column" => column}, socket) do
    column = String.to_existing_atom(column)
    {sort_by, sort_dir} = toggle_sort(socket.assigns, column)
    entries = Glossary.list_entries(sort_by: sort_by, sort_dir: sort_dir)
    {:noreply, assign(socket, entries: entries, sort_by: sort_by, sort_dir: sort_dir)}
  end
end
```

**Alternative considered**: Go + Templ + HTMX
- Also excellent, but Phoenix provides more integrated solution
- LiveView handles what would require HTMX + Alpine.js in Go stack

### Decision 2: Ecto with SQLite

**What**: Use Ecto ORM with ecto_sqlite3 adapter for database access.

**Why**:
- Composable queries (pipe-based, very Elixir-idiomatic)
- Changesets for validation (validation is data, not side effects)
- Explicit preloading (no N+1 surprises)
- Works with existing SQLite database

**Schema example**:
```elixir
defmodule Gallformers.Species do
  use Ecto.Schema

  schema "species" do
    field :name, :string
    field :abundance, :string
    field :datacomplete, :boolean

    belongs_to :taxonomy, Gallformers.Taxonomy
    has_many :images, Gallformers.Image
    many_to_many :hosts, Gallformers.Host, join_through: "specieshosts"
  end

  def changeset(species, attrs) do
    species
    |> cast(attrs, [:name, :abundance, :datacomplete])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:name)
  end
end
```

**Composable queries**:
```elixir
def filter_galls(params) do
  Gall
  |> maybe_filter_host(params[:host_id])
  |> maybe_filter_colors(params[:colors])
  |> maybe_filter_shapes(params[:shapes])
  |> preload([:species, :hosts, :images])
  |> Repo.all()
end

defp maybe_filter_host(query, nil), do: query
defp maybe_filter_host(query, host_id) do
  from g in query,
    join: h in assoc(g, :hosts),
    where: h.id == ^host_id
end
```

### Decision 3: LiveView for all interactivity

**What**: Use LiveView for search, ID tool, forms, and all dynamic features.

**Why**:
- No client-side state management needed
- Server maintains state, pushes diffs over WebSocket
- Forms with real-time validation via changesets
- URL state via `handle_params` and `push_patch`

**Search example**:
```elixir
def handle_event("search", %{"query" => query}, socket) do
  results = Search.find(query)
  {:noreply, assign(socket, results: results, query: query)}
end
```

**URL state for ID tool**:
```elixir
def handle_params(params, _uri, socket) do
  filters = parse_filters(params)
  results = IDTool.filter_galls(filters)
  {:noreply, assign(socket, filters: filters, results: results)}
end

def handle_event("filter_change", %{"host" => host_id}, socket) do
  filters = Map.put(socket.assigns.filters, :host_id, host_id)
  {:noreply, push_patch(socket, to: ~p"/id?#{filters}")}
end
```

**Alternative considered**: HTMX-style approach with dead views + partials
- LiveView is simpler - no need to manage separate partial endpoints
- Built-in form handling with changesets

### Decision 4: PubSub for real-time updates

**What**: Use Phoenix PubSub to broadcast admin changes to all connected clients.

**Why**:
- Admin saves species → broadcast to all users viewing that species
- No cache invalidation logic needed
- Built into Phoenix, zero configuration

**Example**:
```elixir
# In admin context after save
def update_species(species, attrs) do
  case Repo.update(Species.changeset(species, attrs)) do
    {:ok, species} ->
      Phoenix.PubSub.broadcast(Gallformers.PubSub, "species:#{species.id}", {:species_updated, species})
      {:ok, species}
    error -> error
  end
end

# In public LiveView
def mount(%{"id" => id}, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Gallformers.PubSub, "species:#{id}")
  end
  species = Species.get!(id)
  {:ok, assign(socket, species: species)}
end

def handle_info({:species_updated, species}, socket) do
  {:noreply, assign(socket, species: species)}
end
```

### Decision 5: JS hooks for complex visualizations

**What**: Use Phoenix LiveView hooks for features that need JavaScript (maps, uploads).

**Why**:
- Clean boundary: server manages data, JS manages visualization
- LiveView handles data passing, hook handles rendering
- No need for separate "islands" build process

**Range map example**:
```elixir
# In template
<div id="range-map"
     phx-hook="RangeMap"
     data-range={Jason.encode!(@range_data)}>
</div>
```

```javascript
// In app.js
Hooks.RangeMap = {
  mounted() {
    const data = JSON.parse(this.el.dataset.range)
    this.map = initMapLibre(this.el, data)
  },
  updated() {
    const data = JSON.parse(this.el.dataset.range)
    updateMapData(this.map, data)
  },
  destroyed() {
    this.map?.remove()
  }
}
```

**Hooks needed**:
- Range map (MapLibre)
- Image upload with preview
- Any third-party JS components

### Decision 6: HEEx templates with Tailwind

**What**: Use HEEx (HTML + Elixir) templates with existing Tailwind classes.

**Why**:
- HEEx is the standard Phoenix templating
- Compile-time checks for assigns
- Tailwind classes copy directly from SvelteKit

**Example**:
```heex
<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
  <h1 class="text-2xl font-bold text-gf-maroon mb-4"><%= @species.name %></h1>

  <.card title="Hosts">
    <ul>
      <%= for host <- @species.hosts do %>
        <li>
          <.link navigate={~p"/host/#{host.id}"} class="text-gf-maroon hover:underline">
            <%= host.name %>
          </.link>
        </li>
      <% end %>
    </ul>
  </.card>
</div>
```

**Function components**:
```elixir
defmodule GallformersWeb.Components do
  use Phoenix.Component

  attr :title, :string, required: true
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class="bg-white rounded border border-gray-200 shadow-sm">
      <div class="px-4 py-3 border-b border-gray-200">
        <h2 class="text-xl font-semibold text-gf-maroon"><%= @title %></h2>
      </div>
      <div class="p-4">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
```

### Decision 7: Phoenix contexts for domain logic

**What**: Organize business logic into contexts (bounded modules).

**Structure**:
```
lib/gallformers/
├── species.ex          # Species context
├── species/
│   ├── gall.ex         # Gall schema
│   ├── host.ex         # Host schema
│   └── taxonomy.ex     # Taxonomy schema
├── glossary.ex         # Glossary context
├── search.ex           # Search context
├── id_tool.ex          # ID tool filtering logic
└── accounts.ex         # Admin accounts context
```

**Context example**:
```elixir
defmodule Gallformers.Species do
  alias Gallformers.Repo
  alias Gallformers.Species.{Gall, Host, Taxonomy}

  def get_gall!(id) do
    Gall
    |> Repo.get!(id)
    |> Repo.preload([:hosts, :images, :taxonomy])
  end

  def list_galls(opts \\ []) do
    Gall
    |> apply_filters(opts)
    |> Repo.all()
  end

  def update_gall(%Gall{} = gall, attrs) do
    gall
    |> Gall.changeset(attrs)
    |> Repo.update()
    |> broadcast_change()
  end
end
```

### Decision 8: Authentication with Auth0

**What**: Continue using Auth0 via ueberauth_auth0.

**Why**:
- Already configured for v1/v2
- ueberauth provides standard Phoenix integration
- Session-based auth works well with LiveView

**Implementation**:
```elixir
# In router
pipeline :browser do
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, {GallformersWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug :fetch_current_user
end

pipeline :admin do
  plug :require_authenticated_user
  plug :require_admin_role
end

scope "/admin", GallformersWeb.Admin do
  pipe_through [:browser, :admin]

  live "/species", SpeciesLive.Index
  live "/species/:id/edit", SpeciesLive.Edit
end
```

### Decision 9: Markdown with earmark

**What**: Server-side markdown rendering with earmark, glossary linking as post-processor.

**Implementation**:
```elixir
defmodule Gallformers.Markdown do
  def render(source) do
    source
    |> Earmark.as_html!()
    |> link_glossary_terms()
  end

  defp link_glossary_terms(html) do
    terms = Glossary.list_terms()
    Enum.reduce(terms, html, fn term, acc ->
      regex = ~r/\b#{Regex.escape(term.word)}\b/i
      Regex.replace(regex, acc, fn match ->
        ~s(<a href="/glossary##{String.downcase(term.word)}" class="text-gf-maroon hover:underline">#{match}</a>)
      end)
    end)
  end
end
```

### Decision 10: SEO implementation

**What**: Standard Phoenix SEO with meta tags, Open Graph, and sitemap.

**Meta component**:
```elixir
def meta_tags(assigns) do
  ~H"""
  <title><%= @title %> | Gallformers</title>
  <meta name="description" content={@description} />
  <link rel="canonical" href={@canonical_url} />

  <meta property="og:title" content={@title} />
  <meta property="og:description" content={@description} />
  <meta property="og:image" content={@image_url} />
  <meta property="og:url" content={@canonical_url} />
  <meta property="og:type" content="website" />
  """
end
```

**Sitemap**: Generate with `sitemap` library or custom controller.

**Robots.txt**: Static file or controller allowing public, disallowing admin.

### Decision 11: Directory structure

```
v2/
├── lib/
│   ├── gallformers/              # Business logic (contexts)
│   │   ├── species.ex
│   │   ├── species/
│   │   │   ├── gall.ex
│   │   │   ├── host.ex
│   │   │   └── taxonomy.ex
│   │   ├── glossary.ex
│   │   ├── search.ex
│   │   ├── id_tool.ex
│   │   └── accounts.ex
│   ├── gallformers_web/          # Web layer
│   │   ├── components/           # Reusable UI components
│   │   │   ├── layouts.ex
│   │   │   └── core_components.ex
│   │   ├── live/                 # LiveView modules
│   │   │   ├── gall_live.ex
│   │   │   ├── host_live.ex
│   │   │   ├── glossary_live.ex
│   │   │   ├── search_live.ex
│   │   │   ├── id_live.ex
│   │   │   └── admin/
│   │   │       ├── species_live.ex
│   │   │       └── ...
│   │   ├── controllers/          # Non-LiveView (API, auth callbacks)
│   │   │   ├── api/
│   │   │   └── auth_controller.ex
│   │   └── router.ex
│   └── gallformers.ex            # Application entry
├── priv/
│   └── static/                   # Static assets
│       ├── css/
│       ├── js/
│       └── images/
├── assets/                       # Asset sources
│   ├── css/app.css
│   ├── js/app.js
│   └── js/hooks/
│       └── range_map.js
├── config/                       # Configuration
├── test/                         # Tests
└── mix.exs                       # Dependencies
```

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Elixir learning curve | Low | Maintainer has strong FP background |
| Smaller ecosystem than JS/Go | Low | Phoenix ecosystem covers all needs |
| LLM code quality | Medium | Review Elixir idioms, provide patterns |
| WebSocket scalability | Low | Single instance is fine; Fly.io handles gracefully |
| SQLite with Ecto maturity | Low | ecto_sqlite3 is stable, used in production |

## Migration Plan

**Critical constraint**: Visual design MUST match current V2 SvelteKit site.

**Key principles**:
1. **Deploy early, deploy often** - Get something running in prod ASAP
2. **One page at a time** - Build, deploy, verify visual parity, then move on
3. **v2_old is the spec** - Reference the existing code, don't create separate docs
4. **CI from day one** - Catch issues early
5. **Home page first** - Proves the architecture works end-to-end

### Phase 0: Code Migration
- Move `v2/` to `v2_old/`
- Create new `v2/` for Phoenix project
- Update root CLAUDE.md to reflect new structure

### Phase 1: Foundation + CI + First Deploy
- Set up Phoenix project with CI pipeline
- Create `v2/CLAUDE.md` with agent instructions
- Configure Ecto with SQLite
- Create base layout with Tailwind (port from v2_old)
- Deploy to Fly.io (even with placeholder content)

### Phase 2: Home Page (Tracer Bullet)
- Create minimal Ecto schemas needed for home page
- Implement HomeLive with random gall feature
- Verify visual parity with v2_old
- Deploy and verify in production

**Milestone**: Site is live with working home page

### Phase 3: Ecto Schemas + Components
- Complete all Ecto schemas
- Build shared UI components
- Reference v2_old code for data model and styling

### Phase 4: Public Pages
- Build one page at a time
- Deploy after each page
- Verify visual parity before moving on

### Phase 5: Interactive Features
- Implement search LiveView
- Implement ID tool LiveView
- Add range map JS hook

### Phase 6: Admin
- Implement admin LiveViews with forms
- Add PubSub for real-time updates
- Integrate Auth0

### Phase 7: API
- Add JSON API endpoints matching v2_old patterns
- Document API using v2_old style (V1_V2_DIFFERENCES.md format)

### Phase 8: Cleanup
- Final visual parity sign-off
- Remove v2_old directory
- Update documentation

## Rollback Strategy

Keep `v2_old/` until Phoenix is fully deployed and verified. The code in v2_old serves as both the spec and the rollback target.
