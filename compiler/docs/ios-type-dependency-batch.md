# Batch exact-type dependency planning

`dcflight sdk plan-ios-type-dependencies --capture CAPTURE --output FRESH_DIRECTORY`
validates one retained SDK extraction and scans each successful graph's symbols once.
A temporary indexed SQLite database resolves exact referenced nominal identities for
all requested primary modules. No spelling guesses, callable promotion, native
compilation credit, or catalog writes occur.

The single-module planner and batch planner share publication and duplicate checks.
Each successful `plans/MODULE/type-dependencies.json` is the ordinary single-module
plan, with the same original byte hashes, selected nominal identities, context and
independently consumable primary/type graph paths. The top-level `batch.json`
records every requested module as planned or rejected, including rejection reasons.
Invalid capture identity/context, changing inputs or exhausted global budgets
reject the whole batch atomically. Per-module ambiguity and dependency bounds are
explicit rejections, not silently absent coverage.

Original graph bytes are copied into a private output pool. Regular hardlinks within
that private pool avoid duplicating originals hundreds of times; no source capture
file is hardlinked. Treat the published tree as immutable: editing a hardlink changes
its aliases and invalidates plan hashes. Derived nominal subsets are independent
files. Copying the entire bundle without preserving hardlinks may require more disk.

Bounds include 512 modules, 4096 graphs, 4 GiB expanded validated capture, one million
symbols, four million reference rows, 1 GiB SQLite pages, 2 GiB physical retained
output and 262144 output entries. Individual graph, reference-depth, dependency-count
and 512 MiB per-plan limits remain those of the single planner. The default disk
floor is 1 GiB and deadline 1800 seconds. Budget checks run between bounded reads,
periodically during indexing and between plans; these are cooperative checks, not
an OS process resource sandbox. The temporary index is deleted before publication.
Final capture file-set/status/graph hashes and compiler fingerprints must remain
unchanged. An external supervisor can enforce a hard wall-clock deadline.

The installed compiler command requires no catalog and keeps progress JSON on stderr, with a compact final JSON summary on stdout. `--module` may repeat; `--timeout` and `--min-free-mb` bound planning. Per-module rejection counts are explicit in the summary and full batch receipt; no native coverage credit is granted. The repository helper `tools/plan_ios_type_dependencies_batch.py` remains available.
