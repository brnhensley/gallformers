# FTS5 Full-Text Search for V2 Species Search

## Motivation

The current V2 search uses basic `LIKE` queries which lack:
- **Prefix search**: "cyn" matching "Cynipid"
- **Relevance ranking**: Best matches first via bm25()

FTS5 is SQLite's built-in full-text search engine that provides both.

## How FTS5 Works

FTS5 creates an inverted index mapping tokens (words) to documents:

```
Index structure:
  "quercus" → [species 1, species 45, species 203]
  "alba"    → [species 1, species 12]
  "cynipid" → [species 8, species 15, species 89]
```

Queries look up tokens in the index and intersect results, with bm25() scoring relevance.

## Implementation

### 1. Migration

```elixir
# priv/repo/migrations/20250113_add_species_fts.exs
defmodule Gallformers.Repo.Migrations.AddSpeciesFts do
  use Ecto.Migration

  def up do
    # prefix='2 3' enables 2+ and 3+ char prefix searches
    execute """
      CREATE VIRTUAL TABLE species_fts USING fts5(
        name,
        aliases,
        tokenize='porter unicode61',
        prefix='2 3'
      )
    """

    execute """
      INSERT INTO species_fts(rowid, name, aliases)
      SELECT
        s.id,
        s.name,
        COALESCE(GROUP_CONCAT(a.name, ' '), '')
      FROM species s
      LEFT JOIN aliasspecies asp ON s.id = asp.species_id
      LEFT JOIN alias a ON asp.alias_id = a.id
      GROUP BY s.id
    """
  end

  def down do
    execute "DROP TABLE IF EXISTS species_fts"
  end
end
```

### 2. Search Functions

```elixir
# lib/gallformers/search.ex

@doc """
Search species using FTS5 with prefix matching and relevance ranking.
Falls back to LIKE search if FTS5 returns no results.
"""
def search_species(query) when byte_size(query) >= 1 do
  fts_results = search_species_fts(query)

  if Enum.empty?(fts_results) do
    search_species_like(query)
  else
    fts_results
  end
end

def search_species(_query), do: []

defp search_species_fts(query) do
  fts_query =
    query
    |> sanitize_fts_query()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&(&1 <> "*"))  # Each term becomes prefix search
    |> Enum.join(" ")           # AND logic between terms

  # "q alba" becomes "q* alba*" → matches "Quercus alba"

  case Repo.query("""
    SELECT s.id, s.name, s.taxoncode, bm25(species_fts) as rank
    FROM species_fts
    JOIN species s ON species_fts.rowid = s.id
    WHERE species_fts MATCH ?1
    ORDER BY rank
    LIMIT 50
  """, [fts_query]) do
    {:ok, result} -> map_fts_results(result)
    {:error, _} -> []
  end
end

defp search_species_like(query) do
  pattern = "%" <> String.replace(query, " ", "%") <> "%"

  from(s in Species,
    where: fragment("lower(?) LIKE lower(?)", s.name, ^pattern),
    limit: 50
  )
  |> Repo.all()
end

defp sanitize_fts_query(query) do
  query
  |> String.replace(~r/["\(\)\*\:\-]/, " ")
  |> String.trim()
end

defp map_fts_results(%{rows: rows}) do
  Enum.map(rows, fn [id, name, taxoncode, rank] ->
    %{id: id, name: name, taxoncode: taxoncode, rank: rank}
  end)
end
```

### 3. Keeping FTS Index in Sync

Call after species create/update/delete in admin functions:

```elixir
# lib/gallformers/species.ex

def update_species_fts(species_id) do
  # Remove old entry
  Repo.query!("DELETE FROM species_fts WHERE rowid = ?1", [species_id])

  # Re-insert with current data
  Repo.query!("""
    INSERT INTO species_fts(rowid, name, aliases)
    SELECT s.id, s.name, COALESCE(GROUP_CONCAT(a.name, ' '), '')
    FROM species s
    LEFT JOIN aliasspecies asp ON s.id = asp.species_id
    LEFT JOIN alias a ON asp.alias_id = a.id
    WHERE s.id = ?1
    GROUP BY s.id
  """, [species_id])
end

def delete_species_fts(species_id) do
  Repo.query!("DELETE FROM species_fts WHERE rowid = ?1", [species_id])
end

# Alternative: Full rebuild (simpler, use for batch operations)
def rebuild_species_fts do
  Repo.query!("DELETE FROM species_fts")

  Repo.query!("""
    INSERT INTO species_fts(rowid, name, aliases)
    SELECT s.id, s.name, COALESCE(GROUP_CONCAT(a.name, ' '), '')
    FROM species s
    LEFT JOIN aliasspecies asp ON s.id = asp.species_id
    LEFT JOIN alias a ON asp.alias_id = a.id
    GROUP BY s.id
  """)
end
```

## Query Behavior

### FTS5 Query Examples

| Input | FTS Query | Matches |
|-------|-----------|---------|
| `q alba` | `q* alba*` | Quercus alba |
| `cyn` | `cyn*` | Cynipid, Cynips, Cynipini |
| `oak apple` | `oak* apple*` | Oak apple gall |
| `quercus` | `quercus*` | All Quercus species |

### FTS5 vs LIKE Comparison

| Query | LIKE (`%q%alba%`) | FTS5 (`q* alba*`) |
|-------|-------------------|-------------------|
| `q alba` | ✓ Quercus alba | ✓ Quercus alba |
| `alba` | ✓ Quercus alba | ✓ Quercus alba |
| `ercus` | ✓ Quercus (mid-word) | ✗ (not word start) |
| Ranking | No | Yes (bm25) |
| Speed | Slower (full scan) | Fast (index lookup) |

The hybrid approach tries FTS5 first for speed and ranking, then falls back to LIKE for mid-word substring matches.

## FTS5 Features

### Tokenizer Options

- `unicode61` - Unicode-aware word boundaries (default)
- `porter` - Stemming ("galling" matches "gall")
- `ascii` - ASCII-only, faster but less accurate

Using `porter unicode61` combines both.

### Advanced Query Syntax

```sql
-- Phrase search (exact sequence)
WHERE species_fts MATCH '"oak apple"'

-- OR search
WHERE species_fts MATCH 'oak OR maple'

-- NOT search
WHERE species_fts MATCH 'oak NOT red'

-- Column-specific
WHERE species_fts MATCH 'name:quercus'
```

### Ranking with bm25()

The `bm25()` function returns relevance scores (lower = more relevant):
- Exact matches score better than partial
- Multiple term matches score better than single
- Rarer terms contribute more to relevance

## Considerations

### Storage

FTS5 creates additional index tables. For the Gallformers species dataset (~thousands of records), this is negligible.

### Sync Strategy

For Gallformers where data changes infrequently (admin curation only):
- Update FTS on individual species changes
- Full rebuild is fast enough for batch imports

### Deployment

FTS5 is built into SQLite (since 3.9.0, 2015). No additional extensions needed for ecto_sqlite3.

## Testing

```elixir
# test/gallformers/search_test.exs

describe "search_species/1" do
  test "prefix search matches partial terms" do
    results = Search.search_species("q alba")
    assert Enum.any?(results, &(&1.name == "Quercus alba"))
  end

  test "results are ranked by relevance" do
    results = Search.search_species("quercus")
    # Exact match should rank higher than partial
    ranks = Enum.map(results, & &1.rank)
    assert ranks == Enum.sort(ranks)
  end

  test "falls back to LIKE for mid-word matches" do
    results = Search.search_species("ercus")
    assert Enum.any?(results, &String.contains?(&1.name, "ercus"))
  end
end
```
