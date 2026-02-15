# Print-Friendly Keys Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Generate publication-quality PDF versions of identification keys using Typst, stored on S3, linked from the public key page.

**Architecture:** A `Keys.PdfGenerator` module serializes key data to JSON, shells out to `typst compile` with a template at `priv/typst/key.typ`, and uploads the resulting PDF to S3. Generation is triggered asynchronously after admin key create/update via `Gallformers.Async.run/1`. The public key page links to the CDN URL when a PDF exists.

**Tech Stack:** Typst CLI (shelled out via `System.cmd`), existing S3/Storage infrastructure, existing `Gallformers.Async` for background execution.

---

### Task 1: Add Typst to Dockerfile

**Files:**
- Modify: `Dockerfile:53-63` (runtime stage)
- Modify: `Dockerfile.preview:55-59` (runtime stage)

**Step 1: Add Typst binary to production Dockerfile**

In the runtime stage, after the existing `RUN apk add` line, add:

```dockerfile
# Install Typst for PDF generation of identification keys
ADD https://github.com/typst/typst/releases/download/v0.14.2/typst-x86_64-unknown-linux-musl.tar.xz /tmp/typst.tar.xz
RUN tar -C /usr/local/bin -xf /tmp/typst.tar.xz --strip-components=1 typst-x86_64-unknown-linux-musl/typst && rm /tmp/typst.tar.xz
```

**Step 2: Add Typst binary to preview Dockerfile**

Same addition in `Dockerfile.preview` runtime stage.

**Step 3: Commit**

```bash
git add Dockerfile Dockerfile.preview
git commit -m "Add Typst binary to Docker images for key PDF generation"
```

---

### Task 2: Install Typst locally for development

**Step 1: Install Typst on macOS**

```bash
brew install typst
```

**Step 2: Verify installation**

```bash
typst --version
```

Expected: `typst 0.14.x` or similar.

---

### Task 3: Create the Typst template

**Files:**
- Create: `priv/typst/key.typ`

**Step 1: Write the template**

The template reads JSON from `sys.inputs.data` and a boolean flag from `sys.inputs.images`.

```typst
// Identification Key PDF Template
// Usage: typst compile --input data='<json>' --input images=false key.typ output.pdf

#let data = json(bytes(sys.inputs.data))
#let show_images = sys.inputs.at("images", default: "false") == "true"

// Page setup
#set page(
  paper: "us-letter",
  margin: (top: 1in, bottom: 1in, left: 0.75in, right: 0.75in),
  header: context {
    if counter(page).get().first() > 1 [
      #set text(size: 9pt, style: "italic", fill: rgb("#666"))
      #data.title #h(1fr) #counter(page).display()
    ]
  },
  footer: [
    #set text(size: 8pt, fill: rgb("#999"))
    gallformers.org/keys/#data.slug #h(1fr) Version #data.version
  ],
)

#set text(font: "Linux Libertine", size: 11pt)
#set par(leading: 0.65em)

// Title block
#align(center)[
  #text(size: 18pt, weight: "bold")[#data.title]
  #if data.at("subtitle", default: none) != none [
    #v(0.3em)
    #text(size: 12pt, fill: rgb("#666"))[#data.subtitle]
  ]
  #if data.at("authors", default: ()).len() > 0 [
    #v(0.3em)
    #text(size: 10pt)[#data.authors.join(", ")]
  ]
  #if data.at("citation", default: none) != none [
    #v(0.2em)
    #text(size: 9pt, fill: rgb("#666"))[#data.citation]
  ]
]

#v(0.5em)
#line(length: 100%, stroke: 0.5pt + rgb("#ccc"))

#if data.at("description", default: none) != none [
  #v(0.5em)
  #text(size: 10pt, fill: rgb("#444"))[#data.description]
  #v(0.5em)
  #line(length: 100%, stroke: 0.5pt + rgb("#ccc"))
]

#v(1em)

// Letter labels for leads within a couplet
#let lead_letter(index) = {
  let letters = "abcdefghijklmnopqrstuvwxyz"
  letters.at(index)
}

// Render a single lead row: "1a. Text ............ Destination"
#let render_lead(couplet_number, lead, index, is_first) = {
  let prefix = if is_first {
    text(weight: "bold")[#couplet_number#lead_letter(index).]
  } else {
    // Indent subsequent leads to align with first
    h(measure(text(weight: "bold")[#couplet_number]).width)
    text(weight: "bold")[#lead_letter(index).]
  }

  let dest = lead.destination
  let dest_text = if dest.type == "taxon" {
    emph(dest.name)
  } else {
    text(weight: "bold")[#dest.number]
  }

  // The lead row
  grid(
    columns: (1fr, auto),
    column-gutter: 0.3em,
    [#prefix #h(0.5em) #lead.text #h(0.3em) #box(width: 1fr, repeat[.])],
    dest_text,
  )

  // Notes below the lead (indented, smaller)
  if lead.at("notes", default: none) != none {
    pad(left: 2em)[
      #text(size: 9pt, fill: rgb("#555"), style: "italic")[#lead.notes]
    ]
  }

  // Images below the lead (when enabled)
  if show_images {
    let imgs = lead.at("images", default: ())
    if imgs.len() > 0 {
      pad(left: 2em)[
        #for img in imgs [
          #if "file" in img [
            // Images are served from CDN
            // #image(img.file, width: 40%)
            #text(size: 9pt, fill: rgb("#888"))[\[Image: #img.at("caption", default: img.file)\]]
          ]
        ]
      ]
    }
  }
}

// Sort couplet numbers numerically
#let numbers = data.couplets.keys().sorted(key: k => int(k))

// Render all couplets
#for number in numbers {
  let couplet = data.couplets.at(number)
  block(breakable: false, below: 0.8em)[
    #for (index, lead) in couplet.leads.enumerate() {
      render_lead(number, lead, index, index == 0)
    }
  ]
}
```

Note: This template is a starting point. The user expects to iterate on typography after seeing the initial output. The key structural elements are:
- `block(breakable: false)` to keep couplets together
- `grid` with `repeat[.]` for dot leaders
- `emph()` for taxon names
- Running header/footer via `set page`

**Step 2: Test the template locally with a fixture key**

```bash
cat priv/keys/populus-midge-key.json | typst compile --input "data=$(cat priv/keys/populus-midge-key.json)" --input images=false priv/typst/key.typ /tmp/test-key.pdf
```

Verify: Open `/tmp/test-key.pdf` and check that it renders couplets with dot leaders, proper italics, and page numbering.

**Important:** The exact Typst syntax may need adjustment — the template above is based on Typst docs but hasn't been compiled. Expect to iterate on syntax errors in this step. The structure and approach are correct; the exact API calls may need tweaking against Typst 0.14.x docs.

**Step 3: Commit**

```bash
git add priv/typst/key.typ
git commit -m "Add Typst template for print-friendly identification keys"
```

---

### Task 4: Write the PdfGenerator module — failing test first

**Files:**
- Create: `test/gallformers/keys/pdf_generator_test.exs`
- Create: `lib/gallformers/keys/pdf_generator.ex`

**Step 1: Write the failing test**

```elixir
defmodule Gallformers.Keys.PdfGeneratorTest do
  use Gallformers.DataCase

  alias Gallformers.Keys
  alias Gallformers.Keys.PdfGenerator

  @valid_couplets Jason.encode!(%{
    "1" => %{
      "leads" => [
        %{
          "text" => "Lead A",
          "images" => [],
          "destination" => %{"type" => "couplet", "number" => "2"}
        },
        %{
          "text" => "Lead B",
          "images" => [],
          "destination" => %{"type" => "taxon", "name" => "Species X"}
        }
      ]
    },
    "2" => %{
      "leads" => [
        %{
          "text" => "Lead C",
          "images" => [],
          "destination" => %{"type" => "taxon", "name" => "Species Y"}
        },
        %{
          "text" => "Lead D",
          "images" => [],
          "destination" => %{"type" => "taxon", "name" => "Species Z"}
        }
      ]
    }
  })

  defp create_test_key do
    {:ok, key} =
      Keys.create_key(%{
        title: "Test Key",
        version: "2026-01-01",
        couplets: @valid_couplets
      })

    key
  end

  describe "serialize_key/1" do
    test "serializes key struct to JSON string" do
      key = create_test_key()
      json = PdfGenerator.serialize_key(key)
      data = Jason.decode!(json)

      assert data["title"] == "Test Key"
      assert data["slug"] == "test-key"
      assert data["version"] == "2026-01-01"
      assert is_map(data["couplets"])
      assert Map.has_key?(data["couplets"], "1")
      assert Map.has_key?(data["couplets"], "2")
    end

    test "couplet leads have string-keyed maps" do
      key = create_test_key()
      json = PdfGenerator.serialize_key(key)
      data = Jason.decode!(json)

      lead = data["couplets"]["1"]["leads"] |> hd()
      assert lead["text"] == "Lead A"
      assert lead["destination"]["type"] == "couplet"
    end
  end

  describe "generate_pdf/2" do
    @tag :typst
    test "generates a PDF file" do
      key = create_test_key()
      {:ok, pdf_path} = PdfGenerator.generate_pdf(key, images: false)

      assert File.exists?(pdf_path)
      # PDF files start with %PDF
      assert File.read!(pdf_path) |> String.starts_with?("%PDF")

      File.rm(pdf_path)
    end

    @tag :typst
    test "returns error when typst is not available" do
      key = create_test_key()
      result = PdfGenerator.generate_pdf(key, images: false, typst_cmd: "nonexistent-binary")

      assert {:error, _reason} = result
    end
  end

  describe "s3_paths/1" do
    test "returns correct S3 paths for a key" do
      key = create_test_key()
      paths = PdfGenerator.s3_paths(key)

      assert paths.text_only == "keys/test-key/test-key.pdf"
      assert paths.with_images == "keys/test-key/test-key-images.pdf"
    end
  end

  describe "cdn_urls/1" do
    test "returns full CDN URLs" do
      key = create_test_key()
      urls = PdfGenerator.cdn_urls(key)

      cdn = Gallformers.Storage.cdn_url()
      assert urls.text_only == "#{cdn}/keys/test-key/test-key.pdf"
      assert urls.with_images == "#{cdn}/keys/test-key/test-key-images.pdf"
    end
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/gallformers/keys/pdf_generator_test.exs --exclude typst
```

Expected: Compilation error — `PdfGenerator` module does not exist.

**Step 3: Write the PdfGenerator module**

```elixir
defmodule Gallformers.Keys.PdfGenerator do
  @moduledoc """
  Generates PDF versions of identification keys using Typst.

  Serializes key data to JSON, compiles with a Typst template,
  and uploads the resulting PDF to S3.
  """

  require Logger

  alias Gallformers.Storage

  @template_path "priv/typst/key.typ"

  @doc """
  Serializes a Key struct to a JSON string suitable for Typst input.

  Converts atom-keyed couplet maps back to string-keyed maps
  for JSON encoding.
  """
  @spec serialize_key(Gallformers.Keys.Key.t()) :: String.t()
  def serialize_key(key) do
    %{
      title: key.title,
      slug: key.slug,
      subtitle: key.subtitle,
      authors: key.authors || [],
      citation: key.citation,
      citation_url: key.citation_url,
      description: key.description,
      version: key.version,
      couplets: serialize_couplets(key.couplets)
    }
    |> Jason.encode!()
  end

  @doc """
  Generates a PDF file from a key.

  Returns `{:ok, output_path}` on success or `{:error, reason}` on failure.

  ## Options
    * `:images` - Whether to include images (default: `false`)
    * `:output_path` - Custom output path (default: temp file)
    * `:typst_cmd` - Typst binary name (default: `"typst"`)
  """
  @spec generate_pdf(Gallformers.Keys.Key.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_pdf(key, opts \\ []) do
    images = Keyword.get(opts, :images, false)
    typst_cmd = Keyword.get(opts, :typst_cmd, "typst")

    output_path =
      Keyword.get_lazy(opts, :output_path, fn ->
        Path.join(System.tmp_dir!(), "key-#{key.slug}-#{System.unique_integer([:positive])}.pdf")
      end)

    json = serialize_key(key)
    template = Application.app_dir(:gallformers, @template_path)

    args = [
      "compile",
      "--input", "data=#{json}",
      "--input", "images=#{images}",
      template,
      output_path
    ]

    case System.cmd(typst_cmd, args, stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, output_path}

      {output, exit_code} ->
        Logger.error("Typst compilation failed (exit #{exit_code}): #{output}")
        {:error, {:typst_failed, exit_code, output}}
    end
  end

  @doc """
  Returns the S3 paths for a key's PDFs.
  """
  @spec s3_paths(Gallformers.Keys.Key.t()) :: %{text_only: String.t(), with_images: String.t()}
  def s3_paths(key) do
    %{
      text_only: "keys/#{key.slug}/#{key.slug}.pdf",
      with_images: "keys/#{key.slug}/#{key.slug}-images.pdf"
    }
  end

  @doc """
  Returns the full CDN URLs for a key's PDFs.
  """
  @spec cdn_urls(Gallformers.Keys.Key.t()) :: %{text_only: String.t(), with_images: String.t()}
  def cdn_urls(key) do
    paths = s3_paths(key)
    cdn = Storage.cdn_url()

    %{
      text_only: "#{cdn}/#{paths.text_only}",
      with_images: "#{cdn}/#{paths.with_images}"
    }
  end

  @doc """
  Generates PDFs and uploads them to S3.

  Generates the text-only variant always. Generates the with-images
  variant only if the key has images in its couplet data.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @spec generate_and_upload(Gallformers.Keys.Key.t()) :: :ok | {:error, term()}
  def generate_and_upload(key) do
    paths = s3_paths(key)

    with {:ok, pdf_path} <- generate_pdf(key, images: false),
         pdf_data = File.read!(pdf_path),
         {:ok, _} <- Storage.upload(paths.text_only, pdf_data, "application/pdf"),
         :ok <- File.rm(pdf_path) do
      # Generate with-images variant if key has any images
      if key_has_images?(key) do
        generate_and_upload_variant(key, paths.with_images, images: true)
      else
        :ok
      end
    else
      {:error, reason} ->
        Logger.error("PDF generation/upload failed for key #{key.slug}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_and_upload_variant(key, s3_path, opts) do
    with {:ok, pdf_path} <- generate_pdf(key, opts),
         pdf_data = File.read!(pdf_path),
         {:ok, _} <- Storage.upload(s3_path, pdf_data, "application/pdf"),
         :ok <- File.rm(pdf_path) do
      :ok
    else
      {:error, reason} ->
        Logger.error("PDF variant upload failed for key #{key.slug}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp key_has_images?(key) do
    Enum.any?(key.couplets, fn {_number, couplet} ->
      Enum.any?(couplet.leads, fn lead ->
        lead.images != nil and lead.images != []
      end)
    end)
  end

  # Converts atom-keyed couplet maps to string-keyed maps for JSON.
  defp serialize_couplets(couplets) do
    Map.new(couplets, fn {number, couplet} ->
      {number, %{
        "leads" => Enum.map(couplet.leads, &serialize_lead/1)
      }}
    end)
  end

  defp serialize_lead(lead) do
    %{
      "text" => lead.text,
      "notes" => lead[:notes],
      "images" => Enum.map(lead.images || [], &serialize_image/1),
      "destination" => serialize_destination(lead.destination)
    }
  end

  defp serialize_image(image) do
    %{
      "ref" => image[:ref],
      "file" => image[:file],
      "caption" => image[:caption]
    }
  end

  defp serialize_destination(nil), do: nil

  defp serialize_destination(dest) do
    base = %{"type" => dest.type}

    case dest.type do
      "couplet" ->
        Map.merge(base, %{"number" => dest[:number], "label" => dest[:label]})

      "taxon" ->
        Map.merge(base, %{
          "name" => dest[:name],
          "context" => dest[:context],
          "species_ids" => dest[:species_ids] || []
        })

      _ ->
        base
    end
  end
end
```

**Step 4: Run non-typst tests to verify serialization works**

```bash
mix test test/gallformers/keys/pdf_generator_test.exs --exclude typst
```

Expected: All non-typst tests pass.

**Step 5: Run typst-tagged tests (requires local Typst installation from Task 2)**

```bash
mix test test/gallformers/keys/pdf_generator_test.exs --include typst
```

Expected: PDF generation test passes. If Typst template has syntax errors, fix them iteratively.

**Step 6: Commit**

```bash
git add lib/gallformers/keys/pdf_generator.ex test/gallformers/keys/pdf_generator_test.exs
git commit -m "Add PdfGenerator module for Typst-based key PDF generation"
```

---

### Task 5: Wire PDF generation into admin key save

**Files:**
- Modify: `lib/gallformers_web/live/admin/key_live/form.ex`

**Step 1: Override `after_create` and `after_update` to trigger PDF generation**

Add these overrides in the admin form module, after the existing `FormHelpers` callback implementations:

```elixir
@impl GallformersWeb.Admin.FormHelpers
def after_create(socket, entity) do
  trigger_pdf_generation(entity)

  socket
  |> put_flash(:info, "Key created successfully. PDF generation started.")
  |> push_navigate(to: "#{list_path()}/#{entity.id}")
end

@impl GallformersWeb.Admin.FormHelpers
def after_update(socket, entity) do
  trigger_pdf_generation(entity)

  changeset = change_entity(entity)

  socket
  |> put_flash(:info, "Key updated successfully. PDF generation started.")
  |> assign(entity_key(), entity)
  |> assign(:form, to_form(changeset, as: "key"))
  |> assign(:form_dirty, false)
end

defp trigger_pdf_generation(key) do
  Gallformers.Async.run(fn ->
    case Gallformers.Keys.PdfGenerator.generate_and_upload(key) do
      :ok ->
        Logger.info("PDF generated and uploaded for key: #{key.slug}")

      {:error, reason} ->
        Logger.error("PDF generation failed for key #{key.slug}: #{inspect(reason)}")
    end
  end)
end
```

Add `require Logger` at the top of the module.

**Step 2: Run existing admin key tests to ensure nothing breaks**

```bash
mix test test/gallformers_web/live/admin/key_live_test.exs
```

Expected: All existing tests pass. The `Async.run` is synchronous in test mode, and `S3.request` returns mock success in tests.

**Step 3: Commit**

```bash
git add lib/gallformers_web/live/admin/key_live/form.ex
git commit -m "Trigger PDF generation on key create and update"
```

---

### Task 6: Add download links to public key page

**Files:**
- Modify: `lib/gallformers_web/live/key_live.ex`

**Step 1: Add PDF URLs to assigns in mount**

In the `mount` function's success branch, add:

```elixir
pdf_urls: Gallformers.Keys.PdfGenerator.cdn_urls(key),
key_has_images: key_has_images?(key),
```

Add a private helper:

```elixir
defp key_has_images?(key) do
  Enum.any?(key.couplets, fn {_number, couplet} ->
    Enum.any?(couplet.leads, fn lead ->
      lead.images != nil and lead.images != []
    end)
  end)
end
```

**Step 2: Add download links to the template**

In the header section of the render function, after the description paragraph and before the path tracker, add:

```heex
<div class="flex gap-3 mt-4">
  <a
    href={@pdf_urls.text_only}
    target="_blank"
    rel="noopener noreferrer"
    class="inline-flex items-center gap-1.5 text-sm text-gf-maroon hover:underline"
  >
    <.icon name="file-pdf" class="w-4 h-4" /> Download PDF
  </a>
  <a
    :if={@key_has_images}
    href={@pdf_urls.with_images}
    target="_blank"
    rel="noopener noreferrer"
    class="inline-flex items-center gap-1.5 text-sm text-gf-maroon hover:underline"
  >
    <.icon name="file-pdf" class="w-4 h-4" /> Download PDF (with images)
  </a>
</div>
```

Note: Check that the `file-pdf` Phosphor icon exists in `assets/vendor/phosphor/`. If not, download it.

**Step 3: Run existing key page tests**

```bash
mix test test/gallformers_web/live/key_live_test.exs
```

Expected: Pass.

**Step 4: Commit**

```bash
git add lib/gallformers_web/live/key_live.ex
git commit -m "Add PDF download links to public key page"
```

---

### Task 7: Add admin "Regenerate PDFs" action

**Files:**
- Modify: `lib/gallformers_web/live/admin/key_live/form.ex`

**Step 1: Add a "Regenerate PDFs" button to the admin form template**

In the form template, in the footer/actions area, add a button (visible in edit mode only):

```heex
<button
  :if={@mode == :edit}
  type="button"
  phx-click="regenerate_pdfs"
  class="gf-btn gf-btn-secondary"
>
  Regenerate PDFs
</button>
```

**Step 2: Add the event handler**

```elixir
@impl true
def handle_event("regenerate_pdfs", _params, socket) do
  key = socket.assigns.key
  trigger_pdf_generation(key)
  {:noreply, put_flash(socket, :info, "PDF regeneration started for #{key.title}")}
end
```

**Step 3: Run admin tests**

```bash
mix test test/gallformers_web/live/admin/key_live_test.exs
```

Expected: Pass.

**Step 4: Commit**

```bash
git add lib/gallformers_web/live/admin/key_live/form.ex
git commit -m "Add Regenerate PDFs button to admin key form"
```

---

### Task 8: Add CI test configuration for Typst

**Files:**
- Modify: `test/test_helper.exs` (or test config)

**Step 1: Configure test exclusions**

Tests tagged with `@tag :typst` require the Typst binary. In CI, either:
- Install Typst in the CI workflow and include the tag
- Or exclude the tag in CI and run Typst tests locally only

Check `test/test_helper.exs` for existing `ExUnit.configure` and add `:typst` to the exclude list if Typst won't be in CI:

```elixir
ExUnit.configure(exclude: [:typst | existing_excludes])
```

If Typst will be in CI, add it to the GitHub Actions workflow instead.

**Step 2: Run the full test suite**

```bash
mix precommit
```

Expected: All tests pass, no warnings.

**Step 3: Commit**

```bash
git add test/test_helper.exs
git commit -m "Configure Typst test tag exclusion"
```

---

### Task 9: Visual review and template iteration

This task is manual and iterative.

**Step 1: Generate a PDF from a real key**

```bash
typst compile --input "data=$(cat priv/keys/populus-midge-key.json)" --input images=false priv/typst/key.typ /tmp/populus-midge-key.pdf
open /tmp/populus-midge-key.pdf
```

**Step 2: Review with the user**

Show the PDF and gather feedback on:
- Font choice (Linux Libertine is the default — may want something else)
- Dot leader spacing and alignment
- Couplet number/letter formatting
- Note styling
- Page header/footer content
- Overall spacing and density

**Step 3: Iterate on `priv/typst/key.typ` based on feedback**

This will likely take multiple rounds. Each round: edit template, recompile, review.

**Step 4: Commit final template**

```bash
git add priv/typst/key.typ
git commit -m "Refine key PDF template typography"
```
