# One DC Dart logic source, native machine code

DCFlight compiles DC Dart business logic once per target, from the **same source**,
using DC Dart 0.1.1 or newer. It does not translate business logic into Swift and
Kotlin or evaluate JSON actions as a substitute for that code.

`dcflight.dcdart.compile_logic` emits a native `logic.o`, a compiler-derived C ABI
`logic.h`, and a development-only `logic.build.json` recording source/prelude,
compiler and object hashes, compiler version, target, native toolchain version
and symbol audit results. Pass explicit source, prelude, output and target paths.
A failed compilation or symbol audit leaves previous compiled output intact.

Targets are `ios-arm64` (iOS16), `ios-simulator-arm64` (Simulator16),
`android-arm64` (Android API26) and `host`. These are distinct target triples;
macOS or GNU/Linux objects are never relabeled as mobile objects. iOS links the
object into its normal native project and imports its C header. Android links
it into an ordinary NDK shared library; Kotlin calls exported native methods
through generated JNI ABI glue. JNI here is Android's native-code interop,
not a JavaScript bridge, interpreter or DCFlight runtime. UIKit/Android UI code
still calls platform APIs directly.

The example exports `increment`, `discountedTotal` and `greatestCommonDivisor`.
The same branches, arithmetic and loop execute on each CPU. Sized integers have
DC Dart's checked arithmetic behavior; overflows may trap. Callers must validate
ranges or use deliberate language operations rather than assume wrapping.

## Run and verify

Install the released DC Dart compiler and its pinned development SDK. DC Dart's
current frontend requires Dart SDK 3.12.2; set `DCDART_DART` to that SDK's `bin/dart`
when your default Dart version differs. This SDK is used during compilation only.
The example imports `prelude.dart`. The harness copies the installed prelude next
to its working source; no prelude or Dart source is shipped in native apps.

```
python3 tools/verify_dcdart.py --dcc /path/to/dcc \
  --prelude /path/to/prelude.dart --nm /path/to/llvm-nm
```

The harness compiles the same source for all four targets, rejects any undefined
symbol, and runs five behavior checks on the host. The upstream DC Dart mobile
conformance harness additionally links iOS device, iOS Simulator and Android
executables and an Android shared library, and can run the behavior checks on a
booted simulator. Cross-compilation/linking alone is not device execution.

## No hidden runtime

The adapter allows `--mode bare` only. It inspects defined as well as undefined
symbols, rejects embedded DC heap/ARC helpers and Dart/Flutter/JS runtime symbols,
and requires an explicit allowlist for external native C functions. Allowlisting
a prohibited runtime symbol does not bypass the audit. These object checks
complement final project/binary audits; they do not prove arbitrary external
libraries have no runtime of their own.

The currently supported runtime-free subset covers low-level typed functions,
control flow, sized arithmetic and explicit native ABI interactions. DC Dart's
full hosted language, unrestricted packages, asynchronous object-heavy app logic
and every platform's object ownership semantics are not implemented by this
adapter. Unsupported language features fail at compilation. `bare` by itself is
not sufficient evidence: upstream DC Dart also has embedded allocation features,
which DCFlight's stricter symbol audit intentionally rejects.

## Application integration

A manifest can reference user-owned business logic and declare the native ABI it
expects. Paths resolve relative to the manifest. DCFlight checks these signatures
against DCC's emitted C header; it never trusts a handwritten ABI declaration.

```json
"logic": {
  "source": "logic.dart",
  "prelude": "prelude.dart",
  "functions": [
    {"name": "increment", "parameters": ["uint32"], "returns": "uint32"}
  ]
},
"actions": [
  {"id": "add", "op": "call", "function": "increment",
   "args": [{"ref": "count"}], "target": "count"}
]
```

The Dart authoring equivalent uses `Logic`, `LogicFunction` and
`Action(op: 'call', function: ..., args: ...)`. UI authoring stays declarative;
the referenced `logic.dart` is compiled DC Dart, with real functions and loops.
The canonical IR has typed logic functions, ABI scalar types and CALL actions.
Current end-to-end native tests exercise unsigned32 functions. Other declared
ABI shapes must actually be produced by DCC or generation fails.

Set `DCFLIGHT_DCC` to the released compiler, `DCDART_DART` to Dart SDK3.12.2,
and `DCFLIGHT_ANDROID_CLANG` to NDK `aarch64-linux-android26-clang`.
`DCFLIGHT_NM` and `DCFLIGHT_READELF` can select LLVM inspection tools.
Generation finishes compilation/linking before synchronization. The generated
projects have no DCC, Python, Dart or DCFlight build hooks.

The sample `examples/shared_logic/app.json` calls increment, a discount function
with branching, and GCD with a loop. Copy your installed `prelude.dart` beside it.
The two platform projects then contain:

- iOS: separate device/simulator object files, C header, ordinary Swift calls,
  and a generated xcconfig referenced by the user-owned Xcode project.
- Android: audited `libapplogic.so`, generated Java native declarations, and
  ordinary JNI source retained in `native-source/` for inspection. The library
  is built during generation; Gradle simply packages it.

Portable app state remains signed Int32. Passing negative state to a uint32
function is rejected. A uint32 result exceeding Int32.max is rejected before
assignment. Swift uses preconditions; Android throws IllegalArgumentException.
Neither silently reinterprets sign bits. DC Dart arithmetic overflow can also
trap inside the native function. The current API deliberately does not claim
recoverable error equivalence between platform exception mechanisms.

Generated binaries participate in conflict detection and atomic file writes.
Unchanged generation is a no-op; one-platform generation preserves the other
platform's library hashes and compiler evidence. Existing user-owned Xcode
projects created before logic support must add the generated xcconfig or be
regenerated into a new folder; the compiler reports this explicitly.

Run `tools/verify_shared_app.py --help` for the detached integration harness.
It builds both native projects concurrently, compares the APK's application
library byte-for-byte against the audited generation hash, verifies iOS dynamic
dependencies, and optionally executes the generated Swift AppModel and shared
logic inside iOS Simulator. Android device execution remains a separate check.

### Allocation scope

Zero VM does **not** require allocation-free code. C++ destructors, Swift ARC and
native allocation routines can be ordinary compiled language support. The current
DCFlight audit conservatively rejects DC Dart's embedded heap/ARC helpers because
that ownership/allocator subsystem has not been reviewed for this application's
native interoperability and lifecycle requirements. This is a narrower audited
subset, not a claim that every allocator constitutes an engine or framework.
Expanding it requires a concrete ownership contract and native conformance tests;
it does not inherently require introducing a VM or UI framework runtime.
