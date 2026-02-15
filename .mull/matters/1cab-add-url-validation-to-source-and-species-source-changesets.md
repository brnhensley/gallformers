---
status: active
created: 2026-02-15
updated: 2026-02-15
relates: [8257]
needs: [be64]
---

# Add URL validation to source and species_source changesets

Prevent bad URL data from entering the database in the first place.

Fields to validate:
- source.link (Source schema changeset)
- source.licenselink (Source schema changeset)
- species_source.externallink (SpeciesSource schema changeset)

Validation rules:
- Trim whitespace
- If non-empty, must start with http:// or https://
- Reject plain text, DOIs without scheme, literal 'none', etc.
- Consider auto-prepending https:// for values starting with www. (normalize rather than reject)

Apply in Ecto changesets so the DB layer rejects bad data regardless of which admin form or import path creates the record.

Related: be64 (fix existing bad data), follows from investigation docs/investigations/20260215-request-log-anomalies-oom.md Finding #5.
