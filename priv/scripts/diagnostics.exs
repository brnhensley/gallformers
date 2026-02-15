import Ecto.Query
alias Gallformers.Repo

# 1. Undescribed galls with real genera (the mislabeled ones)
real_genus_undescribed = Repo.all(
  from gt in "gall_traits",
    join: st in "species_taxonomy", on: st.species_id == gt.species_id,
    join: t in "taxonomy", on: st.taxonomy_id == t.id,
    join: s in "species", on: s.id == gt.species_id,
    where: gt.undescribed == true,
    where: t.type == "genus",
    where: not like(t.name, "Unknown%"),
    select: %{species_id: gt.species_id, name: s.name, genus: t.name}
)
IO.puts("=== DIAGNOSTIC 1: Undescribed galls with real genera ===")
IO.puts("Count: #{length(real_genus_undescribed)}")
Enum.each(real_genus_undescribed, fn r ->
  IO.puts("  #{r.species_id}: #{r.name} (genus: #{r.genus})")
end)

# 2. Of those, how many have sources vs don't
with_sources = Enum.filter(real_genus_undescribed, fn %{species_id: sid} ->
  Repo.exists?(from ss in "species_source", where: ss.species_id == ^sid)
end)
IO.puts("")
IO.puts("=== DIAGNOSTIC 2: Source breakdown of above ===")
IO.puts("  With sources: #{length(with_sources)}")
IO.puts("  Without sources: #{length(real_genus_undescribed) - length(with_sources)}")

# 3. Galls marked datacomplete but lacking sources
complete_no_sources = Repo.all(
  from s in "species",
    where: s.taxoncode == "gall",
    where: s.datacomplete == true,
    where: s.id not in subquery(from ss in "species_source", select: ss.species_id),
    select: %{id: s.id, name: s.name}
)
IO.puts("")
IO.puts("=== DIAGNOSTIC 3: Data-complete galls without sources ===")
IO.puts("Count: #{length(complete_no_sources)}")
Enum.each(complete_no_sources, fn r ->
  IO.puts("  #{r.id}: #{r.name}")
end)

# 4. Current former_undescribed aliases
former_aliases = Repo.all(
  from a in "alias",
    join: als in "alias_species", on: als.alias_id == a.id,
    join: s in "species", on: s.id == als.species_id,
    where: a.type == "former_undescribed",
    select: %{alias_id: a.id, alias_name: a.name, species_id: s.id, species_name: s.name}
)
IO.puts("")
IO.puts("=== DIAGNOSTIC 4: Former undescribed aliases ===")
IO.puts("Count: #{length(former_aliases)}")
Enum.each(former_aliases, fn a ->
  IO.puts("  #{a.species_name} (id:#{a.species_id}) <- alias: \"#{a.alias_name}\" (alias_id:#{a.alias_id})")
end)
