# Whole retained SDK native coordinator

Report-only coordinator for original retained SDK graphs. It does not import a catalog, mutate application projects, drive devices, recover callback qualifiers or rewrite graph files. Default dependencies are explicit, ordinary SDK type graph imports; override with a complete JSON module→dependency-list map when needed.

Run only after the final wheel is frozen:

```sh
python3 tools/verify_ios_sdk.py --wheel FINAL.whl --site EXTRACTED_SITE --wheel-sha256 FINAL_SHA --extraction TASK/outputs/native-api-dev20/sdk-replay/extraction --producer-report TASK/outputs/native-api-dev20/sdk-replay/run.json --producer-sha256 ORIGINAL_RUN_SHA --output FRESH_OUTPUT --jobs 1 --min-free-mb 2048 --timeout 3600
```

`--module UIKit` selects a bounded smoke scope. Omit it to select all original inventory modules. Add `--resume` to the identical command to retain completed, hash-validated module receipts; changed wheel, compiler, graph bytes, producer provenance, target, dependencies, SDK, inventory or harness rejects resume. Retried timeout/error modules use fresh native report files. Original compiler provenance remains historical; new native reports bind the explicitly supplied wheel.

Seven unit tests run with `python3 -m unittest discover -s tests -v`. A read-only preflight against actual retained artifacts validated 298 statuses: 294 successful graph extractions and four failed extractions. Whole-SDK native work has **not** been launched.

Native passes are only generated Swift6 MainActor iOS18 simulator typechecks. Ordinary and explicit specialization passes are counted separately. `coverage` preserves current compiler unsupported reasons; `targetSkipped` remains separate. `no_candidates`, `extraction_failed`, `dependency_extraction_failed`, `timeout`, `disk_floor`, `invalid_report` and verifier/coordinator errors are never native passes. Completion means inventory processing finished, not platform completeness. Exit zero permits explicitly classified empty/extraction-failed scopes; inspect the summary for coverage.

Each module runs in a new process group, with private Swift/Clang caches and temporary files, removed after process exit. A hard timeout or disk floor kills the entire group. Jobs are bounded 1–4 (default1), disk floor at least256MiB (default2GiB); use1 on constrained storage. Final checks rehash all original artifacts and SDK/compiler identities. Individual reports interrupted before completion are never certified. The result is reproducibility/hash continuity within the provided trusted archive, not a cryptographic assertion that an arbitrary caller's metadata originated at Apple. Retained graph expansion is capped512MiB per file.

The coordinator does not discover all transitive imports automatically. An unconfigured dependency produces an explicit native diagnostic; it cannot broaden coverage through invented declarations. No runtime execution claim is made.

`no_candidates` is valid only with a complete zero-candidate report and native verifier exit1; the coordinator records it separately and does not claim a compiler invocation passed. Output ancestry follows the root-owned standard macOS /tmp and /var alias policy; output symlinks and any symlink artifact/cache are rejected. Cleanup kills the entire worker group and removes its private cache on timeout or exceptional exits.
