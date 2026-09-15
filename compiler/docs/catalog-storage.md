# Catalog evidence storage

Schema v2 stores a shared verification payload once and links each tested symbol to it. Evidence remains per symbol and per level; sharing payload bytes never enables an unsupported API or expands a native proof. The Catalog read API and the five-column evidence SELECT view remain available. Writes go through Catalog methods, not direct evidence-view INSERT statements.

Read-only opens accept v1 and v2 without migration. Opening v1 for writing migrates schema and data in one SQLite transaction; failure rolls back to v1. Back up catalogs before upgrading and retain enough disk space for SQLite journals. Old compiler releases that accept only schema v1 cannot read v2. Schema-specific recovery scripts and snapshots must match the target version.

Migration makes old evidence pages reusable but does not shrink the physical database. Compaction is a separate explicit maintenance operation, requiring free workspace and no active transaction. Do not run it as an implicit side effect of app generation.

The storage change preserves source descriptors, evidence levels, exact payloads, native source provenance and availability restrictions. It does not establish broader native API coverage.
