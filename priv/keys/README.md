# Identification Key Source Files

These JSON files are the **original source material** for the dichotomous identification keys. The key data now lives in the database (see `Gallformers.Keys` context and `keys` table).

No application code reads these files at runtime. They're kept as reference in case key data needs to be re-imported or the JSON format is needed for export/interchange.

`schemas/key-schema.json` defines the expected JSON structure.
