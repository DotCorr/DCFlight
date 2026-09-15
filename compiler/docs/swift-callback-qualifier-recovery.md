# Recovering omitted Swift callback qualifiers

Some SDK symbolgraphs omit an outer callback's `@Sendable` even though the precise Swift symbol identity and SDK interface preserve it. `tools/recover_swift_callback_qualifiers.py` creates an explicit derived graph bundle; it does not silently modify SDK output or relax actor checks.

```sh
python tools/recover_swift_callback_qualifiers.py /path/to/original/graphs --module UniformTypeIdentifiers --output /path/to/fresh/bundle --interface /path/to/SDK/UniformTypeIdentifiers.swiftinterface
python tools/verify_ios_api_batch.py --module UniformTypeIdentifiers=/path/to/fresh/bundle --limit 0 --swift-version 6 --ios-version 18.0 --output /path/to/fresh/native-report.json
```

The recovery batches exact Swift precise IDs through the installed `swift-demangle --expand --tree-only`. Its binary hash is recorded. Only a `ConcurrentFunctionType` directly attached to a top-level callback parameter can add `@Sendable`. Name, arity and structural position must match; ambiguous, generic or unfamiliar trees remain uncorrected with an explicit skipped reason. Nested callback qualifiers and optional wrappers are never lifted onto the outer callback. No API names, OS-specific exceptions, unchecked Sendable declarations or actor flags are hardcoded.

Original compressed or uncompressed graph bytes remain in `bundle/original/`. Top-level graph files are explicitly derived data. `qualifier-recovery.json` records both hashes, exact changed symbol IDs, parameter indices, original symbol hashes and expanded demangler trees. The optional SDK interface is copied and hashed as corroborating provenance. It is not used as a text-replacement authority. Retain the entire bundle alongside native reports and exported descriptors; copying only the derived files loses extraction provenance. `verify_bundle()` verifies the retained file set and hashes without any SDK tool or implicit sidecar dependency. It does not authenticate an externally supplied compiler or certify native behavior.

Normal SDKCatalog lowering reads the derived graph's typed parameter fragments. Every other normalized API field must remain identical. Existing native verification then checks the generated calls against the real SDK. Adding `@Sendable` constrains callers; the native emitter still rejects a non-Sendable reference. The recovery manifest alone never promotes APIs to native-tested status.

Bounds:256 graph files,128MiB expanded per graph,100,000 callback candidates,4,096 characters per precise identity,64 IDs/64KiB input per demangler batch,8MiB output/30seconds per batch,64 levels/32,768 nodes per expanded tree. This version recovers only direct, supported outer function-type parameters. Unsupported or ambiguous shapes remain visible gaps.

Validation recovered both missing UniformTypeIdentifiers callback qualifiers: normal Swift6 full-module verification passed215signatures. Two deliberately non-Sendable callback probes failed both structured emission and native Swift compilation. These are source/typechecking proofs, not callback execution, hardware testing or a complete-platform claim. All recovery tooling stays on the development machine; generated apps gain no runtime component.

Recovery rechecks the original graph file set and hashes before and after processing. JSON is decoded from the exact retained bytes. Failed recovery may leave an incomplete output directory without a success manifest; retry into a fresh directory. Bundle verification rejects manifest and artifact-parent symlinks.

Combined generic-class metadata can include source-byte hashes. If rewriting a graph changes these non-qualifier facts, recovery rejects the graph, including formatting-only hash differences. This remains fail-closed; the tool does not drop or relabel class-fact provenance. Such graphs require a separately reviewed transformation.
