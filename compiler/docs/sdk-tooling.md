# Using the native SDK catalog

The SDK catalog lets an AI or developer find actual platform APIs, inspect their contracts and verification evidence, and produce ordinary native expressions from typed inputs. It runs on the development computer. Generated apps do not load this database or contact an MCP server.

The semantic registry and SDK catalog serve different purposes. `registry` describes reviewed shared UI capabilities. `sdk` describes platform-native APIs. An emitted camera call is not a complete shared camera feature: the app still needs permission handling, lifecycle ownership, threading, error behavior and native integration. Shared application logic remains the responsibility of the DC Dart compiler path; platform-call emission does not replace that language.

## Inspect an existing catalog

Use your installed `dcflight` command, or `python3 -m dcflight` from the compiler repository.

```sh
dcflight sdk coverage --catalog /path/to/dcflight-sdk.sqlite

dcflight sdk search 'android.widget.TextView setText' \
  --platform android --supported --limit 10 \
  --catalog /path/to/dcflight-sdk.sqlite

dcflight sdk get 'android.widget.TextView#setText(java.lang.CharSequence)' \
  --platform android --catalog /path/to/dcflight-sdk.sqlite

dcflight sdk search Button --platform ios --scope UIKit --limit 10 \
  --catalog /path/to/dcflight-sdk.sqlite
```

Search is bounded and returns `nextOffset` when more results exist. Repeat with `--offset` to continue. Select an exact returned identity before emission; overloads have different identities. `sdk get` returns the descriptor and independent evidence, including unsupported reasons. `--supported` means the emitter accepts the signature shape, not that it has been executed on a device.

## Emit a native Android call

Save this as `invocation.json`:

```json
{
  "platform": "android",
  "id": "android.widget.TextView#setText(java.lang.CharSequence)",
  "receiver": {"ref": "button", "type": "android.widget.Button"},
  "arguments": [{"literal": "Continue"}]
}
```

Then run:

```sh
dcflight sdk emit invocation.json --catalog /path/to/dcflight-sdk.sqlite
```

The result contains:

```java
((android.widget.TextView) button).setText((java.lang.CharSequence) ("Continue"))
```

The returned object states the source language, result type, imports and `runtimeDependency: null`. It does not execute the API or write a file. The caller places the expression inside a suitable native context where `button` is declared, then uses the normal native compiler. Typed references are assertions about that context; final symbol binding is checked by the native compiler.

Android inputs are `{"literal": value}`, `{"ref": "name", "type": "qualified.Type"}` or `{"null": "qualified.Type"}`. Raw source snippets are rejected. Constructors and static calls omit `receiver`. Native fields can be read through their exact catalog identities. Arrays and concrete parameterized types remain native types; unsupported generic variables are rejected rather than erased.

Android writable fields also accept a `set` value through the same CLI/MCP invocation:

```json
{
  "platform": "android",
  "id": "android.graphics.Rect#left",
  "receiver": {"ref": "bounds", "type": "android.graphics.Rect"},
  "set": {"literal": 24}
}
```

This emits `((android.graphics.Rect) bounds).left = (int) (24)`. Assignments reject final fields, enum constants, methods, wrong receiver/value types, null for nonnull fields, raw source and accompanying arguments. Static writable fields omit the receiver. Fresh Android catalog records include `writable`; existing catalogs still emit writes by checking their verified SDK snapshot, and can be reindexed to refresh discovery metadata. Reindexing intentionally invalidates old evidence.

`tools/verify_android_field_writes.py` compiles every supported writable field against a supplied Android JAR. Its report names the **fieldWrite** operation and exact identities separately from field-read/call evidence. On the Android 35 snapshot used here, all 748 supported writable field assignments compiled. The Java fixture execution test verifies actual assignment semantics; the SDK sweep does not execute Android behavior.

For iOS, retrieve an exact descriptor first. Its identity, parameter labels, types, availability and async/throwing requirements determine the invocation. The native emitter accepts `iosVersion`, `allowAsync` and `allowThrows` where applicable; passing those fields to Android is rejected.

## Connect an AI client using MCP

Start the stdio server with the catalog:

```sh
dcflight mcp --catalog /path/to/dcflight-sdk.sqlite
```

An MCP client can register the executable and arguments, for example:

```json
{
  "mcpServers": {
    "dcflight": {
      "command": "dcflight",
      "args": ["mcp", "--catalog", "/path/to/dcflight-sdk.sqlite"]
    }
  }
}
```

Client configuration formats differ; the command and arguments are the important parts. Available tools include:

| Tool | Purpose |
| --- | --- |
| `registry_search` | Find reviewed shared semantic capabilities |
| `app_schema` | Inspect the JSON application authoring schema |
| `validate_app` | Validate an application without executing it |
| `sdk_search` | Search signatures with pagination and optional platform/scope filters |
| `sdk_get` | Inspect one exact signature and its evidence |
| `sdk_coverage` | Read current coverage by platform and SDK scope |
| `sdk_emit` | Produce a native expression from a typed invocation |

For `sdk_emit`, the tool arguments are `{"invocation": {...}}`, containing the same invocation object used by the CLI. For `sdk_search`, use `emittable_only: true` rather than the CLI's `--supported` spelling. These tools do not install apps, grant permissions or execute OS capabilities.

## Build or update a catalog

```sh
dcflight sdk index-android /path/to/android-35.txt --sdk 35 \
  --catalog /path/to/dcflight-sdk.sqlite

dcflight sdk index-ios /path/to/ios-sdk-sweep \
  --catalog /path/to/dcflight-sdk.sqlite
```

Indexing does not confer verification. Reimporting a scope invalidates its old evidence intentionally. For Android, import a successful exhaustive conformance report using:

```sh
python3 tools/import_android_catalog.py \
  --source /path/to/android-35.txt \
  --report /path/to/android-api-conformance-all.json \
  --catalog /path/to/dcflight-sdk.sqlite
```

The helper checks the source hash, report status and exact tested identities before associating compile evidence. Preserve source snapshots and verification artifacts with the catalog. SDK extraction and native tests must be repeated when an SDK changes.

## Interpret coverage precisely

| Level | What it establishes |
| --- | --- |
| Indexed | A signature was imported from an SDK description |
| Emittable | The structured emitter accepts its native signature shape |
| Compiled | That exact identity appeared in a successful native compilation fixture |
| Executed | That exact identity appeared in a successful native execution fixture |

These counts are not interchangeable and are not counts of complete application features. Compilation does not verify device behavior, permissions, availability on older releases, accessibility quality, callback ownership or end-to-end workflows. `completePlatformCoverage` remains false until the framework meets the broader product requirement.

## Build the Android app

```sh
dcflight run /path/to/project --platform android --build-only \
  --android-sdk /path/to/android-sdk \
  --java-home /path/to/jdk17 \
  --gradle /path/to/gradle-8.11.1/bin/gradle
```

Remove `--build-only` to install and launch on a connected, authorized device or running emulator. Add `--device SERIAL` when multiple devices are connected. This performs a native rebuild and relaunch. It is not state-preserving hot reload.

## Compose native calls with checked local dataflow

`dcflight sdk emit-sequence sequence.json --catalog sdk.sqlite` (MCP tool `sdk_emit_sequence`, argument `sequence`) emits a straight-line Java or Swift block. Each step uses an exact catalog identity. A `bind` name receives the SDK-declared return type, so later references require only `{"ref":"name"}`. Supplying a replacement type, referencing a later/missing binding, or redefining a binding fails before emission. Final native compilation still checks the supplied context.

```json
{
  "platform": "android",
  "steps": [
    {"id":"android.graphics.Rect#<init>()", "bind":"bounds"},
    {"id":"android.graphics.Rect#left", "receiver":{"ref":"bounds"}, "set":{"literal":24}},
    {"id":"android.graphics.Rect#width()", "receiver":{"ref":"bounds"}, "bind":"width"}
  ]
}
```

The emitter evaluates each step once in order, including unused field reads. Input symbols from the surrounding native context are declared as `inputs: [{"name":"context","type":"android.content.Context"}]`; iOS mutable inputs additionally use `mutable: true`. Local Swift results are mutable native variables to support value-type operations. Inputs retain their existing lifetime; this tool does not acquire or release external resources automatically.

Top-level `iosVersion`, `allowAsync` and `allowThrows` have the same checks as individual iOS calls. They declare requirements on the enclosing native context, not hidden error handling. Per-step overrides and mixed-platform sequences are rejected. The result reports imports, native module dependencies, result bindings and exact API identities. It introduces no compiler runtime dependency.

`inputContracts` reports each supplied input name and native type. On iOS,
`escaping: true` means an input is forwarded directly to a parameter marked
escaping in the imported SDK descriptor; an enclosing Swift function must
preserve that annotation on its callback parameter. Unused inputs and inputs
without that requirement report false. This metadata describes the caller's
declaration obligation, not callback implementation, retention ownership or
cancellation. Old SDK descriptors must be reimported to obtain escaping metadata.

This is a platform-specific escape hatch for composing catalog calls, not a replacement for shared DC Dart application logic. It does not yet connect arbitrary SDK calls to routed application effects, synthesize callbacks/lifecycle policy, or promise one native API exists on every OS. The Java and Swift tests compile and execute representative sequences; this is not device-wide API execution evidence.

## Define one operation contract for both native targets

`dcflight sdk emit-operation operation.json --catalog sdk.sqlite` and MCP `sdk_emit_operation` (argument `operation`) validate a shared scalar signature, then emit a normal Swift enum/static method and Java class/static method. The typed `OperationContract` is independent of either native type spelling.

The input contains `name`, `parameters` (name/type pairs), `result`, optional Boolean `throws`, and exactly two `implementations`: `ios` and `android`. Each implementation contains sequence `steps` and `return: {"ref":"binding"}`; iOS may specify `iosVersion`. Shared types are `string`, `bool` and `int`, mapping to String/Bool/Int32 and java.lang.String/boolean/int. Both results must match the same canonical contract. In particular, Swift Int is not silently narrowed to Int32. Reference results, nullable results, async callbacks and coercions need additional explicit contracts before support.

The compiler reports complete source for each target and its selected API identities/dependencies. The caller integrates the source with its normal native project; this interface does not write project files or install dependencies. A throwing contract emits Swift `throws` and Java `throws Throwable`; it does not catch failures or define a fallback. Thread ownership remains the caller's responsibility. Actor-isolation requirements in SDK descriptors are not yet complete, so native compilation in the actual caller context remains mandatory.

Generated local bindings now use reserved internal names; `bindings[].nativeName` gives the emitted name while `name` remains the authoring identity. This prevents an authored local named UUID from shadowing the Swift UUID constructor. External input names that shadow referenced SDK type/module names are rejected explicitly.

These operations are reviewed native adapters with one shared signature, not app screen templates. Synchronous scalar operations can be declared on a routed App and invoked using NativeOperationEffect; standalone definitions can also use buildOperation(). Asynchronous callbacks and owned native resources still need additional contracts.

## Author operation definitions in Dart

Import `package:dcflight_authoring/dcflight.dart` and expose a `NativeOperation buildOperation()` function. The typed constructors are `NativeOperation`, `NativeParameter`, `NativeImplementation`, `NativeCall`, `NativeRef`, `NativeLiteral` and Android's explicitly typed `NativeNull`. `NativeScalar.string`, `.bool` and `.int` select canonical types. A `NativeImplementation` has `steps` and a `result` reference; an operation requires both `ios` and `android` implementations. NativeCall identities must be exact entries in the selected catalog.

Run `dcflight sdk emit-operation operation.dart --catalog sdk.sqlite --evaluate-dart --dart-sdk /path/to/dart`. The opt-in evaluator invokes only the fixed buildOperation entry point and requires a NativeOperation return value. It uses the same authoring package and compiler validation as JSON. Normal Dart helpers, loops and composition are available at development time. No package downloads happen implicitly. Without `--evaluate-dart`, executable Dart is rejected; MCP continues accepting data only and never invokes the Dart evaluator.

The resulting static native APIs contain no Dart authoring objects, Dart VM or compiler dispatcher. An App can declare these reusable adapters in nativeOperations and call their shared scalar signatures through NativeOperationEffect. JSON remains independently supported and is checked against the same canonical OperationContract. Package verification exercises this path using only the built wheel, without importing the checkout's authoring library.

## Invoke native operations from shared app flows

Version-2 App accepts `nativeOperations` and a development-only `sdkCatalog` path (relative to the source file or absolute). Both implementations are validated before any files are synchronized. App operations must explicitly select `NativeExecution.main` / `execution: "main"`; generic background work, callbacks and suspension are not inferred.

A shared `NativeOperationEffect(operation: 'newIdentifier', target: 'identifier', success: 'accepted', failure: 'rejected')` calls the same declared contract on both targets. Optional `arguments` are shared scalar literals or state references, checked against the contract. The target state's type must match the result, and the effect must end its case. Both continuation flows must exist; synchronous cycles are rejected. Timers cannot invoke native operation effects.

The compiler emits Swift sources under `ios/App/Generated/Operations` and same-package Java files beside the Android app sources. The model calls the static native API directly. Results are validated before state commit: Swift integer arguments are exactly representable as Int32, and returned strings are limited to 8 MiB UTF-8; Android also rejects null and malformed UTF-16. Failure retains the previous target value and follows the authored failure flow. Fatal native/JVM errors are not promised recoverable. Long-running calls block the main thread and require a future asynchronous contract.

Generated operation files use the existing conflict-safe synchronizer; manual changes cannot be silently overwritten. Selected catalog descriptors/provenance are hashed into per-target generation receipts so a one-target SDK change cannot falsely certify that both projects match. Referenced native module dependencies must match declared verified module locks.

`examples/native-operation/app.dart` is a complete shared app example. `tools/prepare_native_operation_app.py` prepares its small catalog from supplied actual Foundation records and exact Android UUID class bytes, avoiding the JDK boot-classpath substitution. It refuses to replace an existing evidence directory. Full iOS and Android builds have passed separately; native helper/model tests prove result/failure behavior, while this build pass does not claim an on-device button journey.

## Index Android core APIs from the platform archive

The framework metalava listing does not include all Java core APIs available to Android applications. Import the installed platform archive with:

```sh
dcflight sdk index-android-core /path/to/platforms/android-35/android.jar --sdk 35 --javap /path/to/jdk/bin/javap --catalog sdk.sqlite
```

This adds the `core-bytecode` scope for java, javax, org.w3c.dom and org.xml.sax. It uses the verified class-file bytes, excludes compiler bridge methods using ACC_BRIDGE metadata, and retains source-level typed methods. The Android SDK JAR is an existing platform dependency; it is not packaged as a third-party module. Its artifact hash, selected namespaces and exact inspection method are recorded. Nullability and introduction-version metadata missing from class listings remain unknown.

On Android 35, this importer inspected 1,473 classes and indexed 17,575 declarations, with 15,723 emittable signatures. All 15,723 calls compiled against Android's actual boot stubs using `tools/verify_android_api.py --android-core --limit 50000`. The evidence importer `tools/import_android_core_evidence.py` checks source/archive hashes and exact identities before recording compiled evidence in core-bytecode; it never labels those calls executed. Compiler-generated bridge filtering can increase usable coverage because covariant source methods no longer appear ambiguous with their synthetic variants.

The compilation harness inspects real class references instead of looking for substrings such as dart inside ordinary names (for example getCalendarType). Select `--scope core-bytecode` where an identity also exists in another catalog scope. Reimporting a scope invalidates its previous evidence, which must then be rebuilt.

Core evidence import additionally requires the tested identities and probe identities to agree exactly, with matching integer counts, clean dependency results, and the recorded compiler command/version. Unknown identities roll back the entire evidence batch; no partial verification remains. The compilation harness first copies the Android archive into its temporary build directory and hashes that copy, so the report identifies the SDK bytes actually passed to javac. Generated probe-source hashes are retained in the report. Reports are local build evidence, not cryptographic attestations from an independent verifier.

## Android typed scalar values

SDK call arguments and field assignments infer primitive literal types from the selected
signature. Dart/JSON authors can pass a signed 64-bit value directly to a `long` parameter,
a byte-range integer to `byte`, or one character to `char`. The emitter validates the
declared range and emits native Java syntax such as the required `L` suffix. Boolean and
integer values remain distinct. Float conversion uses Java narrowing, including underflow
to zero; nonfinite or out-of-range values fail before emission. Scalar values and array
elements use the same validation/lowering implementation.

This does not add implicit boxed-object construction or widen shared App state integers.
Shared integer state and operation contracts remain Int32; these are explicit native SDK
arguments. Existing Python `JavaValue.literal` keeps its inferred scalar types; callers
that know the SDK primitive type can use `JavaValue.typed_literal(value, type)`.

The Android value harness below now executes 20 reviewed cases: nine arrays and eleven
scalar cases, including both signed long boundaries, byte/short limits and char values.

## Android array values

Android SDK calls and writable-field assignments accept `{"literal": [1, 2, 3]}`
when the selected signature declares an array. The compiler infers the exact native
array type from that declaration and emits `new int[] {1, 2, 3}`. Dart authors use
`const NativeLiteral([1, 2, 3])`; both forms reach the same checked native emitter.

Supported literal elements include Java primitives and strings, with nested arrays
and null reference/array elements. Integer bounds follow the declared byte/short/int/long
type, booleans cannot stand in for integers, and char values must fit one nonsurrogate
UTF-16 code unit. Floating values must be finite and within the target range; float
conversion follows Java narrowing, including underflow to zero. Array literals have
4096-value and 16-level limits. Generic array creation, boxed/object construction and
List/Map literals are not implicitly synthesized. Typed native references remain the
way to pass existing values of other supported types.

The output contains ordinary native Java arrays and introduces no dcflight allocation
helper, interpreter or bridge. These are platform SDK arguments, not a change to shared
App state collection semantics.

Run `python3 tools/verify_android_array_calls.py --catalog SDK.sqlite --sdk ANDROID_SDK
--java-home JAVA_HOME --serial SERIAL --report REPORT.json` to compile reviewed array
cases against the selected Android boot stubs, convert the fixture to DEX, and execute
it directly on Android ART. The default SDK/build-tools versions are 35 and 35.0.0.
The selected device must report the matching SDK level. This harness executes only its
explicit reviewed cases; it does not execute arbitrary SDK inventories.

The report includes expected results, emitted calls, actual device fingerprint,
compiler invocation/version and SDK/source/DEX hashes. Every assertion must pass and
the current run's unique completion marker must return before a success report is
written. A temporary payload under `/data/local/tmp` is removed after success or
failure. This verifies Android runtime calls without installing or driving an app;
UI, lifecycle and physical-device acceptance remain separate requirements.
Use a new report path for each run; existing evidence is never reused or overwritten.

## Swift collection values

SDK signatures can now contain nested array and dictionary types, optional elements,
and concrete generic type references. A bounded parser handles the type structure;
closures, existential/ownership syntax and constrained generic specialization
remain unsupported. `[String]`, `Array<String>` and `Swift.Array<String>` represent the
same collection reference type. Optional elements and optional collections remain distinct.

The existing `{"literal": value}` input accepts JSON arrays and objects when the SDK
parameter declares a compatible collection. Elements and dictionary keys/values are
validated recursively against the signature. JSON object keys are strings; they are not
silently converted into numeric or enum keys. Empty dictionaries emit `[:]`. Literal
trees are limited to 4096 values and type nesting to 16. Other concrete generic types
can be passed by typed reference, without guessing constructors or embedding source.

Dart authors use the same data through `const NativeLiteral({'numbers': [1, null, 3]})`.
The Dart authoring package checks finite JSON values and size/depth limits; the compiler
then checks each value against the selected native signature. This does not make
collections valid for an Android API whose parameter has a different type.

This support is SDK-call lowering, not new shared App collection/state semantics. The
output uses Swift's native collection types and introduces no dcflight runtime. Existing
catalogs require reimport before previously rejected signatures gain the new support;
their old evidence is not automatically promoted to native execution evidence.

## Swift tuple results

Native sequences support named and unnamed tuple result types, including nested
collection/optional elements. Use `{"project":{"ref":"pair","index":0},"bind":"data"}`
to select an element from a previously bound, nonoptional tuple. The compiler infers
the element type, checks the index and emits an ordinary Swift local assignment.
Tuple values are not serialized into an application runtime. Selections do not create
extra SDK calls or repeat the original operation.

Dart authors use `NativeTupleElement(NativeRef('pair'), index: 0, bind: 'data')`
inside a `NativeImplementation`. The existing NativeCall remains available alongside
it through the NativeStep interface. Selecting an optional tuple, forward reference,
invalid index or Android tuple is rejected. Tuple
literals, closures and shared App tuple state are not introduced.

For SDK sequences, async/throwing calls still require explicit allowAsync/allowThrows
and an appropriate native caller. Actual URLSession.data(for:) data/response selection
passes iOS SDK typechecking and host-native local HTTP execution. Shared App operations
remain synchronous; this does not claim cancellation, callback or async lifecycle support.

The integration regression also checks tuple projection inside a synchronous shared
operation: Dart and JSON emit identical operations, routed App generation preserves
the projection and SDK provenance, and both native implementations execute matching
normal/boundary results. The arithmetic fixture verifies the adapter machinery; it
does not move application business logic out of the shared DC Dart source. Generated
app-flow source is checked separately from execution of the operation methods.

## Checked native optional and null results

Use `{"unwrap":{"ref":"candidate"},"bind":"url","message":"Invalid URL"}`
after a call that returns an optional value. Dart exposes the same step as
`NativeUnwrap(NativeRef('candidate'), bind: 'url', message: 'Invalid URL')`.
The compiler infers the nonoptional result and emits `guard var … else { throw … }`.
It evaluates no additional SDK call and never force-unwraps a missing value.

An explicit throws context is required (`allowThrows: true` for SDK sequences,
`throwsErrors: true` for Dart shared operations). A missing value throws an ordinary
Foundation NSError with domain NativeValue, code 1 and the authored description.
Messages are escaped as data, not source. Optional tuples may be unwrapped first and
then projected. Nonoptional inputs, missing references and invalid contexts fail at
generation time. This adds no runtime dispatcher and does not add shared optional state,
whole-program nullability analysis or general branching to native sequences.

On Android, the same unwrap step accepts a reference type and emits a new final local
followed by a null check. Null throws `java.lang.IllegalStateException` with the authored
message; a present reference continues unchanged. Primitive inputs are rejected. SDK
sequences require `allowThrows: true`, and shared operations require `throwsErrors: true`
for either platform. Android's allowThrows sequence flag describes the caller's failure
contract; it is not passed to the lower-level SDK call emitter as an iOS option.

An Android ART fixture verifies both present and absent results from the actual
System.getProperty SDK call, including the authored failure message and cleanup of the
temporary payload. This does not certify unrelated nullable SDK calls, app lifecycle
or touchscreen behavior.

The shared-flow integration regression compiles the emitted operation and emitted
effect handler together on Swift and Kotlin/JVM. A normal result commits once;
invalid and overflowing native input invokes the failure continuation while retaining
the previous state. This verifies real generated operation code rather than a stand-in
operation implementation. The fixture checks adapter behavior, not a replacement for
shared DC Dart business logic or full app/device acceptance.

## iOS actor context

New iOS symbolgraph imports record `actorIsolation` as `main`, `nonisolated`, `unknown` or `global:Module.ActorName`. MainActor attributes on a member or its known nominal owner are preserved; an explicit nonisolated member overrides inherited actor isolation. A known main-actor API requires `actorContext: "main"` in sdk_emit or the enclosing sdk_emit_sequence. Allowing async/throws does not implicitly authorize a cross-actor call or insert an actor hop.

Custom global actors are resolved through attribute fragment precise identifiers against `@globalActor` declarations supplied in the imported symbolgraphs. Calls require the exact qualified context, for example `actorContext: "global:Storage.DatabaseActor"`; another module's identically named actor is not equivalent. The caller must actually execute on that actor, which remains subject to the native Swift compiler's checks. The emitter adds no actor dispatcher or synchronization layer. Explicit nonisolated members remain callable without that context. An unavailable actor declaration remains unknown; this does not certify it as safe. Instance actors, external actor resolution and cross-actor asynchronous lowering are still separate work. Shared App operations currently execute on the main actor and therefore reject custom-global-actor calls that would require a hop.

Shared operations declared with `execution: "main"` pass the main actor context through and emit @MainActor native Swift APIs. A generic caller operation cannot silently use a known main-actor API. Explicit nonisolated calls retain their ordinary native behavior.

Older records lacking metadata remain unknown; existing catalog evidence is not silently re-certified. External global actors without imported declarations, actor instances and complete inherited/extension isolation require further metadata support. Unknown isolation still requires native compilation in the actual caller context. Verification includes a real generated Swift symbolgraph plus Swift 6 acceptance/rejection tests, and the actual UIKit UIView(frame:) declaration typechecked against the iOS simulator SDK. Typechecking is not device execution.
## Android native value execution checks

Typed primitive references may use Java widening conversions, such as `int` to
`long`, `char` to `int` or `float` to `double`. The emitted argument retains the
requested SDK parameter type so overloaded calls select the intended signature.
Narrowing and boxing are not inferred. Primitive arrays remain invariant: this
does not permit `int[]` to be passed as `long[]`. Java widening to floating-point
types follows Java's normal precision behavior; it does not promise exactness.

Use `{"array": [[1, 2], null], "type": "int[][]"}` when the argument needs a
concrete array type different from the SDK parameter type. In Dart this is
`NativeArray([[1, 2], null], type: 'int[][]')`. The Android emitter validates both
the array contents and Java assignability; for example, `int[][]` can be passed
to `Object[]`, while `int[]` cannot. It emits native array construction directly.
This is an Android escape-hatch value, not a shared collection conversion.

```sh
dcflight sdk test-android-values --catalog sdk.sqlite --sdk /path/to/android-sdk \
  --java-home /path/to/jdk --serial emulator-5580 --report android-values.json
```

This command runs the reviewed scalar/array cases through emitted Java and Android
ART. It requires the indexed `core-bytecode` and Android `framework` scopes, an explicit device serial,
matching SDK/device API levels (35 by default) and a fresh report path. It removes
its temporary device payload after execution. The report records source/DEX/SDK
hashes and device identity. These cases test native value emission, not every
Android API, app lifecycle or visual behavior. No installed app is modified.

The reviewed Android cases also include a generated RectF construction, field
assignment and readback sequence. Its integer-to-float boundary follows native
Java precision semantics. Sequence cases run in separate local scopes to preserve
generated local-name isolation.
