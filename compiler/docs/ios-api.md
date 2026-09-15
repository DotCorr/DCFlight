# SDK-derived iOS API authoring

`dcflight.platforms.ios_api` is a development-time adapter. It reads installed Apple Swift symbol graphs and emits ordinary Swift expressions. SDK data supplies names and signatures; reviewed Python code validates and formats calls. SDK documentation and declarations are never executed as templates. No registry, Python interpreter, dispatcher, bridge, Dart VM, or dcflight library is included in emitted source.

## Verify and install through the CLI

```sh
dcflight sdk verify-ios work/sdk-inventory/uikit --module UIKit \
  --catalog work/sdk.sqlite --report work/uikit-verification.json
```

This packaged command requires Xcode and the iOS simulator SDK. It checks all
currently emittable signatures by default (`--limit 0`), targeting arm64 iOS 18.0
Simulator by default. Use `--ios-version 26.2` (major.minor) to select another
minimum deployment version; availability checks and the compiler use the same
version. This does not change the deployment version of an existing app. `--limit N` samples N signatures; it does not certify untested records.
The report and adjacent `.descriptors` directory must be new paths. The command
replaces only the named iOS catalog scope, committing descriptors and exact
compiled evidence in one transaction. Other platforms/scopes are preserved.
Failed evidence validation rolls back the replacement. Current reports record
compiler source hashes, and export rejects compiler changes after verification.
This is local native typechecking, not signed attestation or device testing.

## Public Python interface

`SDKCatalog.from_symbolgraphs` accepts both plain `.symbols.json` and gzip
`.symbols.json.gz` paths, without extracting compressed files to disk. Pass each
graph once. Both streaming passes validate the complete JSON document and gzip
integrity before returning a catalog. Low-level `symbolgraph.symbols` consumers
must exhaust iteration before accepting an import; entries can precede a later
validation error. Reading new descriptors does not transfer older native
certification to them or certify every emittable signature.

`symbolgraph.graph_paths(directory)` discovers both forms and rejects empty
directories or duplicate compressed/plain copies of the same graph. The batch
verifier and its descriptor export use this discovery path. Batch verification
runs in an explicit main-actor Swift context, records source graph hashes and
toolchain identity, and requires a fresh output path. `--limit 0` checks every
currently emittable signature; unsupported descriptors remain outside that set.
Availability exclusions and native compiler failures are reported separately.

Certified descriptor export requires a complete report with matching graph
hashes and module set. It rejects conflicting or unknown API identities,
missing rejection diagnostics and an existing output directory before writing
records. Old reports without input hashes must be regenerated. These local
consistency checks do not provide cryptographic attestation or replace native
runtime testing.

```python
from pathlib import Path
from dcflight.platforms.ios_api import SDKCatalog, Literal, Reference

catalog = SDKCatalog.from_symbolgraphs(
    Path("work/sdk-inventory/foundation").glob("*.symbols.json"),
    module="Foundation",
)
# Search is discovery. Resolve the precise identity before generating an overload.
for api in catalog.search("UUID.init()", emittable_only=True):
    print(api.id, api.to_dict())

api = catalog.get("s:10Foundation4UUIDVACycfc")
result = catalog.emit_call(api.id)
assert result.expression == "(`UUID`() as UUID)"
assert result.imports == ("Foundation",)
```

`API` contains precise SDK identity, module, full owner path, member kind, typed parameters, external labels, result type, async/throws flags, setter availability and platform availability. `records()` yields JSON-serializable dictionaries for persistent catalogs. `parse_cli_value` accepts exactly `{"literal": value}` or `{"ref": "binding", "type": "SDK.Type"}`; it rejects source strings and unknown fields.

Parameters also carry a boolean `escaping` flag. Swift symbol graphs sometimes
retain `@escaping` only in the full declaration; imports preserve that metadata
separately from the type spelling. Native batch probes use it on their caller
parameters so a callback alias can be forwarded to an API that retains it.
Existing records default to false and need reimporting to obtain the metadata.
This does not add callback bodies to the Dart DSL or establish callback
cancellation, capture ownership or shared-app lifecycle support. Native callers
remain responsible for those contracts.

Explicit function types such as `(Int) -> Bool`, `() async throws -> Data`
and `((String) -> Void)?` are also parsed structurally. Their parameter/result
types, effects and optionality participate in reference type checking. Native
callback values can be forwarded through generated sequences; strings containing
callback bodies are not accepted as literals. Explicit function types may carry
`@Sendable` and `@MainActor`; these attributes participate in type matching and
are preserved in normalized output. An unannotated callback is not silently
accepted as sendable. Custom global-actor function attributes, ownership modifiers and inout
inside callback signatures and Dart-authored callback bodies remain unsupported. Native Swift
still checks capture sendability and actor access; no dispatcher is introduced.

`emit_call(id, arguments, receiver=Reference(...), ios_version=(18, 0))` handles constructors, top-level functions, static/instance methods and readable properties. `emit_set(id, value, receiver=...)` handles SDK properties with explicit public `get set` declarations. Static members reject a receiver; instance members require a binding with the exact owner type. Callers supply every parameter, including defaulted parameters, to avoid inventing default semantics. Async/throwing calls require `allow_async=True`/`allow_throws=True`; callers must place them in an appropriate native context.

Only validated literal and named-reference nodes are accepted. Swift string interpolation is escaped, integer bounds are checked, reference and parameter types must match, and iOS introduction/obsoletion/unavailability are checked. Optional primitive literals are supported. Native references remain native values: constructing those values and declaring their lifetime belongs to generated/user-owned Swift code. This is an explicit native API escape hatch, not the shared business-logic language.

## Supported shapes and limits

The adapter supports scalar and named nominal types, nested optional values, structured collections and tuples, supported existential and callback-reference types, receiver calls, static calls and properties. Unsupported symbols remain searchable with explicit reasons. Generic constraints, opaque results, arbitrary callback-body authoring, unsupported ownership modifiers, operators and advanced specialization still require additional lowering and are rejected. Inherited receiver coercions are not inferred. Framework entitlements, application lifecycle, actor context, permissions, linked capabilities and semantic equivalence are not automatically synthesized from SDK signatures.

An **emittable signature** means the adapter supports its syntactic shape. It is not a promise that an arbitrary call is semantically valid in every native context. Apple compilation remains required. **Native tested** counts refer only to explicit invocations that passed the verification harness; untested entries are not relabeled as tested. Raw symbol inventory is not component coverage.

## SDK-wide ingestion

```sh
python3 tools/sweep_ios_sdk.py --output work/sdk-coverage/ios --jobs 2
```

The sweep discovers installed simulator SDK public frameworks, Swift modules, and top-level SDK C module declarations. Underscore implementation modules are recorded as exclusions. C++ modulemap entries are retained in a separate `cxx-module` inventory category with an explicit requirement for a C++ adapter; they are not passed to the Swift symbol extractor. This discovery covers the installed SDK, not private APIs or packages absent from it. Unsupported simulator modules, extractor failures and timeouts remain visible per module; they never silently count as successes.

Each module gets a checkpoint `status.json`, normalized `records.jsonl`, and an extraction log. `inventory.json`, `coverage.json`, and `provenance.json` record discovery, failures, totals, target triple, SDK path/version, Xcode/Swift versions and adapter hash. Resuming skips successful modules; `--retry-failures` retries failures. A changed SDK/toolchain/adapter requires a new output directory. `--modules Foundation UIKit` runs a subset and leaves other modules visibly pending.

Raw graphs are temporary and removed after successful normalization to limit disk usage; `--keep-graphs` retains them. `--min-free-mb` stops new extraction below a disk threshold. `--timeout` bounds each module and `--jobs` bounds concurrency. Optional `--reuse Foundation=PATH` consumes existing graphs without copying but explicitly records that their original extraction provenance is unverified. Records remain available for failed native conformance cases; SDK ingestion does not imply native certification.

## Native verification

```sh
python3 -m unittest discover -s tests -p test_ios_api.py -v
python3 tools/verify_ios_api.py \
  --symbolgraphs work/sdk-inventory/foundation \
  --uikit-symbolgraphs work/sdk-inventory/uikit \
  --output work/ios-api-verification.json
```

The verification harness resolves actual SDK IDs and passes generated Swift directly to Apple's iOS simulator Swift compiler. Foundation cases cover constructors, failable constructors, methods and properties. UIKit cases cover main-actor context, a typed native enum argument, static properties, methods and writable properties. Its report includes the exact tested IDs and emitted source. It typechecks native integration; it does not claim runtime UI behavior tests or certification of every emittable SDK member.

For broad native conformance, `tools/verify_ios_api_batch.py --module Foundation=PATH --module UIKit=PATH --limit 0 --output work/native-conformance.json` generates typed function contexts for every supported signature shape and compiles batches. Function parameters supply native values of the declared types; they do not fake implementations. Exact compiler-rejected IDs and diagnostics remain in the report. Survivors are recompiled successfully before being marked passed. Mutating calls use explicit mutable receiver bindings; optional Objective-C protocol methods use native optional invocation. Obsolete Swift aliases are rejected using SDK metadata.

The verifier's `export_records(module_paths, report_path, output)` helper writes refreshed JSONL catalogs annotated with target-specific native conformance. Compiler-rejected and target-skipped entries are explicitly non-emittable in this export with diagnostics attached. A successful typecheck establishes native syntax/type integration under that target and calling context, not behavioral correctness, entitlement coverage or cross-platform semantic equivalence. `SDKCatalog.from_records` reloads normalized descriptors without needing large raw graphs.

## Searchable catalog integration

`tools/import_ios_catalog.py --database PATH --sweep SWEEP --certified CERTIFIED --report REPORT` imports successful sweep records first, then replaces certified modules with corrected descriptors and records exact per-symbol compilation evidence through `Catalog`. Use `--skip-sweep` to apply another certified module set without overwriting existing evidence. Foundation, UIKit and SwiftUI conformance reports are separate artifacts. Their rejected/skipped entries remain non-emittable in the target-certified catalog.

`NativeAPI(database).emit(request)` consumes the same normalized records used by CLI/MCP search. Its iOS request supports typed arguments, native receiver bindings, target iOS version, async/throws context and property assignment via `set`. Smoke verification resolves IDs from the SQLite catalog and compiles their emitted Swift with Apple's compiler.

## Native audit revision

The final emitter audit tightened overload selection: literal arguments and call results carry explicit Swift type context, so selecting an SDK identity cannot silently select an `Int` overload instead of `Double`, or a different return-only overload. A native executable regression checks both cases. Normalized records now validate field types, path/label consistency, availability, conflicting identities, and explicit rejection flags. Invalid Unicode scalars and overflowing/nonfinite floating literals are rejected.

The full Foundation/UIKit/SwiftUI verification was repeated after this change. It certified **13,682** invocations: Foundation **6,352**, UIKit **6,545**, SwiftUI **785**. Compared with the prior **13,717** receipt, **37** optional Objective-C property descriptors were removed because their optional result semantics were not represented, while **2** previously rejected invocations gained correct overload context. Those properties remain explicitly unsupported; counts were not increased by weakening type checks. There were **372** native compiler rejections and **1,086** target skips. The authoritative final report is `ios-api-audit-verification.json`, and the final certified descriptors are in `ios-audit-certified`.

## Swift language mode

`verify-ios --swift-version 6` opts into Swift 6 language checking. The default
is explicitly Swift 5 mode for compatibility with existing generated projects.
Both the actual compiler command and saved evidence record the selected mode;
the Swift compiler executable version is recorded separately. A successful
Swift 5 run is not evidence of Swift 6 concurrency compatibility. Use a separate
catalog when retaining results for more than one language/target configuration,
since verification replaces the named module scope.

## Mutable native parameters

SDK `inout` parameters are stored separately from their underlying type and emit
native `&` arguments. They require an explicitly mutable reference, with exact
structural type matching. Literals, immutable references and repeated borrowing
of the same input in one call are rejected. The caller owns the mutable storage;
this does not introduce a copy-back bridge or change shared-operation input
semantics. Full Swift exclusivity checking still occurs during native compilation.

SDK sweep normalization uses the same owner/actor-aware catalog passes as native
verification. Sweep provenance fingerprints the extractor as well as the API
adapter; changed tooling requires a fresh output directory. Normalized records
still carry zero native-test credit until actual verification runs.

## Additional native import context

Use repeated `--import MODULE` options when an SDK signature or cross-import
overlay requires another platform module, for example `--module AVFoundation
--import CoreImage`. Verification records the context, and exported descriptors
carry `requiredImports`. SDK call emission includes those imports automatically.
Names are validated module identifiers, not arbitrary source. Imports can affect
name resolution, so verification must use the same context as generated code.
The tool does not guess or automatically install third-party dependencies.


## Failable constructor execution checks

`tools/verify_ios_failable.py` accepts `--catalog`, an explicit `--simulator`,
and a fresh `--report`. It resolves Foundation UUID(uuidString:) and uuidString
from the SDK catalog, emits a typed sequence with an authored unwrap guard,
compiles native Swift 6 for the iOS simulator and executes it there. Two valid
and three invalid UUID inputs check success, error details and preservation of
the previously assigned value when construction fails. The temporary fixture
is not installed or used to drive the product UI.

The report retains requests, emissions, generated source, native binary hash,
SDK/compiler details and a run-specific completion marker. These checks cover
the specified Foundation API, not every failable constructor, optional protocol
property or complete application error flow.


## Optional Objective-C protocol properties

Instance property reads marked optional in the SDK declaration retain the
requirement's optional layer. If the declared property is already String?,
the result is String??: outer nil means the requirement is unimplemented;
.some(nil) means it is implemented and returns nil. The compiler preserves
this distinction through catalog records and typed native sequence bindings.
Each authored unwrap removes exactly one layer and can use a distinct failure
message. Optional<T>, Swift.Optional<T> and suffix spellings normalize to the
same bounded type representation.

Optional protocol property assignment remains unsupported, even when the SDK
declares a setter. Optional static properties also remain unsupported. These
restrictions do not block supported instance reads. Re-extract existing SDK
catalogs to obtain the optional-property metadata; old normalized records may
lack the declaration's optional requirement information.

Native tests distinguish all three states through an Objective-C-compatible
protocol fixture. A freshly extracted MapKit MKAnnotation.title declaration was
also tested on the iOS simulator with an unimplemented title, MKPointAnnotation's
nil title and a populated title. This does not certify every protocol or
application lifecycle interaction.


Native batch verification checks the declared result type as well as the call
expression, including property reads. A regression intentionally labels a real
Double property as String and verifies that native compilation rejects it.
Protocol initializers without a concrete conforming owner are rejected during
normalization and imported-record validation. Additional framework imports used
for verification are retained in exported descriptors; they are real native
source dependencies, not compiler runtime dependencies.


Optional Objective-C methods follow native Swift optional-call chaining. When
an optional method itself returns String?, invoking it with `?()` yields String?,
so a missing implementation and an implemented nil result both yield nil.
This differs from optional property access, which can yield String??. Native
regressions cover both behaviors; the compiler does not impose a common
flattening rule on them.


Optional-call result types are constructed structurally. In particular an
optional method returning `any Protocol` yields `(any Protocol)?`, not the
invalid `any Protocol?` spelling. A native Objective-C-compatible protocol
regression verifies absence and a returned object, and the UIKit batch verifies
the real interruptibleAnimator delegate signature.

## Concrete value-type Self and overlay imports

For indexed nongeneric structs and enums, the importer resolves exact `Self`
type leaves to the nominal owner before producing normalized descriptors. This
applies recursively to collection and callback types, preserving optionality,
callback effects and native mutability. The resulting descriptors work through
the same JSON and evaluated Dart NativeAPI operation interfaces. Class and
protocol `Self`, generic owners, dependent members such as `Self.Element`, opaque
results and `rethrows` remain unsupported. Raw normalized records containing
unresolved `Self` cannot be re-enabled by clearing their rejection metadata.

Some SDK extension graphs declare required companion modules in
`module.bystanders`. The streaming importer retains these validated module names
as imports only for descriptors originating in that graph. For example, MapKit
SwiftUI overlay declarations require `SwiftUI` in their emitted native context.
Graphs without this metadata retain their existing behavior; malformed module
metadata and unsafe import names fail validation. These imports are native SDK
modules, not a dcflight execution layer. Changes to either signature lowering or
imports require fresh native verification before replacing catalog evidence.

## Conditional operation and actor-context proof

`dcflight sdk verify-ios-invocations GRAPHS --module AVFoundation --id PRECISE_ID
--context main --context nonisolated --report fresh.json --records fresh.jsonl`
performs opt-in Swift6/iOS18 simulator proof for 1–128 explicit SDK IDs. Use
`--ios-version major.minor`, `--import MODULE` and `--type-module MODULE=GRAPHS`
when needed. It does not write a catalog or replace the ordinary broad verifier.
Every property read and declared setter is probed separately in each requested
context; methods and constructors use call probes. Rejected invocations remain
in the report and produce a nonzero exit status. No generated native code is
executed by this command.

The optional JSONL contains only the selected conditional descriptors. Each
remains `emittable: false`; there is no whole-symbol compiled-ID promotion. A
local caller may import these into a separate catalog/scope using `Catalog`,
then use existing NativeAPI `set`, `actorContext` and `iosVersion` fields. Keep
existing broad catalog scopes intact; when IDs exist in multiple scopes, select
the intended scope explicitly. Successful conditional invocations are counted
separately from generally supported symbols. Generic-owner specialization and
other unsupported declaration shapes remain on their existing paths; this
bounded verifier rejects them instead of inferring generic instantiations.

NativeAPI verifies the embedded report digest, current dcflight/compiler and
Apple SDK identities, and the hashes of actual graph inputs. It regenerates
descriptors and probe source from those inputs, rejects contradictory/missing
evidence, then recompiles the exact selected operation/context before first
use. A forged passed flag cannot replace native compilation. Source and SDK
identities are checked again afterward; later cache use rechecks current inputs.
Conditional reports therefore require the original SDK graphs and installed
Apple compiler when authoring. These local checks are not signed attestation.

A setter pass never grants a getter pass. A nonisolated async pass never grants
a MainActor or unknown-context pass. The existing Dart `NativeExecution.worker`
selects explicit nonisolated context and emits a nonisolated native method;
`NativeExecution.main` selects main. Inherited `caller` context remains unknown
and cannot consume conditional proof. Shared worker operations must construct
and use non-Sendable native objects within their native implementation; portable
scalar arguments do not transfer UI-owned AVFoundation objects. Native Swift6
checks still apply to the complete generated application.

All proof handling is development-time only. Generated output remains ordinary
Swift SDK calls, with no report reader, registry, bridge or dcflight runtime.
