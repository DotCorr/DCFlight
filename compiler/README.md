# dcflight compiler 0.1.0

Development-time authoring, native code generation, source synchronization and API tooling. Generated apps ship **no dcflight runtime**.

This package is isolated from the repository's older runtime framework. It emits ordinary Swift/SwiftUI Xcode projects and Java/Android Views Gradle projects. Read [the architecture](docs/architecture.md) for invariants, ownership rules and current limits.

## Create and run an app

From this directory, no installation is required:

```sh
./bin/dcflight create /absolute/path/to/my-app --name "My App" --id com.example.myapp
./bin/dcflight run /absolute/path/to/my-app
```

The second command builds the native iOS app, starts an available iPhone Simulator, installs the app, and launches it. Requires macOS and Xcode with an installed iOS Simulator. Edit your project's `app.json`, then run the same command again to see changes. Build logs are in the project's `.dcflight/build-ios.log`. This is a rebuild/relaunch workflow. Android projects are created alongside iOS and open in Android Studio; automated Android device launching is not yet implemented.

## Compiler commands

Python 3.9+ is sufficient for the compiler; it has no third-party runtime dependencies. Run from this directory:

```sh
python3 -m dcflight validate examples/counter.json
python3 -m dcflight compile examples/counter.json --out /absolute/path/to/counter
python3 -m dcflight compile examples/counter.dart --out /absolute/path/to/counter --dry-run
python3 -m dcflight audit /absolute/path/to/counter
```

The JSON and Dart examples produce the same typed IR. Open the emitted `ios/App.xcodeproj` with Xcode 16+ (iOS 17+), or the `android` directory in Android Studio. Android builds use JDK 17, Gradle 8.11.1, Android SDK 35 and AGP 8.9.2:

```sh
gradle --project-dir /absolute/path/to/counter/android :app:assembleDebug
```

The Gradle wrapper is not bundled. Android Studio can use the stated local Gradle distribution; `tools/install_gradle_wrapper.py` can install the standard verified wrapper into a generated project for standalone `./gradlew` builds. No compiler hook is added to native builds.

Supported capabilities: text, integer counter display, button, column, row, toggle, text field, divider, progress indicator, and user-native view/action escape hatches. State supports strings, Int32 and booleans. Shared actions support assignment, increment and boolean toggle. See `examples/catalog.json` and `examples/native.json`.

The Dart authoring form uses only `const app = App(...)`, `Node(...)`, `Action(...)`, `Ref(name: ...)`, literals, maps and lists. It does not execute arbitrary Dart. `authoring/lib/dcflight.dart` supplies the corresponding actual Dart classes for editor tooling. DC Dart is neither modified nor required.

## Inspect and extend

```sh
python3 -m dcflight inspect examples/counter.json
python3 -m dcflight registry text
python3 -m dcflight schema
python3 -m dcflight mcp
python3 tools/seed_registry.py
python3 tools/check_registry.py --fixture-out examples/catalog.json
python3 -m dcflight schema > registry/app.schema.json
```

MCP tools are `registry_search`, `app_schema` and `validate_app`. Standard output contains protocol messages only. Invoke the module from this directory, or install this package with `python3 -m pip install .` and use the `dcflight` executable.

Bulk API import:

```sh
python3 -m dcflight ingest /path/to/SwiftUI.symbols.json \
  --format apple-symbolgraph --sdk iPhoneSimulator26.2 --out /path/to/swiftui.inventory.json
python3 -m dcflight ingest /path/to/android-current.txt \
  --format android-api --sdk android-15.0.0_r1 --out /path/to/android.inventory.json
python3 tools/ingest_sdk.py --apple-module SwiftUI --out /path/to/inventories
```

Inventory entries are explicitly **unmapped**. The initial real SDK import indexed 129,617 symbols; it does not claim broad cross-platform parity. Extend reviewed mapping families, rebuild the schema and run both native backends. Do not auto-promote SDK symbols into executable mappings.

## Validate

```sh
python3 -m unittest discover -s tests -v
python3 tools/check_registry.py
dart pub get --directory examples
dart analyze authoring/lib examples/counter.dart
python3 tools/verify_native.py --ios
python3 tools/verify_native.py --android-jar /sdk/platforms/android-35/android.jar \
  --java-home /jdk --gradle /gradle/bin/gradle --android-sdk /sdk
```

Native verification includes counter, catalog and real native-extension projects. Reports and logs go under `.build/native` or the chosen `--work-dir`. CI defines equivalent native build checks. No hot reload, arbitrary Dart logic translation, production navigation/persistence/animations, or Web/Windows/Linux backend is claimed in this MVP.
