---
status: done
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

Implemented the extraction adapter follow-up.

Decisions captured in code:
- Renamed the Elixir adapter from `Gallformers.IngestionPipeline.PythonPort` to `Gallformers.IngestionPipeline.Stages.Extract.PythonExtractor` so the boundary is owned by the extract stage and named for extraction responsibility rather than the Erlang transport.
- Renamed the Python entrypoint from `priv/python/extraction_port.py` to `priv/python/pdf_text_extractor.py`.
- Updated the extract stage config seam from `:python_port` to `:extractor`.
- Kept `uv` as a local-development fallback, but production/preview release images no longer depend on `uv` being present at runtime.

Runtime/deploy support:
- Both `Dockerfile` and `Dockerfile.preview` now install `python3` in the runtime image.
- Both builder stages vendor the Python extraction dependencies into `priv/python/vendor` with `pip install --target ... /app/priv/python` during image build.
- The extractor prefers an explicitly configured Python executable, then a runtime Python + vendored dependency path, and only falls back to `uv run` when no vendored runtime is present.

Verification:
- `mix compile --warnings-as-errors`
- targeted extraction tests
- `mix precommit` (passed)
