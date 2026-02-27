---
status: done
created: 2026-02-27
updated: 2026-02-27
epic: geo-expansion
relates: [8900]
---

# Include boundaries.pmtiles in Docker build

boundaries.pmtiles (370MB) is gitignored and not included in Docker builds. After deploying maps-rework, all maps were empty because the file was missing from the release. Quick-fixed by SFTP upload but this will be lost on next deploy. Need a durable solution — likely download from S3 during Docker build or at runtime in the entrypoint.
