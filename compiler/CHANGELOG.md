# Unreleased

- Add typed compact/large native route titles across Dart, JSON, SwiftUI and Compose. Default to compact instead of platform-dependent iOS automatic title size; make Snap’s composer choice explicit.

- Add typed shared emptiness and boolean predicates for visibility/enabled state across Dart/JSON, canonical IR and Swift/Java/Compose emission; preserve row scopes and map dependencies. Hide empty Snap status messages from one authored condition.

- Render untitled iOS tab-container roots through their owned navigation stacks, avoiding redundant outer navigation chrome. Verify composer tab visibility through native UI input.

- Bind iOS route roots and destinations to their owning router; fix photo-composer cancellation discovered by native UI tests. Add an installed-Snap iOS photo selection/cancellation harness.

- Preserve Android blank-title route composition while native back chrome changes, preventing navigation from resetting remembered scroll/input state.

- Center Snap’s uncropped photo composition preview in a shared dark frame after Android capture/navigation UI verification.

- Align Android camera placeholders vertically with the shared native frame contract; author Snap camera placeholder padding and text alignment once in Dart.

- Correct optional Swift protocol-returning method syntax using structural types; refresh UIKit native conformance and retain failed/target-skipped restrictions in exported catalogs.

- Strengthen iOS native verification to check property result types; reject protocol construction without a concrete conforming type. Verify and export a refreshed MapKit catalog with required framework imports.

- Preserve nested Swift optionals and support optional Objective-C instance-property reads, with one-layer unwrap semantics and native MapKit execution verification.

- Add catalog-driven iOS simulator verification for failable Foundation construction, authored unwrap failures and preservation of prior values.

- Execute typed Pair, SparseArray, ArrayMap and LruCache sequences in the Android ART harness; enforce unchecked-warning failures and record compiler-source hashes.

- Add typed native Android construction through NativeCall.constructedType, with checked owner bounds, parameter/result substitution and catalog-driven constructor sweeps.

# 0.4.0.dev10 — development preview

Local installable preview; full native API coverage and production acceptance remain unfinished.

- Specialize Android native instance members from concrete receiver type arguments, including inherited owner bindings and checked fields. Extend catalog/sequence integration and native SDK sweep tooling.

- Bind authored app names to generated Android string resources and iOS Info.plist metadata. Preserve user-owned native project files; incompatible legacy name bindings fail explicitly on regeneration.

# 0.4.0.dev9 — development preview

Local installable preview; full native API coverage and production acceptance remain unfinished.

- Authored iOS font sizes now honor native Dynamic Type via ScaledMetric, including styled button labels; shared fontSize semantics explicitly honor each platform's text-size preferences.
- Android authored font sizes clear inherited Material line heights, preserving natural native line metrics for headings, controls and fields. Add an emulator measurement harness.
- Shared native operation contracts distinguish suspension from execution context. iOS emits async native implementations; Android defers main operations or uses its worker executor without blocking for completion.

# 0.4.0.dev8 — development preview

Local installable preview; full native API coverage and production acceptance remain unfinished.

- Shared native operations support worker execution with scalar snapshots, main-thread completion, stale-result rejection and native lifecycle cancellation on iOS and Android.
- Android native calls retain SDK thread requirements; shared operations validate their declared execution context instead of silently invoking worker-only APIs on the main thread.

# 0.4.0.dev7 — development preview

Local installable preview; full native API coverage and production acceptance remain unfinished.

- Dart NativeCall exposes explicit typeArguments and NativeClass values; the native operation schema accepts and bounds both forms.
- Android typed values accept structured native class literals, including exact primitive-wrapper and array Class types, for generic SDK arguments.
- Add a bounded Android generic-method native compilation sweep with separate emission rejections and compiler failures.
- Reject a generic varargs overload pattern that remains ambiguous after explicit specialization, discovered in native Android animation API checks.

# 0.4.0.dev6 — development preview

Local installable preview; full native API coverage and production acceptance remain unfinished.

- Android generic instance methods accept checked typed receivers and explicit method type arguments, including typed collection-to-array calls.
- Android static generic methods accept explicit reference type arguments through direct catalog requests and typed native sequences, validate declared bounds, and emit concrete result types with explicit Java type witnesses.
- Android native arguments and field assignments support primitive boxing, reference widening after boxing, and unboxing with primitive widening. Explicit null unboxing rejects; selected overloads retain exact casts.

# 0.4.0.dev5 — development preview

Local installable preview; full native API coverage and production acceptance remain unfinished.

- Android authored button alignment positions the label inside its full native surface, preserving the authored frame and hit region.
- Android typed references preserve declared generic superclass/interface arguments when checking assignability.
- Non-generic Android classes retain fixed generic parent arguments through inheritance; raw or incompatible references cannot silently satisfy concrete parameterized arguments.

# 0.4.0.dev4 — development preview

Local installable preview; full native API coverage and production acceptance remain unfinished.

- Swift C function-pointer types preserve @convention(c) in typed references, optional forms and native calls; Swift closure references cannot silently substitute for C pointers.

- Mutating Swift property getters require a mutable receiver and retain that contract from SDK declarations.

- Swift explicit protocol existential types preserve any Protocol, optional and nested collection forms in typed SDK calls. Concrete-to-protocol conversions are not inferred.

- Swift actor owners are distinguished from class-shaped SDK graph records. Actor instance calls require explicit async context and emit await; direct isolated property writes reject.

- Native Swift autoclosure parameters preserve lazy evaluation by forwarding typed zero-argument callbacks as native autoclosure expressions.

# 0.4.0.dev3 — development preview

Local installable preview. Production acceptance and complete platform coverage remain unfinished.

- Filling children of shared rows now use native Compose weights instead of each requesting the full row width. Fixed-width children retain their width; filling spacers receive only one weight.

- Styled SwiftUI buttons now own their authored frame, padding, background and interaction shape inside the native label; disabled state and motion stay on the control.

- Shared rows, columns and cards use explicit zero spacing and start alignment on iOS even when Style is omitted, matching Compose defaults and empty Style declarations.

- Android pushed routes retain a native back control even when their shared navigation title is empty; blank root routes remain without a title bar.

- Android shared navigation now consumes applied scaffold padding at tab and titled-route boundaries, following Compose inset propagation contracts.

- Native SDK verification accepts explicit import contexts and preserves required imports in descriptors and emitted calls.

- SDK sweep normalization now shares owner/actor-aware parsing with native verification and records the extractor identity.

- Swift SDK inout parameters use checked mutable references and native address arguments; sequence mutation and overlap rejection are verified.

- iOS SDK verification selects and records Swift language mode explicitly, separating Swift 5 evidence from Swift 6 checks.

- Structured Swift callback types preserve Sendable and MainActor attributes; native Swift 6 tests cover valid execution and rejection of non-sendable captures.

- Android device checks now execute generated constructor/field-write/readback sequences, including a native floating-point conversion boundary.

- Android typed references support Java primitive widening while preserving exact overload selection. Primitive arrays remain invariant and narrowing/boxing are not inferred.

- Android native calls accept explicitly typed array values, exposed as Dart NativeArray, allowing concrete nested arrays to reach compatible Object[] APIs without casts or runtime conversion.

- `sdk test-android-values` exposes reviewed native scalar/array execution checks through the compiler package, with explicit device selection and fresh evidence paths.

- Native SDK verification accepts an explicit iOS deployment version, using it for availability checks, compiler targets and evidence.

# 0.4.0.dev2 — development preview

Local installable preview; production acceptance remains incomplete.

- The packaged `sdk verify-ios` command performs native verification and catalog installation in one workflow. Descriptor replacement and compiled evidence commit atomically, and current reports fingerprint compiler sources as well as SDK inputs.

- Swift function types are represented structurally, including parameter/result types, optional callbacks and async/throws effects. Explicit native callback references now pass through SDK and sequence generation with native execution coverage.

- Native sequences expose input callback escaping requirements inferred from SDK calls, verified by compiling and executing a generated sequence with a retained Swift callback.

- Swift SDK parameters retain escaping-callback metadata from full declarations and parameter signatures. Native batch probes preserve it for callback type aliases; native retention/negative compilation tests cover the distinction.

- Certified iOS descriptor export validates complete batch counts, exact SDK graph hashes and unique known API identities before writing output; stale or conflicting evidence cannot silently certify a changed import.

- Native iOS batch verification discovers compressed SDK graphs, supplies its actual main-actor caller context, rejects stale evidence paths and records input hashes/toolchain identity. Empty candidate sets produce explicit zero-result reports.

- SDK symbol graph ingestion reads gzip inputs directly and validates the complete document, including duplicate keys, trailing content and compressed-file integrity, before catalog construction succeeds.

- Generated native operations containing checked result handling are now exercised together with emitted Swift/Kotlin flow handlers, verifying atomic state publication and authored failure continuations.

- NativeUnwrap now guards Android reference results as well as Swift optionals, with explicit failure contracts and native success/null execution checks.

- Swift native sequences support checked optional binding with authored failure messages, exposing NativeUnwrap in Dart and preserving native throws handling without force unwraps.

- Tuple projections are verified through Dart shared-operation authoring, routed app generation and native Swift/Java execution, including an overflow-boundary regression.

- Swift tuple result types and typed native-sequence projections unlock multi-result SDK calls, including native URLSession async data/response selection. Dart exposes NativeTupleElement; raw source and unchecked optional tuple selection remain disallowed.

- Generation receipts fingerprint compiler sources/templates and effective registry mappings, retaining per-target identities so compiler-only upgrades cannot hide an older native target.

# 0.4.0.dev1 — development preview

Local installable preview; not a production release or complete platform API certification.

- Android SDK scalar literals follow the selected primitive signature, supporting checked long/byte/short/char/float values through Dart/JSON. Scalar and array element validation share one lowering path; 20 value cases execute on Android ART.

- A reusable Android ART array-call harness verifies generated SDK calls on an explicitly selected device, records SDK/source/DEX identities and removes its temporary payload without changing installed apps.

- Android SDK array arguments and field assignments accept typed collection data from Dart/JSON, emitting native Java arrays with element bounds checks, nested arrays and no conversion runtime.

- Swift SDK calls support structured collection/concrete generic type references and typed array/dictionary literals, with bounded parsing and per-element validation. Native Foundation collection calls pass iOS SDK typechecking and host execution.

- iOS symbolgraph ingestion resolves custom global-actor attributes by precise symbol identity and requires a matching qualified caller context. Swift 6 execution verifies direct calls within that actor.

- Native source audits now detect changed or missing generated files even when iOS and Android input receipts match. User-owned edits remain preserved and explicitly outside this integrity claim.

- iOS SDK actor-isolation metadata and explicit caller-context validation prevent known MainActor APIs from being emitted into an unspecified context; shared main-thread operations propagate the requirement.

- Core SDK conformance evidence now records the actual compiler invocation/version and captured SDK bytes, rejects mismatched probe/test sets and verifies transactional rollback for unknown IDs.

- Android core SDK archive ingestion adds Java/Javax/XML APIs without treating the platform SDK as a third-party dependency. Exact bytecode bridge flags preserve typed APIs, and Android boot-stub compilation verifies 15,723 core signatures.

- Native module export inspects exact verified class files, preventing host JDK boot-classpath substitution, and rejects archive/internal class identity mismatches. Provenance distinguishes the corrected v2 inspection path.

- Routed App native operation declarations and typed NativeOperationEffect integrate shared Dart/JSON contracts with direct Swift/Java calls, atomic result publication, authored failure flows, generated-source ownership and per-target SDK provenance. Full native example builds pass on iOS and Android.

- Typed Dart NativeOperation authoring through explicit buildOperation() evaluation, with CLI opt-in, JSON/canonical/native-source equivalence and wheel-only authoring verification.

- Shared scalar native operation contracts emit ordinary Swift/Java static APIs and reject missing or type-divergent implementations. Native sequence locals use hygienic emitted names, with authoring-to-native binding metadata.

- SDK native-call sequences for Java and Swift, with inferred local result types, checked dataflow and CLI/MCP entry points. Native fixtures verify ordered construction, field writes and subsequent calls without a dcflight runtime.

- Typed Android writable-field assignment through the SDK CLI/MCP interface, with mutability, receiver, type and nullability validation. A scalable harness compiles every supported writable field and records operation-specific evidence.

# 0.3.0

- Explicit trusted Dart buildApp() authoring with functions, loops and reusable components; JSON remains an independent input to the same typed IR.
- Version-2 typed routes, native SwiftUI/Compose stacks and tabs, shared presentation/motion, keyed collections, strict asynchronous effects and native secure storage.
- Shared-source Snap reference app: account, People, text/photo messaging, stories and expiry. Camera, maps and consented location use generic authored device contracts instead of separate product screen templates; hardware and UI acceptance are recorded separately from model tests.
- Per-platform generation provenance detects stale authoring, typed IR or shared-logic inputs after a one-target rebuild.
- Content-locked Android native dependencies, bytecode API export, catalog/MCP reuse and artifact verification.
- Host-aware Android runtime graph resolution aligns native modules with Compose; all locked artifact bytes are retained while Maven duplicates are excluded from application classpaths.
- Ad-hoc signed iOS simulator execution for native Keychain; Android ARM64 execution and source/binary audits.
- Strict validation rejects unsupported semantics rather than silently ignoring author intent.

DC Dart stays on released 0.1.1. No language dependency was changed. This version records compiler functionality, not a claim of all-platform coverage or completed production release certification.
