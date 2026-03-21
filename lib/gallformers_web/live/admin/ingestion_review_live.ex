defmodule GallformersWeb.Admin.IngestionReviewLive do
  use GallformersWeb, :live_view

  require Logger

  alias Gallformers.Galls
  alias Gallformers.Sources
  alias Gallformers.Species

  @pipeline_name "bhl-deepseek-v3"

  @impl true
  def mount(_params, session, socket) do
    current_user = session["current_user"]

    socket =
      socket
      |> assign(
        current_user: current_user,
        page_title: "Source Ingestion Review",
        pdf_hash: nil,
        pipeline_status: nil,
        pipeline_stage: nil,
        pipeline_error: nil,
        cached: false,
        metadata: nil,
        extraction: nil,
        galls: [],
        markdown: nil,
        output_dir: nil,
        # Source matching
        source_search_query: "",
        source_search_results: [],
        selected_source: nil,
        # Species mapping (keyed by "gall:name" or "host:gallname:hostname")
        mapping_open: nil,
        mapping_query: "",
        mapping_results: []
      )
      |> allow_upload(:pdf,
        accept: :any,
        max_entries: 1,
        max_file_size: 50_000_000,
        auto_upload: true,
        progress: &handle_progress/3
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"hash" => hash}, _uri, socket) do
    output_dir = default_output_dir(hash)

    if output_exists?(hash, output_dir) do
      socket =
        socket
        |> assign(pdf_hash: hash, output_dir: output_dir, cached: true)
        |> load_output_files(hash, output_dir)
        |> auto_match_source()
        |> build_galls()

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "No pipeline output found for hash: #{hash}")}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} page_title="Source Ingestion Review">
      <%!-- Upload section --%>
      <div :if={@pdf_hash == nil && @pipeline_status == nil && @metadata == nil}>
        <form id="upload-form" phx-change="validate-upload" phx-submit="noop">
          <.file_dropzone id="pdf-dropzone" upload={@uploads.pdf} label="Upload PDF (.pdf)" />
          <%!-- Show selected file + upload progress --%>
          <div :for={entry <- @uploads.pdf.entries} class="mt-3 flex items-center gap-3">
            <.icon name="ph-file-pdf" class="size-5 text-red-600" />
            <span class="text-sm font-medium">{entry.client_name}</span>
            <div class="flex-1 h-2 bg-gray-200 rounded-full overflow-hidden">
              <div
                class="h-full bg-gf-blue rounded-full transition-all"
                style={"width: #{entry.progress}%"}
              >
              </div>
            </div>
            <span class="text-xs text-gray-500">{entry.progress}%</span>
          </div>
          <div :for={err <- upload_errors(@uploads.pdf)} class="mt-2">
            <.alert variant="error">{error_to_string(err)}</.alert>
          </div>
        </form>
      </div>

      <%!-- Processing (after upload, before results) --%>
      <div :if={@pipeline_status == :running} class="mt-4 flex flex-col items-center gap-3 py-12">
        <.loading_spinner />
        <p class="text-sm text-gray-600">Processing PDF... this may take a minute.</p>
        <p :if={@pipeline_stage} class="text-sm font-medium text-gray-800">{@pipeline_stage}</p>
      </div>

      <%!-- Pipeline error --%>
      <div :if={@pipeline_status == :error} class="mt-4">
        <.alert variant="error">
          Pipeline failed. <pre :if={@pipeline_error} class="mt-2 text-xs whitespace-pre-wrap">{@pipeline_error}</pre>
        </.alert>
      </div>

      <%!-- Loaded data sections --%>
      <div :if={@metadata} class="space-y-6">
        <div class="flex items-center gap-3 text-sm text-gray-500">
          <span>PDF hash: {@pdf_hash}</span>
          <.badge :if={@cached}>cached — pipeline not re-run</.badge>
        </div>

        <%!-- === EXTRACTED GALLS === --%>
        <.card title="Extracted Galls" icon="gf-gall">
          <div class="divide-y">
            <div :for={gall <- @galls} class="py-4 first:pt-0 last:pb-0 space-y-3">
              <%!-- Gall header --%>
              <div>
                <h3 class="text-base font-semibold">
                  <em>{gall.name}</em>
                  <span :if={gall.authority} class="text-gray-500 font-normal">
                    {gall.authority}
                  </span>
                </h3>
                <div :if={gall.matches != []} class="mt-1">
                  <span class="text-xs text-green-700 font-medium">Matched:</span>
                  <span :for={match <- gall.matches} class="ml-1">
                    <.taxon_name name={match.name} />
                    <.link
                      href={~p"/admin/galls/#{match.id}"}
                      target="_blank"
                      class="text-xs text-gf-blue hover:underline ml-1"
                    >
                      Edit
                    </.link>
                  </span>
                </div>
                <div :if={gall.matches == []} class="mt-1 space-y-2">
                  <div class="flex items-center gap-3">
                    <span class="text-xs text-amber-600 font-medium">No match</span>
                    <.link
                      href={~p"/admin/galls/new?name=#{gall.name}"}
                      target="_blank"
                      class="text-xs text-gf-blue hover:underline"
                    >
                      Create gall
                    </.link>
                    <button
                      phx-click="open_mapping"
                      phx-value-key={"gall:#{gall.name}"}
                      phx-value-taxoncode="gall"
                      class="text-xs text-gf-blue hover:underline"
                    >
                      Map to existing
                    </button>
                  </div>
                  <.species_mapper
                    :if={@mapping_open == "gall:#{gall.name}"}
                    id={"map-gall-#{gall.name}"}
                    query={@mapping_query}
                    results={@mapping_results}
                    mapping_key={@mapping_open}
                  />
                </div>
              </div>

              <%!-- Hosts --%>
              <div>
                <h4 class="text-sm font-medium text-gray-700 mb-1">Hosts</h4>
                <div :for={host <- gall.hosts} class="flex items-center gap-2 text-sm ml-2 mb-1">
                  <em>{host.name}</em>
                  <span :if={host.authority} class="text-gray-500 text-xs">
                    {host.authority}
                  </span>
                  <span :if={host.matches != []} class="text-xs text-green-700">
                    — matched:
                    <.link
                      :for={m <- host.matches}
                      href={~p"/admin/hosts/#{m.id}"}
                      target="_blank"
                      class="text-gf-blue hover:underline ml-1"
                    >
                      {m.name}
                    </.link>
                  </span>
                  <span :if={host.matches == []} class="text-xs text-amber-600">
                    — no match
                    <.link
                      href={~p"/admin/hosts/new?name=#{host.name}"}
                      target="_blank"
                      class="text-gf-blue hover:underline ml-1"
                    >
                      create
                    </.link>
                    <button
                      phx-click="open_mapping"
                      phx-value-key={"host:#{gall.name}:#{host.name}"}
                      phx-value-taxoncode="plant"
                      class="text-gf-blue hover:underline ml-1"
                    >
                      map
                    </button>
                  </span>
                  <div :if={@mapping_open == "host:#{gall.name}:#{host.name}"} class="mt-1 ml-2">
                    <.species_mapper
                      id={"map-host-#{gall.name}-#{host.name}"}
                      query={@mapping_query}
                      results={@mapping_results}
                      mapping_key={@mapping_open}
                    />
                  </div>
                </div>
              </div>

              <%!-- Traits --%>
              <div :if={gall.traits != %{} || gall.db_traits}>
                <h4 class="text-sm font-medium text-gray-700 mb-1">Traits</h4>
                <table class="text-xs w-full">
                  <thead>
                    <tr class="text-left text-gray-500 border-b">
                      <th class="pr-4 pb-1">Trait</th>
                      <th class="pr-4 pb-1 text-blue-700">Current (DB)</th>
                      <th class="pr-4 pb-1">Original text</th>
                      <th class="pb-1 text-green-700">Suggested</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      :for={row <- build_trait_rows(gall.traits, gall.db_traits)}
                      class="border-b border-gray-100"
                    >
                      <td class="pr-4 py-1 font-medium align-top">{row.name}</td>
                      <td class="pr-4 py-1 align-top text-blue-700">
                        {row.current || "—"}
                      </td>
                      <td class="pr-4 py-1 text-gray-600 align-top">
                        {row.original || "—"}
                      </td>
                      <td class="py-1 text-green-700">{row.suggested || "—"}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </.card>

        <%!-- === SOURCE === --%>
        <.card title="Source" icon="ph-book-open">
          <div class="space-y-6">
            <%!-- Metadata sub-section --%>
            <div>
              <h3 class="text-sm font-semibold text-gray-700 mb-2">Article Metadata</h3>
              <dl class="text-sm space-y-1 ml-2">
                <div class="flex gap-2">
                  <dt class="font-medium w-20">Title</dt>
                  <dd>{@metadata["title"]}</dd>
                </div>
                <div class="flex gap-2">
                  <dt class="font-medium w-20">Authors</dt>
                  <dd>{Enum.join(@metadata["authors"] || [], ", ")}</dd>
                </div>
                <div class="flex gap-2">
                  <dt class="font-medium w-20">Year</dt>
                  <dd>{@metadata["year"]}</dd>
                </div>
              </dl>
            </div>

            <%!-- Source lookup sub-section --%>
            <div class="border-t pt-4">
              <h3 class="text-sm font-semibold text-gray-700 mb-2">Source Lookup</h3>
              <div id="source-typeahead" class="ml-2">
                <.typeahead
                  id="source-picker"
                  label="Match to existing source"
                  placeholder="Search sources..."
                  query={@source_search_query}
                  results={@source_search_results}
                  selected={@selected_source}
                  search_event="search_source"
                  select_event="select_source"
                  clear_event="clear_source"
                  display_fn={&source_display/1}
                >
                  <:result :let={source}>
                    <div>{source.title}</div>
                    <div class="text-xs text-gray-500">
                      {source.author} ({source.pubyear})
                    </div>
                  </:result>
                </.typeahead>
                <div :if={@selected_source == nil} class="mt-2">
                  <.link
                    href={~p"/admin/sources/new"}
                    target="_blank"
                    class="text-sm text-gf-blue hover:underline"
                  >
                    Create new source
                  </.link>
                </div>
              </div>
            </div>

            <%!-- Source text sub-section --%>
            <div class="border-t pt-4">
              <h3 class="text-sm font-semibold text-gray-700 mb-2">Source Text</h3>
              <p class="text-xs text-gray-500 mb-2 ml-2">
                Edit to keep only the relevant passage for the species-source description.
              </p>
              <form phx-change="update-markdown">
                <textarea
                  id="source-text"
                  name="markdown"
                  class="w-full h-96 font-mono text-sm border rounded p-2"
                  phx-debounce="500"
                >{@markdown}</textarea>
              </form>
            </div>

            <%!-- Link actions --%>
            <div :if={@galls != []} class="border-t pt-4">
              <div
                :for={gall <- @galls}
                :if={@selected_source && gall.matches != []}
                class="mb-2"
              >
                <.button
                  phx-click="link_source"
                  phx-value-gall-name={gall.name}
                  phx-value-species-id={hd(gall.matches).id}
                >
                  Link Source to {hd(gall.matches).name}
                </.button>
              </div>
              <p :if={@selected_source == nil} class="text-sm text-gray-400">
                Select a source above to enable linking.
              </p>
            </div>
          </div>
        </.card>
      </div>
    </Layouts.admin>
    """
  end

  # -- Upload handling --

  defp handle_progress(:pdf, entry, socket) do
    if entry.done? do
      {pdf_content, pdf_path} =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          content = File.read!(path)
          dest = Path.join(System.tmp_dir!(), "ingestion-#{entry.client_name}")
          File.cp!(path, dest)
          {:ok, {content, dest}}
        end)

      hash =
        :crypto.hash(:sha256, pdf_content)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 12)

      output_dir = socket.assigns[:output_dir] || default_output_dir(hash)

      socket =
        socket
        |> assign(pdf_hash: hash, pdf_path: pdf_path, output_dir: output_dir)
        |> maybe_load_or_run_pipeline(hash, pdf_path, output_dir)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # -- Pipeline --

  defp maybe_load_or_run_pipeline(socket, hash, pdf_path, output_dir) do
    if output_exists?(hash, output_dir) do
      socket
      |> load_output_files(hash, output_dir)
      |> assign(cached: true)
      |> auto_match_source()
      |> build_galls()
    else
      run_pipeline_async(socket, hash, pdf_path, output_dir)
    end
  end

  defp output_exists?(hash, output_dir) do
    metadata_path = Path.join(output_dir, "#{@pipeline_name}-4-metadata.json")
    extraction_path = Path.join(output_dir, "#{@pipeline_name}-5-data-extract.json")
    markdown_path = Path.join(output_dir, "#{@pipeline_name}-#{hash}.md")

    File.exists?(metadata_path) && File.exists?(extraction_path) && File.exists?(markdown_path)
  end

  defp load_output_files(socket, hash, output_dir) do
    metadata_path = Path.join(output_dir, "#{@pipeline_name}-4-metadata.json")
    extraction_path = Path.join(output_dir, "#{@pipeline_name}-5-data-extract.json")
    markdown_path = Path.join(output_dir, "#{@pipeline_name}-#{hash}.md")

    with {:ok, meta_raw} <- File.read(metadata_path),
         {:ok, metadata} <- Jason.decode(meta_raw),
         {:ok, ext_raw} <- File.read(extraction_path),
         {:ok, extraction} <- Jason.decode(ext_raw),
         {:ok, markdown} <- File.read(markdown_path) do
      assign(socket,
        pipeline_status: :done,
        metadata: metadata,
        extraction: extraction,
        markdown: markdown
      )
    else
      _ -> assign(socket, pipeline_status: :error)
    end
  end

  defp run_pipeline_async(socket, hash, pdf_path, output_dir) do
    lv = self()

    Task.start(fn ->
      pipeline_dir = pipeline_base_dir()
      pipeline_config = Path.join(pipeline_dir, "pipelines/#{@pipeline_name}.yaml")

      args = [
        "run",
        "ingest",
        "run",
        "-p",
        pipeline_config,
        "--source-id",
        hash,
        "-i",
        pdf_path,
        "-o",
        Path.dirname(output_dir)
      ]

      port =
        Port.open(
          {:spawn_executable, System.find_executable("uv")},
          [:binary, :exit_status, :stderr_to_stdout, args: args, cd: pipeline_dir]
        )

      collect_pipeline_output(port, lv, hash, output_dir, "")
    end)

    assign(socket, pipeline_status: :running, pipeline_stage: nil)
  end

  defp collect_pipeline_output(port, lv, hash, output_dir, buffer) do
    receive do
      {^port, {:data, data}} ->
        new_buffer = buffer <> data

        # Send progress for complete lines
        {lines, rest} = split_lines(new_buffer)

        for line <- lines do
          if line =~ ~r/Running .+ \(step \d+\)/ || line =~ ~r/Pipeline .+ complete/ do
            send(lv, {:pipeline_progress, String.trim(line)})
          end
        end

        collect_pipeline_output(port, lv, hash, output_dir, rest)

      {^port, {:exit_status, 0}} ->
        send(lv, {:pipeline_complete, hash, output_dir})

      {^port, {:exit_status, _code}} ->
        send(lv, {:pipeline_failed, buffer})
    end
  end

  defp split_lines(data) do
    parts = String.split(data, "\n")
    # Last element is incomplete (no trailing newline) — keep as buffer
    {Enum.slice(parts, 0..-2//1), List.last(parts)}
  end

  defp default_output_dir(hash) do
    Path.join(pipeline_base_dir(), "output/#{hash}")
  end

  defp pipeline_base_dir do
    Path.join(File.cwd!(), "services/source-ingestion")
  end

  # -- Source auto-matching --

  defp auto_match_source(socket) do
    title = get_in(socket.assigns, [:metadata, "title"]) || ""

    if String.length(title) >= 3 do
      results = Sources.search_sources(title)

      case results do
        [single] ->
          assign(socket,
            selected_source: single,
            source_search_query: "",
            source_search_results: []
          )

        [_ | _] ->
          assign(socket,
            source_search_query: title,
            source_search_results: results
          )

        [] ->
          assign(socket, source_search_query: title, source_search_results: [])
      end
    else
      socket
    end
  end

  # -- Gall collapsing --

  defp build_galls(socket) do
    extraction = socket.assigns.extraction || []

    # Group raw records by gall species name
    grouped =
      extraction
      |> Enum.group_by(fn raw -> get_in(raw, ["gall_species", "name"]) || "" end)

    galls =
      Enum.map(grouped, fn {gall_name, records} ->
        first = hd(records)
        matches = find_species_matches(gall_name, "gall")

        hosts =
          records
          |> Enum.map(fn raw ->
            host_name = get_in(raw, ["host_species", "name"]) || ""

            %{
              name: host_name,
              authority: get_in(raw, ["host_species", "authority"]),
              matches: find_species_matches(host_name, "plant")
            }
          end)
          |> Enum.uniq_by(& &1.name)

        traits = merge_traits(records)
        db_traits = load_db_traits(matches)

        %{
          name: gall_name,
          authority: get_in(first, ["gall_species", "authority"]),
          matches: matches,
          hosts: hosts,
          traits: traits,
          db_traits: db_traits
        }
      end)

    assign(socket, galls: galls)
  end

  defp load_db_traits([]), do: nil

  defp load_db_traits(matches) do
    # Use the first match's ID to load traits
    species_id = hd(matches).id
    gall_traits = Galls.get_gall_traits(species_id)

    case Galls.get_gall_filter_values_batch([species_id]) do
      %{^species_id => filter_vals} ->
        %{
          detachable: (gall_traits && gall_traits.detachable) || nil,
          colors: filter_vals.colors,
          shapes: filter_vals.shapes,
          textures: filter_vals.textures,
          walls: filter_vals.walls,
          cells: filter_vals.cells,
          alignments: filter_vals.alignments,
          plant_parts: filter_vals.plant_parts,
          forms: filter_vals.forms,
          seasons: filter_vals.seasons
        }

      _ ->
        nil
    end
  end

  defp merge_traits(records) do
    # Collect all traits across records, merge originals and suggested values
    records
    |> Enum.flat_map(fn raw -> Map.to_list(raw["traits"] || %{}) end)
    |> Enum.group_by(fn {trait_name, _} -> trait_name end, fn {_, values} -> values end)
    |> Enum.map(fn {trait_name, value_list} ->
      originals =
        value_list
        |> Enum.map(fn v -> v["original"] end)
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.uniq()

      suggested =
        value_list
        |> Enum.flat_map(fn v -> v["suggested"] || [] end)
        |> Enum.uniq()

      {trait_name, %{originals: originals, suggested: suggested}}
    end)
    |> Enum.filter(fn {_, v} -> v.originals != [] || v.suggested != [] end)
    |> Enum.into(%{})
  end

  # -- Species matching --

  defp find_species_matches(name, _taxoncode) when name in [nil, ""], do: []

  defp find_species_matches(name, taxoncode) do
    direct = Species.search_species_by_name(name, taxoncode, 5)
    alias_matches = Species.find_species_with_alias(name)

    (format_direct_matches(direct) ++ format_alias_matches(alias_matches, taxoncode))
    |> Enum.uniq_by(& &1.id)
    |> Enum.take(5)
  end

  defp format_direct_matches(matches) do
    Enum.map(matches, fn m ->
      %{id: m.id, name: m.name, taxoncode: m.taxoncode, match_type: :name}
    end)
  end

  defp format_alias_matches(matches, taxoncode) do
    matches
    |> Enum.filter(fn m -> taxoncode == nil || m.taxoncode == taxoncode end)
    |> Enum.map(fn m ->
      %{
        id: m.species_id,
        name: m.species_name,
        taxoncode: m.taxoncode,
        match_type: {:alias, m.alias_type}
      }
    end)
  end

  # -- Helpers --

  defp source_display(source), do: source.title

  attr :id, :string, required: true
  attr :query, :string, required: true
  attr :results, :list, required: true
  attr :mapping_key, :string, required: true

  defp species_mapper(assigns) do
    ~H"""
    <div class="max-w-sm">
      <div class="flex gap-1">
        <input
          type="text"
          value={@query}
          placeholder="Search species..."
          phx-keyup="mapping_search"
          phx-value-key={@mapping_key}
          class="text-xs border rounded px-2 py-1 flex-1"
          phx-debounce="300"
        />
        <button
          phx-click="close_mapping"
          class="text-xs text-gray-400 hover:text-gray-600 px-1"
        >
          cancel
        </button>
      </div>
      <div :if={@results != []} class="border rounded mt-1 max-h-40 overflow-y-auto">
        <button
          :for={match <- @results}
          phx-click="select_mapping"
          phx-value-key={@mapping_key}
          phx-value-species-id={match.id}
          class="block w-full text-left text-xs px-2 py-1 hover:bg-gray-100"
        >
          <.taxon_name name={match.name} /> <span class="text-gray-400">({match.taxoncode})</span>
        </button>
      </div>
    </div>
    """
  end

  # Map extracted trait names to DB trait field names
  @trait_db_keys %{
    "color" => :colors,
    "shape" => :shapes,
    "texture" => :textures,
    "walls" => :walls,
    "cells" => :cells,
    "alignment" => :alignments,
    "plant_part" => :plant_parts,
    "form" => :forms,
    "season" => :seasons,
    "detachable" => :detachable
  }

  defp build_trait_rows(extracted_traits, db_traits) do
    all_names =
      (Map.keys(extracted_traits) ++ db_trait_names(db_traits))
      |> Enum.uniq()
      |> Enum.sort()

    all_names
    |> Enum.map(&build_trait_row(&1, extracted_traits, db_traits))
    |> Enum.reject(fn row ->
      row.current == nil && row.original == nil && row.suggested == nil
    end)
  end

  defp db_trait_names(nil), do: []

  defp db_trait_names(db_traits) do
    @trait_db_keys
    |> Enum.filter(fn {_ext, db_key} ->
      Map.get(db_traits, db_key) not in [nil, [], ""]
    end)
    |> Enum.map(fn {ext_name, _} -> ext_name end)
  end

  defp build_trait_row(name, extracted_traits, db_traits) do
    ext = Map.get(extracted_traits, name)

    %{
      name: name,
      current: format_db_trait(name, db_traits),
      original: if(ext && ext.originals != [], do: Enum.join(ext.originals, "; ")),
      suggested: if(ext && ext.suggested != [], do: Enum.join(ext.suggested, ", "))
    }
  end

  defp build_manual_match(species) do
    %{id: species.id, name: species.name, taxoncode: species.taxoncode, match_type: :manual}
  end

  defp apply_species_mapping(galls, key, match) do
    Enum.map(galls, fn gall ->
      cond do
        key == "gall:#{gall.name}" ->
          db_traits = load_db_traits([match])
          %{gall | matches: [match], db_traits: db_traits}

        String.starts_with?(key, "host:#{gall.name}:") ->
          host_name = String.replace_prefix(key, "host:#{gall.name}:", "")
          hosts = apply_host_mapping(gall.hosts, host_name, match)
          %{gall | hosts: hosts}

        true ->
          gall
      end
    end)
  end

  defp apply_host_mapping(hosts, target_name, match) do
    Enum.map(hosts, fn host ->
      if host.name == target_name, do: %{host | matches: [match]}, else: host
    end)
  end

  defp format_db_trait(_name, nil), do: nil

  defp format_db_trait(name, db_traits) do
    case Map.get(@trait_db_keys, name) do
      nil ->
        nil

      :detachable ->
        db_traits.detachable

      db_key ->
        case Map.get(db_traits, db_key, []) do
          [] -> nil
          values -> Enum.join(values, ", ")
        end
    end
  end

  defp error_to_string(:too_large), do: "File is too large."
  defp error_to_string(:not_accepted), do: "Only PDF files are accepted."
  defp error_to_string(:too_many_files), do: "Only one file at a time."
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"

  # -- handle_info --

  @impl true
  def handle_info({:set_output_dir, dir}, socket) do
    {:noreply, assign(socket, output_dir: dir)}
  end

  @impl true
  def handle_info({:load_data, metadata, extraction, markdown}, socket) do
    socket =
      socket
      |> assign(
        pipeline_status: :done,
        metadata: metadata,
        extraction: extraction,
        markdown: markdown
      )
      |> auto_match_source()
      |> build_galls()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:pipeline_progress, stage}, socket) do
    {:noreply, assign(socket, pipeline_stage: stage)}
  end

  @impl true
  def handle_info({:pipeline_complete, hash, output_dir}, socket) do
    socket =
      socket
      |> load_output_files(hash, output_dir)
      |> auto_match_source()
      |> build_galls()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:pipeline_failed, output}, socket) do
    Logger.error("Ingestion pipeline failed: #{output}")
    {:noreply, assign(socket, pipeline_status: :error, pipeline_error: output)}
  end

  # -- handle_event --

  @impl true
  def handle_event("validate-upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("noop", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update-markdown", %{"markdown" => markdown}, socket) do
    {:noreply, assign(socket, markdown: markdown)}
  end

  @impl true
  def handle_event("search_source", %{"query" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Sources.search_sources(query)
      else
        []
      end

    {:noreply, assign(socket, source_search_query: query, source_search_results: results)}
  end

  @impl true
  def handle_event("select_source", %{"id" => id}, socket) do
    source = Sources.get_source!(String.to_integer(id))

    {:noreply,
     assign(socket,
       selected_source: source,
       source_search_query: "",
       source_search_results: []
     )}
  end

  @impl true
  def handle_event("clear_source", _params, socket) do
    {:noreply,
     assign(socket,
       selected_source: nil,
       source_search_query: "",
       source_search_results: []
     )}
  end

  @impl true
  def handle_event("open_mapping", %{"key" => key, "taxoncode" => _taxoncode}, socket) do
    {:noreply, assign(socket, mapping_open: key, mapping_query: "", mapping_results: [])}
  end

  @impl true
  def handle_event("close_mapping", _params, socket) do
    {:noreply, assign(socket, mapping_open: nil, mapping_query: "", mapping_results: [])}
  end

  @impl true
  def handle_event("mapping_search", %{"key" => key, "value" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        taxoncode = if String.starts_with?(key, "gall:"), do: "gall", else: "plant"
        Species.search_species_by_name(query, taxoncode, 10)
      else
        []
      end

    {:noreply, assign(socket, mapping_query: query, mapping_results: results)}
  end

  @impl true
  def handle_event("select_mapping", %{"key" => key, "species-id" => id_str}, socket) do
    species_id = String.to_integer(id_str)
    species = Species.get_species!(species_id)
    match = build_manual_match(species)

    galls = apply_species_mapping(socket.assigns.galls, key, match)

    {:noreply,
     socket
     |> assign(galls: galls, mapping_open: nil, mapping_query: "", mapping_results: [])
     |> put_flash(:info, "Mapped to #{species.name}")}
  end

  @impl true
  def handle_event(
        "link_source",
        %{"gall-name" => _gall_name, "species-id" => species_id_str},
        socket
      ) do
    species_id = String.to_integer(species_id_str)
    source = socket.assigns.selected_source
    markdown = socket.assigns.markdown

    case Sources.create_species_source(%{
           species_id: species_id,
           source_id: source.id,
           description: markdown
         }) do
      {:ok, _ss} ->
        species = Species.get_species!(species_id)

        {:noreply, put_flash(socket, :info, "Linked #{species.name} to #{source.title}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create species-source link")}
    end
  end
end
