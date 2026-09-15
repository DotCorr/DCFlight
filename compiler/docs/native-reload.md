# Development-only native reload

This implementation is deliberately separate from normal generators and the ongoing Snap app. No reload loader is injected into either generated app. DC Dart remains compiled machine code; the released DC Dart compiler is unchanged.

## Implemented interfaces

`python3 -m dcflight.reload SOURCE --out NATIVE_OUTPUT --target ios|android` watches authoring files, validates and synchronizes native source, builds through Xcode/Gradle and restarts the explicitly selected test app. Select `--device ID` or `--build-only`. `--once` builds one stable revision and exits. `--evaluate-dart --dart-sdk /path/to/dart` explicitly opts into executing trusted Dart authoring. Use the existing DCFLIGHT_DCC, DCDART_DART and DCFLIGHT_ANDROID_CLANG environment variables for shared logic.

Examples, from the compiler checkout:

```sh
python3 -m dcflight.reload /path/to/app.json --out /path/to/native \
  --target ios --device YOUR_ALREADY_BOOTED_SIMULATOR_UDID

python3 -m dcflight.reload /path/to/app.dart --evaluate-dart \
  --dart-sdk /path/to/dart --out /path/to/native --target android \
  --device YOUR_TEST_DEVICE --android-sdk /path/to/android-sdk \
  --java-home /path/to/jdk17 --gradle /path/to/gradle
```

Use a dedicated output directory when another development task is already generating/building the app. The watcher holds its own session lock and uses the existing conflict-safe generator. It never uninstalls an app or clears its persistent data. In-memory state is **not** preserved by this restart path. Explicit application state restoration remains future work; no automatic restoration is claimed.

Authoring directories are scanned by content, with generated/build directories excluded. Use `--watch /path/to/additional/source` for imports outside that directory or explicitly selected native user files. Source changes during a build make that build superseded: it is not installed. A failed edit leaves the installed app alone, and a later edit retries. Native outputs/builds may have changed during a failed compilation; the watcher does not claim transactional rollback of build folders. Logs and current status are in `NATIVE_OUTPUT/.dcflight/reload/`. Stop with Ctrl-C.

## Native code swap experiment

`dcflight.reload.build.build_generation` compiles released DC Dart into a content-addressed native shared library. The prototype covers host, Android ARM64, and iOS ARM64 simulator command-line processes. It does **not** yet load replacement code inside generated mobile applications or update native views.

`dcflight/reload/native/loader.c` loads a locally compiled replacement, validates the ABI fingerprint and all required exports, then switches the function table while holding a mutex. All calls must hold that same mutex throughout execution. The previous library is unloaded only after those calls have finished. A failed replacement preserves the working table and generation. Application state belongs to the caller and survives a successful swap.

The contract is narrow: fixed scalar C ABI, stateless functions, no mutable globals, retained pointers/callbacks, spawned work, reentrant loader calls or unknown external dependencies. Incompatible signatures/layouts require restart. Calls are serialized in this experiment; this is a development tradeoff, not a release performance cost. The loader is not an untrusted plugin sandbox: dlopen can execute initializers, so only compiler-produced, verified local generations are admissible.

The loader and metadata refuse compilation unless `DCFLIGHT_DEVELOPMENT_RELOAD=1` is explicitly set. Normal app generators do not import, emit, link or contact the loader. Tests check generated native source for the absence of the loader dependency. A future integration must additionally audit actual release binaries for loader symbols, transports, function tables and payloads; a compile guard alone is not sufficient proof.

`planner.plan` conservatively classifies changes. ABI eligibility is explicitly distinct from platform support: native swap requires a verified adapter. Current mobile watcher behavior is always native rebuild/restart. There is no fallback JSON interpreter, UI graph executor, Dart VM or JavaScript engine.

## Reproduce the native proof

```sh
python3 tools/verify_native_reload.py --target host \
  --dcc /path/to/released/dcc --dart /path/to/matching/dart \
  --prelude /path/to/prelude.dart --nm /path/to/llvm-nm \
  --out /path/to/proof
```

For Android, select `--target android-arm64`, supply `--clang /path/to/NDK/aarch64-linux-android26-clang`, `--adb /path/to/adb`, and `--device SERIAL`. The harness runs its own short-lived native command-line process in a unique temporary device directory and removes that directory. It does not install, stop or interact with any app.

For iOS Simulator, select `--target ios-simulator-arm64 --device UDID` on macOS with an already booted ARM64 simulator. It runs its own simulator process without opening or replacing app UI. This is **not evidence for physical iPhone loading or application sandbox/code-signing support**.

The proof changes increment from +1 to +10 while keeping caller state in one process, rejects an incompatible ABI and missing library, and exercises 100,000 calls across four threads during 100 further swaps. It also checks compilation fails when the development build gate is absent.

## Remaining integration

- Debug-only native app adapters, compatible native view replacement and lifecycle handling.
- Physical iOS signing/loading verification; simulator success does not establish device support.
- Android application sandbox loading verification; a shell process is a separate security context.
- Typed state snapshot/migration for restart fallback, including explicit handling of live camera/network/location resources.
- Platform-specific UI edit classification, and concrete release binary absence checks once adapters exist.
- Packaging the experimental C sources into a distributed toolkit. Current proof runs from the compiler checkout.

Android's standard Apply Changes explicitly restarts for native SO edits. Xcode previews use debug-specific build/library arrangements. This experiment does not claim an unrestricted cross-platform replacement for those tools.

References: [Android Apply Changes](https://developer.android.com/studio/run?hl=en#apply-changes), [Apple debug build layout](https://developer.apple.com/documentation/xcode/understanding-build-product-layout-changes).
