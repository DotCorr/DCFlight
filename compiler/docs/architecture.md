# Architecture decision: native projects are the product

Status: shared routed application migration in progress; broad platform coverage remains incomplete.

The older repository builds a runtime using Flutter Zero, Dart, FFI/JNI, a reconciler and native view wrappers. That implementation is not a dependency, implementation substrate, or fallback for this package. Existing legacy work is retained during the transition. The new compiler imports none of it.

## Invariant

After generation, application source compiles using the platform toolchain alone. There is no dcflight runtime library, Dart VM, JavaScript engine introduced by dcflight, dynamic dispatch bridge, interpreter, registry loader, renderer, component dispatch table, or dcflight framework process in the application. Native Swift/SwiftUI/Combine and Android platform/Jetpack libraries are ordinary platform dependencies.

Development pipeline:

```
JSON or const Dart declarations
  -> frontend syntax parsing
  -> validation and typed canonical IR
  -> reviewed semantic mappings + native backend
  -> artifact/ownership plan
  -> conflict-safe filesystem synchronization
  -> ordinary Xcode / Android Gradle project
  -> native toolchain build
```

Runtime paths are ordinary generated application code: a SwiftUI Button calls an AppModel method; an Android Button listener calls an AppModel method and explicit field updates. AppScreen is application-specific source with concrete native types. It never interprets an IR tree, looks up a component by name, or delegates to a dcflight library. The registry and synchronization manifest are absent from detached project builds.

## Canonical IR

`dcflight/ir.py` defines immutable Application, State, Action, Node, Literal and Reference values. Scalar types are explicit string, signed Int32, and bool types. References resolve during validation. UI properties acquire their types from reviewed capabilities before backend entry. The IR carries semantic capability IDs and stable node IDs, not Dart objects, JSON blobs or native-language AST nodes.

The v1 action algebra supports typed assignment, increment, boolean toggle, direct user-native action calls and typed shared-logic CALL actions. Increment wraps at the Int32 boundary identically on both targets. Integers outside Int32 and implicit conversions are rejected. Strings must contain valid Unicode scalar values. App display names cannot contain control characters or begin with Android resource-reference prefixes (`@` or `?`). The legacy action algebra remains available. Shared business logic can instead call typed DC Dart functions containing native-compiled control flow. Arbitrary hosted Dart is not silently translated.

The two frontends converge before backend selection. The Dart frontend parses a documented const constructor subset without executing Dart or requiring a Dart SDK at generation time. The separate Dart authoring package provides actual classes for editor analysis. It is never copied to app projects. DC Dart business logic is a separate compiled input. Typed LogicModule/LogicFunction ABI declarations and CALL actions connect its exports to application state. Released DC Dart 0.1.1+ compiles the same source to distinct mobile native targets before synchronization. Only audited application objects/libraries and ordinary static C ABI/JNI glue enter native projects; the compiler and authoring source remain development inputs. See shared-logic.md for the supported ABI and language limits.

## Native backends

The backend contract consumes validated IR plus a registry and returns a mapping from relative paths to `Artifact(content, ownership)`. It cannot write files directly. iOS emits SwiftUI source, Combine state, and an Xcode project. The version-1 Android backend emits Java/framework Views. Version-2 routed applications use Kotlin/Jetpack Compose with native navigation and an Android Gradle project. Dependencies are explicit; native-package modules are locked and audited separately.

Web, Windows and Linux are extension points, not implemented targets. Add a backend implementing the artifact contract, add its reviewed target mappings and semantic compatibility checks, then register it in BACKENDS. Missing targets fail explicitly. A future web backend may emit ordinary browser JavaScript; it must not introduce an additional dcflight engine. Windows/Linux must choose and document actual native toolkits.

Layouts use native VStack/HStack and Compose Row/Column (LinearLayout for version 1). Shared authored styles specify spacing, typography, colors, frames and alignment; remaining native behavior follows each control's contract. Different screen sizes and accessibility settings can produce different layouts. Unknown properties fail rather than being ignored.

## Version-2 shared application contracts

`navigation_ir.py`, `flow_ir.py`, `collection_ir.py` and `media_ir.py` extend the immutable typed representation with routes, native stacks/tabs, explicit effect/completion graphs, typed keyed records and transient media. Both frontends lower into these types before choosing a native backend. Trusted Dart evaluation is explicit (`--evaluate-dart`) and supports ordinary Dart construction of the authoring model; it is development-time execution only.

Product strings, forms, layout, navigation destinations, requests and client decisions belong to the shared app source. Native generators implement generic contracts such as presenting an OS picker, storing a token in Keychain/Keystore, validating a response or applying an authored route change. They must not invent alternate app screens, error copy, request endpoints or business rules. Shared DC Dart selectors choose authored effect branches through audited native objects. No effect graph is interpreted at runtime: concrete model methods and native API calls are emitted.

See [effects](shared-effects-contract.md), [collections](shared-collections-contract.md) and [media/timers](shared-media-contract.md) for cancellation, callback ownership, atomic output, image bounds and current restrictions. Supporting an indexed SDK signature is not equivalent to implementing these shared semantics.

## Source ownership and synchronization

- iOS: `App/Generated/**` and shared-logic `Native/**` are compiler-managed. `App/User/**` and the initial `.xcodeproj` are user-owned.
- Android: `AppModel.java`, `AppScreen.java`, shared-logic `SharedLogic.java`, JNI source and its audited application library are compiler-managed. MainActivity, Gradle files, manifest and all additional native files are user-owned.
- Routed Android additionally manages `AuthoredApplication.kt`, `NativeEffects.kt` and its generated native adapters. `MainActivity.kt`, Gradle files and manifest remain user-owned. New required permissions/dependencies must be reconciled explicitly when upgrading an existing project; a fresh generated project is a separate verification requirement.
- User-owned project files are created once. Changing the authoring app name after initial generation does not overwrite display-name customizations in native project settings. Changing application ID requires a new output directory and explicit migration.
- Every generated file may be opened and edited in ordinary native tools. Before overwriting or removing it, synchronization compares its content with the last generated hash. Manual edits cause a conflict; move durable customizations into user files, make the equivalent authoring edit, or reconcile the generated file explicitly. There is no destructive force switch or implied two-way AST merge.
- Explicit node IDs determine native symbols and Swift filenames. IDs are ASCII, length-limited, and unique ignoring case so case-insensitive filesystems cannot alias nodes. Reordering children preserves node identity. Android currently regenerates one application screen file, with stable symbols; Swift emits one file per node.
- Identical files are not rewritten. Stale untouched generated files are deleted. Modified stale files block the entire update. A per-output exclusive lock, full conflict preflight, atomic file replacement and rollback on ordinary I/O failures protect edits. Multi-file transactions are not crash-atomic across power loss; a leftover lock requires recovery and review. Symlinks under the output root and path traversal are rejected.
- Regenerating one target preserves previously generated other targets. The `.dcflight` directory is build-time metadata outside both native project source roots.
- `.dcflight/source.json` records normalized authoring/IR hashes and shared-logic input hashes separately for each generated target. One-target generation preserves the other target's older evidence. `dcflight audit` flags mismatched inputs; older projects without per-target receipts report unknown until regenerated. Matching receipts prove which inputs were recorded at generation, not visual parity, absence of later native edits, or the identity of installed binaries. Native build/install receipts remain necessary.

## Native escape hatches

A `native` node names a symbol implemented by user-owned UserViews source. A `native` action invokes a user-owned UserActions function. There are no source-code strings in JSON and no dynamic native dispatch.

For symbol `badge`, iOS calls `UserViews.v_badge(model: model)`; Android calls `UserViews.v_badge(activity, model)`. For action `change`, iOS calls `UserActions.a_change(model)` and Android calls `UserActions.a_change(model)`. Native code can call its platform APIs directly and can use the generated model. The compiler requires corresponding user source files to exist; actual type/signature correctness is checked by the native compiler. Source auditing must be rerun after user changes.

A complete native example is in `examples/native.json` with real per-platform sources in `examples/native/`. Escape hatches are the supported path for capabilities beyond the shared capability set. They do not imply arbitrary native behavior is portable.

## Registry and bulk API ingestion

Two different artifacts deliberately exist:

1. **Reviewed capabilities** have property types, binding rules, native templates, native symbols and documentation provenance. The baseline family table in `tools/seed_registry.py` emits the registry. Backends consume the table, so adding a simple control mapping does not require adding another handwritten backend branch. Bindings, parenting and native hooks are explicit backend contracts requiring native tests when extended.
2. **SDK inventories** preserve native identities, overload signatures, SDK version, source hash and availability metadata where provided. They are untrusted, unmapped discovery data. Importing a symbol does not claim it has a correct semantic mapping. Android annotations/nullability remain in signatures; there is no invented common API equivalence.

Apple symbol graphs and Android metalava API text are supported. Use `tools/ingest_sdk.py` to extract whole installed Apple modules and import Android API inventories. Normalized outputs are deterministic and sorted. The schema is generated from reviewed capabilities; `tools/check_registry.py` checks drift and generates the all-mappings fixture. A schema validates local shape; compiler validation also checks graph-wide identities, state references, portable types and action compatibility.

Initial real SDK ingestion covered 74,380 SwiftUI symbols and 55,237 Android API symbols. These are inventory counts, not 129,617 working cross-platform mappings. Ten reviewed baseline capabilities are implemented, including the native extension point. SDK snapshots and metadata are recorded separately from executable mappings.

## AI tooling

The CLI exposes schema, registry search, validation, canonical IR inspection, generation preview, compilation, auditing and inventory import. `python3 -m dcflight mcp` starts a development-only, read-only MCP stdio service implementing protocol 2025-03-26 with registry search, schema and app validation/IR tools. Tool results report unsupported capabilities before generation. Generation remains an explicit CLI operation with the same validation and synchronization path.

## Evidence and limits

Unit tests cover frontend equivalence, invalid input, stable identities, no-op generation, partial-target preservation, user-file ownership, manual-edit conflicts, stale deletion, rollback, path protection, schema drift, bulk import and MCP behavior. `tools/verify_native.py` copies only native projects to detached directories, builds with platform tools and runs emitted state/action code. It optionally produces Android APKs and verifies actual iOS binary dependencies.

Source scanning is defense in depth, not a mathematical proof about arbitrary edited native code or transitive system-library internals. Stronger evidence comes from generated build graphs without runtime packages, detached native builds, binary dependency inspection, and generated-model execution. User-added libraries must be reviewed separately. Real device interaction, accessibility audits, signing, store deployment and production lifecycle behavior remain future validation work.

Hot reload is not promised by the absence of a runtime. File synchronization supports incremental development; preview/rebuild/relaunch and any native hot-reload facilities must be implemented per platform without changing release dependencies.

## Primary references

- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [Android framework Views](https://developer.android.com/reference/android/view/View)
- [Android build configuration](https://developer.android.com/build)
- [Android 15 API snapshot](https://android.googlesource.com/platform/frameworks/base/+/android-15.0.0_r1/core/api/current.txt)
- [MCP stdio transport, 2025-03-26](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports)


## SDK catalog and typed native emission

The SQLite catalog is development-only. It retains exact per-SDK native declarations, source provenance and independently recorded native compilation/execution evidence. iOS symbol-graph and Android metalava adapters emit typed ordinary native expressions; they reject unsupported signatures and invalid arguments. This access is distinct from the smaller shared semantic UI registry. Callback implementations, lifecycle, ownership, permissions and cross-platform behavior require explicit implementation beyond a signature.

Android source snapshots are stored beside the database in a content-addressed `.sources` directory, so the catalog can move without depending on its original SDK input path. Snapshot integrity is checked before emission. iOS descriptors contain the information needed by the Swift emitter. The catalog and its snapshots never enter generated applications.

Broad SDK sweeps record successes, unavailable imports, excluded private modules and adapter-required C++ candidates separately. Native conformance harnesses retain exact symbol identities and compiler errors. Failed or unsupported APIs cannot be labeled verified. Emittable does not mean runtime behavior is tested, and no supported-signature count implies complete native application semantics.

### Current composition boundaries

Routed applications use shared typed screen trees, native stack/tab navigation, state/actions, service requests, and presentation. SwiftUI and Compose output are generated from that shared representation. Legacy whole-screen social templates are rejected in routed applications. Platform-specific native views remain explicit user-owned escape hatches.

DC Dart shares explicitly declared, audited scalar ABI decision functions. Shared authored flow effects generate ordinary native networking, navigation and device adapters. The integrated application logic ABI accepts bounded borrowed UTF-8 string inputs with explicit failure handling. Records, collections, string results, and lifecycle-scoped asynchronous request polling remain unsupported. This is not a compiler for arbitrary shared asynchronous Dart programs. No VM fills these gaps; additional language/ABI semantics require intentional implementation and native verification.
