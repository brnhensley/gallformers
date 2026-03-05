"""Export human-curated gall-host association data for a source as a JSON baseline.

Usage:
    python scripts/export_source_baseline.py <source_id> [--db <path>]

Outputs a JSON file matching the data-extract pipeline schema for comparison.
"""

import json
import sqlite3
import sys
from pathlib import Path


DEFAULT_DB = Path(__file__).resolve().parents[3] / "priv" / "gallformers.sqlite"

TRAIT_TABLES = {
    "shape": ("gall_shape", "shape_id", "shape", "shape"),
    "color": ("gall_color", "color_id", "color", "color"),
    "texture": ("gall_texture", "texture_id", "texture", "texture"),
    "walls": ("gall_walls", "walls_id", "walls", "walls"),
    "cells": ("gall_cells", "cells_id", "cells", "cells"),
    "alignment": ("gall_alignment", "alignment_id", "alignment", "alignment"),
    "plant_part": ("gall_plant_part", "plant_part_id", "plant_part", "part"),
    "form": ("gall_form", "form_id", "form", "form"),
    "season": ("gall_season", "season_id", "season", "season"),
}


def get_taxonomy_chain(conn, species_id):
    """Walk up the taxonomy tree from a species to find family, order, etc.

    Uses the species_taxonomy join table to find the species' genus,
    then walks parent_id up to family/order.
    """
    result = {"family": None, "genus": None, "order": None}

    # Get the taxonomy entry for this species (usually a genus)
    row = conn.execute(
        """
        SELECT t.id, t.name, t.type, t.parent_id
        FROM species_taxonomy st
        JOIN taxonomy t ON t.id = st.taxonomy_id
        WHERE st.species_id = ?
        LIMIT 1
        """,
        (species_id,),
    ).fetchone()

    if not row:
        return result

    tid = row[0]
    while tid:
        r = conn.execute(
            "SELECT id, name, type, parent_id FROM taxonomy WHERE id = ?", (tid,)
        ).fetchone()
        if not r:
            break
        _, name, ttype, parent_id = r
        if ttype == "family":
            result["family"] = name
        elif ttype == "genus":
            result["genus"] = name
        elif ttype == "order":
            result["order"] = name
        tid = parent_id

    return result


def get_traits(conn, species_id):
    """Get all traits for a gall species."""
    traits = {}

    for trait_name, (join_table, fk_col, lookup_table, value_col) in TRAIT_TABLES.items():
        rows = conn.execute(
            f"""
            SELECT l.{value_col}
            FROM {join_table} jt
            JOIN {lookup_table} l ON l.id = jt.{fk_col}
            WHERE jt.species_id = ?
            """,
            (species_id,),
        ).fetchall()
        values = [r[0] for r in rows]
        traits[trait_name] = {
            "original": None,  # human-curated data doesn't track original text
            "suggested": values,
        }

    # Detachable from gall_traits
    row = conn.execute(
        "SELECT detachable FROM gall_traits WHERE species_id = ?", (species_id,)
    ).fetchone()
    traits["detachable"] = row[0] if row else "unknown"

    return traits


def get_hosts(conn, gall_species_id):
    """Get host species for a gall."""
    rows = conn.execute(
        """
        SELECT sp.id, sp.name
        FROM gallhost gh
        JOIN species sp ON sp.id = gh.host_species_id
        WHERE gh.gall_species_id = ?
        """,
        (gall_species_id,),
    ).fetchall()
    return rows


def export_source(conn, source_id):
    """Export all gall-host associations for a source."""
    # Get source info
    source = conn.execute(
        "SELECT id, title, author FROM source WHERE id = ?", (source_id,)
    ).fetchone()
    if not source:
        print(f"Source {source_id} not found", file=sys.stderr)
        sys.exit(1)

    print(f"Source: {source[1]} by {source[2]}")

    # Get all gall species linked to this source
    gall_rows = conn.execute(
        """
        SELECT sp.id, sp.name
        FROM species_source ss
        JOIN species sp ON sp.id = ss.species_id
        WHERE ss.source_id = ? AND sp.taxoncode = 'gall'
        ORDER BY sp.name
        """,
        (source_id,),
    ).fetchall()

    print(f"Found {len(gall_rows)} gall species")

    records = []
    for gall_id, gall_name in gall_rows:
        gall_taxonomy = get_taxonomy_chain(conn, gall_id)
        traits = get_traits(conn, gall_id)
        hosts = get_hosts(conn, gall_id)

        if not hosts:
            record = {
                "gall_species": {
                    "name": gall_name,
                    "authority": None,
                    "family": gall_taxonomy["family"],
                    "order": gall_taxonomy["order"],
                },
                "host_species": {
                    "name": None,
                    "authority": None,
                    "family": None,
                },
                "traits": traits,
                "description": None,
                "location": None,
                "confidence": 1.0,
            }
            records.append(record)
        else:
            for host_id, host_name in hosts:
                host_taxonomy = get_taxonomy_chain(conn, host_id)
                record = {
                    "gall_species": {
                        "name": gall_name,
                        "authority": None,
                        "family": gall_taxonomy["family"],
                        "order": gall_taxonomy["order"],
                    },
                    "host_species": {
                        "name": host_name,
                        "authority": None,
                        "family": host_taxonomy["family"],
                    },
                    "traits": traits,
                    "description": None,
                    "location": None,
                    "confidence": 1.0,
                }
                records.append(record)

    print(f"Exported {len(records)} gall-host association records")
    return records


def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/export_source_baseline.py <source_id> [--db <path>]")
        sys.exit(1)

    source_id = int(sys.argv[1])
    db_path = DEFAULT_DB

    if "--db" in sys.argv:
        idx = sys.argv.index("--db")
        db_path = Path(sys.argv[idx + 1])

    if not db_path.exists():
        print(f"Database not found: {db_path}", file=sys.stderr)
        sys.exit(1)

    conn = sqlite3.connect(str(db_path))
    records = export_source(conn, source_id)
    conn.close()

    output_dir = Path("output") / "baselines"
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"source-{source_id}-baseline.json"
    output_path.write_text(json.dumps(records, indent=2))
    print(f"Written to {output_path}")


if __name__ == "__main__":
    main()
