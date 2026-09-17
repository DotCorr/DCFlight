# dcflight compiler

Development-time application authoring, native source synchronization, SDK API discovery and AI tooling. Generated applications ship **zero dcflight runtime, Dart VM, added JavaScript engine, registry interpreter or renderer**.

## Install (macOS, Windows, Linux)

One pure-Python wheel serves every OS. Installers bootstrap it into a user location without touching system packages:

```sh
# macOS / Linux
curl -fsSL https://github.com/DotCorr/DCFlight/releases/latest/download/install.sh | sh
```

```powershell
# Windows (PowerShell)
irm https://github.com/DotCorr/DCFlight/releases/latest/download/install.ps1 | iex
```

Then let the doctor check your native toolchains — it detects Xcode, Android SDK/JDK, Gradle, adb, Dart and dcdart, tells you what to install and why, and can install the dev toolchains itself:

```sh
dcflight doctor                # status + install hints
dcflight doctor --install      # opt-in: install Dart SDK / dcdart / Android commandline tools
dcflight doctor --tool dart    # install only one tool
```

Python 3.9+ is the only prerequisite the installers do not provide. Xcode (macOS) and Android Studio (Windows/macOS) remain user installs for native platform builds — the doctor links them and verifies them once present.

## Use with coding agents (MCP)

```sh
dcflight mcp-config --client claude    # or: vscode, cursor, generic
```

Paste the printed block into your MCP client's config. The server (`dcflight-mcp`) exposes:

- `compile_app` — compile a trusted local Dart `buildApp()` file into native iOS + Android projects
- `registry_search`, `app_schema`, `validate_app` — semantic capabilities, authoring schema, canonical IR
- `sdk_search` / `sdk_get` / `sdk_coverage` / `sdk_emit` — exact native SDK signatures with verification evidence
- `doctor` / `doctor_install` / `mcp_config` — toolchain status and self-description

Point it at an SDK catalog with `DCFLIGHT_SDK_CATALOG=/path/to/sdk.sqlite` (or `dcflight mcp --catalog …`).

The native projects are the product. Shared routed applications use ordinary Swift/SwiftUI and Xcode on iOS, and Kotlin/Jetpack Compose and Gradle on Android. The original version-1 document format also supports Java/framework Views. Shared business decisions are written in **DC Dart**, compiled ahead of time to native objects, and connected with ordinary C ABI/JNI application glue. The dcflight tooling stays on the developer computer.

## Shared-source Snap

`examples/snap/shared/app.dart` is the active shared application definition: screens, copy, styling, navigation, typed state, requests and effects. `logic.dart` owns its compiled client decisions. The two native generators translate those declarations; they do not contain separate Snap screens. The complete Snap example (apps, server contract, QA harnesses) lives in `examples/snap/`.

```sh
./bin/dcflight compile examples/snap/shared/app.dart --out /absolute/path/snap-native --evaluate-dart --dart-sdk /path/to/dart
```

The native projects build independently after generation. See [shared effects](docs/shared-effects-contract.md), [typed collections](docs/shared-collections-contract.md), [native media](docs/shared-media-contract.md) and [camera/maps/location](docs/shared-device-contract.md) for the implemented contracts and limits. Native device adapters are implemented; complete hardware, UI and production acceptance remain unfinished. Successful compilation is not a claim that every product flow is complete.

## Deployment and reproducible native verification

[iOS deployment targets](docs/ios-deployment-target.md) are authored in Dart or JSON and applied through generated Xcode configuration. NativeOperations inherit the app target; newer operations are rejected before files are written instead of silently raising the minimum OS. SDK graph sweeps retain replayable compressed inputs by default, and the [Android flow verifier](docs/releases/dev19.md) provides a reusable native acceptance and APK audit command. See the [dev19 changes](docs/releases/dev19.md) for contracts and limits.

Typed [native configuration](docs/native-configuration.md) exposes general Info.plist values, entitlements and structured Android manifest declarations through both Dart and JSON. [Android SDK versions](docs/android-deployment.md) are shared authoring inputs that reach native Gradle configuration; [native API version validation](docs/android-native-version-validation.md) checks catalog calls against retained JVM and XML evidence. These declarations do not replace native provisioning or runtime permission grants.

## Create and run

```sh
./bin/dcflight create /absolute/path/my-app --name "My App" --id com.example.myapp
./bin/dcflight run /absolute/path/my-app --platform ios
./bin/dcflight run /absolute/path/my-app --platform android
```

Edit `app.json`, save, and rerun. The iOS command builds, installs and launches in an available Simulator. Android builds, installs and launches on an authorized attached device/emulator; `--build-only` produces an APK without a device. This is rebuild/relaunch, not state-preserving hot reload.

Python 3.9+ runs the development tools without third-party Python packages. Native builds require Xcode or Android SDK35/JDK17/Gradle8.11.1. Android tool paths can be supplied through `--android-sdk`, `--java-home` and `--gradle`. The standard Gradle wrapper can be installed with `tools/install_gradle_wrapper.py`.

## One business-logic language

See [shared logic](docs/shared-logic.md) and `examples/shared_logic/`. A manifest declares a DC Dart source and typed exported functions; `call` actions invoke those functions. The same source produces distinct iOS device, iOS Simulator and Android arm64 objects. Generated projects build independently afterward, with no compiler build hooks.

[DC Dart 0.1.1 is released](https://github.com/DotCorr/dcdart/releases/tag/v0.1.1). Set `DCFLIGHT_DCC` to its `dcc` executable and `DCDART_DART` to the required Dart SDK3.12.2 executable. For Android logic compilation, set `DCFLIGHT_ANDROID_CLANG` to the NDK arm64 compiler. DC Dart's development frontend uses that SDK; generated applications do not contain it.

The application ABI supports scalar values and [bounded borrowed UTF-8 string inputs](docs/shared-utf8-input.md), with explicit failure flows for invalid input. [Bounded UTF-8 results](docs/shared-utf8-results.md) use caller-owned output buffers and typed success/failure flows. Snap validates and canonicalizes account handles in shared DC Dart before its authored authentication requests. Records and collections are not yet integrated into this application ABI. DC Dart's supported low-level subset includes functions, sized arithmetic, branches and loops. The released compiler currently rejects bare-source Dart `bool` parameters; Snap explicitly projects Boolean state through `Flag` into UInt32 arguments (see the media contract). Full hosted Dart, arbitrary Dart packages and object-heavy asynchronous Dart app logic are not implemented. Typed effects generate native asynchronous operations with explicit completion and ownership rules. Unsupported features fail rather than introducing a hidden runtime.

## Broad SDK access for AI tools

The SDK catalog retains exact native signatures, availability information where supplied, unsupported reasons, source hashes and native verification evidence. Search results are paginated so AI tools can retrieve relevant APIs without loading entire SDKs into context. Schema v2 stores repeated verification payloads once while retaining per-symbol evidence. Read-only access supports v1 and v2; a writable v1 open migrates transactionally. See [catalog storage](docs/catalog-storage.md) for backup, compaction and compatibility details.

```sh
./bin/dcflight sdk index-android /path/to/android-current.txt --sdk 35 --catalog /path/to/sdk.sqlite
./bin/dcflight sdk index-ios /path/to/ios-sweep --catalog /path/to/sdk.sqlite
./bin/dcflight sdk search "Button" --platform ios --limit 20 --catalog /path/to/sdk.sqlite
./bin/dcflight sdk coverage --catalog /path/to/sdk.sqlite
./bin/dcflight sdk emit /path/to/invocation.json --catalog /path/to/sdk.sqlite
./bin/dcflight mcp --catalog /path/to/sdk.sqlite
```

See [SDK tooling](docs/sdk-tooling.md), [iOS API tooling](docs/ios-api.md) and [Android API tooling](docs/android-api.md). Typed SDK expressions are ordinary native source for user-owned application code. A native signature is not automatically a shared semantic capability, callback implementation or permission flow.

Exact iOS invocation proofs can certify a getter, setter or call in an explicit main-actor or nonisolated context. Conditional evidence never enables the whole descriptor: source is regenerated from the recorded SDK graphs and the selected invocation is recompiled before use. See [operation-specific iOS proof](docs/ios-api.md).

MCP exposes semantic registry search, app schema, app validation, SDK search, exact signature lookup, coverage and typed source emission. It is development-only stdio tooling. Catalogs distinguish **indexed**, **emittable**, **native-compiled** and **executed** APIs; no inventory count means complete platform support.

## Compiler and synchronization

```sh
./bin/dcflight validate examples/counter.json
./bin/dcflight inspect examples/counter.dart
./bin/dcflight compile examples/counter.json --out /absolute/path/native-projects
./bin/dcflight compile examples/counter.json --out /absolute/path/native-projects --dry-run
./bin/dcflight audit /absolute/path/native-projects
```

JSON and a simple const Dart authoring DSL converge into a language-independent typed IR. This declarative DSL is separate from executable DC Dart business logic. Stable node IDs preserve source identity. Generated-file edits produce explicit synchronization conflicts; user-owned source is never overwritten. See [architecture and boundaries](docs/architecture.md).

The routed shared UI includes layouts, text, forms, secure fields, buttons, native stacks/tabs, typed repeated records, image surfaces and authored transitions. Shared effects cover bounded HTTP, native secure storage, photo-library acquisition, collection updates and constrained timers. The SDK catalog is much broader than this semantic layer. Web, Windows and Linux generator interfaces are designed but their backends are not implemented. Full platform coverage remains the project objective, not a claim about this implementation.

## Verification and ingestion harnesses

```sh
python3 -m unittest discover -s tests -v
python3 tools/check_registry.py
dart pub get --directory examples
dart analyze authoring/lib examples/counter.dart
python3 tools/verify_native.py --ios
python3 tools/sweep_ios_sdk.py --output /path/to/ios-sweep
```

Native harnesses build detached projects, compile exact SDK-call fixtures, execute shared logic where a device/simulator is available, and inspect source/build graphs, object symbols, linked libraries and APK contents. Tests never turn compile-only evidence into device-execution claims. Source scanning alone cannot prove arbitrary user-added native libraries have no runtime.
