---
status: raw
created: 2026-04-25
updated: 2026-04-25
epic: source-ingestion
---

# Source ingestion Python extraction adapter follow-up

## Scope
Follow-up work from PR #540 review for the Python-backed PDF extraction path in source ingestion. This matter is intentionally limited to the extraction adapter boundary, naming, and production runtime/deploy support.

## Problem summary
The current extraction integration exposes the transport mechanism too high in the API:
- Elixir module name: `Gallformers.IngestionPipeline.PythonPort`
- Python entrypoint name: `priv/python/extraction_port.py`

This makes the implementation detail (`Port`) part of the public shape of the code and also mixes two concerns in one place:
- launching an external Python process
- defining the PDF text extraction behavior used by the extract stage

## Follow-up implementation work
1. Refactor the Elixir-side extraction adapter to use an extraction-focused name and boundary rather than a transport-focused one.
2. Rename the Python entrypoint to match the extraction responsibility rather than the Erlang transport mechanism.
3. Reassess module placement so the adapter is clearly owned by the extract stage or by a narrowly scoped extraction area, rather than by the ingestion pipeline root as a generic-looking module.
4. Validate or implement production runtime support for the Python extraction path. The current PR does not yet demonstrate that deploy targets will have `uv` and the required Python dependencies available in production.

## Open decisions
- Final naming for the Elixir adapter module.
- Final naming for the Python script entrypoint.
- Whether the adapter should live directly under the extract stage namespace or under a dedicated extraction-focused namespace shared only by extract-related code.
- Whether the Python-backed extraction path is acceptable for the first production slice if deployment/runtime support is not fully wired yet.

## Notes
- This is an architecture and operability follow-up, not an ingestion-lock follow-up.
- The deployment/runtime support gap is the highest-risk item in this set.

