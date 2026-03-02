---
status: planned
created: 2026-03-02
updated: 2026-03-02
epic: platform
relates: [74de]
---

# Surface audit extension for verification-before-completion skill

## Context

API audit (matter 74de) revealed that the public API drifted significantly from what the UI shows. The same class of drift affects documentation (CLAUDE.md, admin docs, memory files) and other parallel representations (OpenAPI schemas, test assertions, copilot-instructions).

## Design Decision

Extend the existing `verification-before-completion` skill with a "surface audit" phase that automatically detects what changed and checks whether parallel representations were updated.

## Surface Categories

1. **API parity** — when LiveView/context data changes, do API controllers return the same data?
2. **OpenAPI schemas** — do `api_schemas.ex` definitions match what controllers actually return?
3. **Test assertions** — do API/controller tests assert the current field set?
4. **LLM context docs** — CLAUDE.md component inventory, CODING_STANDARDS.md patterns, copilot-instructions.md, memory files
5. **User-facing docs** — admin-onboarding.md, admin-domain-reference.md, taxonomy.md, runbooks
6. **Parallel config** — copilot-instructions.md vs CLAUDE.md sync

## Approach

Automated detection (git diff to identify what changed) with user interaction for ambiguous cases. Not a dumb checklist — the skill should reason about what surfaces a specific change affects.

