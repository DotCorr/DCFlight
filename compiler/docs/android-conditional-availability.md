# Conditional Android SDK availability

`@FlaggedApi` remains unsupported by default. An annotation is retained even
when its exact signature has compiled against a supplied SDK. Compilation says
nothing about a device's runtime flag state or the first Android release that
implements the API. Catalog metadata therefore keeps `minimumApi` and
`runtimeSupported` unknown and marks enabled signatures `conditional`.

## Generate and ingest exact evidence

Use the Android API declaration source that is already indexed in the catalog.
The following invokes the ordinary Android call generator, tests all declarations
whose sole blocker is `FlaggedApi`, isolates native compilation failures, and
imports only verified successes:

```sh
dcflight sdk verify-android-availability \
  --source /path/to/indexed-android-api.txt \
  --sdk "$ANDROID_HOME/platforms/android-35/android.jar" \
  --javac "$JAVA_HOME/bin/javac" --api-level 35 \
  --report /path/to/fresh-availability.json \
  --catalog /path/to/sdk.sqlite
```

This command ships in the installed compiler wheel and does not require a source checkout. Omit `--catalog` to write evidence without importing it. Completed batch progress is written to stderr; stdout contains the final JSON result.

The report binds the source hash, SDK bytes, compiler source identity, exact
member IDs and generated probe hashes. Importing additionally recompiles every
claimed-success call, so changing a success flag in a report cannot enable a
missing declaration. Source replacement and evidence updates are transactional.
Other unsupported reasons remain rejected. Existing ordinary SDK evidence is
preserved; conditional evidence is compile-only, never device-execution proof.

Reports and catalogs are not cryptographic certificates. Normal `NativeAPI`
access revalidates conditional calls against caller-configured SDK bytes; a
handcrafted catalog record is not sufficient to bypass native verification.
The SDK identity is checked on each conditional invocation and native proof is
cached within that `NativeAPI` instance. Changed compiler code requires fresh
evidence.

## One authoring contract

Set `androidSdkSha256` on the Android `NativeImplementation`, and use a throwing
operation with an authored `NativeOperationEffect.failure` flow:

```dart
NativeOperation(
  name: 'conditionalRead',
  result: NativeScalar.int,
  throwsErrors: true,
  execution: NativeExecution.main,
  ios: iosImplementation,
  android: NativeImplementation(
    androidSdkSha256: verifiedSdkSha256,
    steps: androidCalls,
    result: NativeRef('answer'),
  ),
)
```

JSON uses the same `implementations.android.androidSdkSha256` property. The
standalone native sequence accepts the same property at the sequence root and
requires `allowThrows: true`. Direct `NativeAPI.emit` accepts
`androidSdkSha256` and returns explicit conditional-availability metadata;
callers composing their own native source must preserve failure handling.

Configure the compiler's actual SDK with one of:

- `NativeAPI(catalog, android_sdk=path, javac=compiler_path)` for embedded tools;
- `DCFLIGHT_ANDROID_SDK_JAR` for a specific boot JAR;
- `ANDROID_HOME` or `ANDROID_SDK_ROOT` for an installed SDK directory.

The compiler uses caller-selected `javac`, `JAVA_HOME/bin/javac`, or the normal
executable search path. Executable paths embedded in evidence are never run.

## Generated native projects

Generated call boundaries catch `java.lang.LinkageError` and convert it into an
ordinary `IllegalStateException`. The native operation's existing exception
handler routes this to the authored failure flow. The compiler does not catch
`Throwable` or `OutOfMemoryError`. A runtime feature flag can still change
behavior without a linkage error; the certificate does not promise functional
availability on any device.

Generated Android projects include a development-only Gradle hook. `preBuild`
hashes the actual `android.bootClasspath` boot JAR and rejects a mismatch before
compilation. Removing the last conditional call leaves a generated no-op hook,
so the user-owned Gradle file remains valid. Existing projects missing an active,
unconditional top-level hook receive an actionable migration error; user-owned
Gradle files are not overwritten. Commented, nested and ambiguous hooks are
rejected conservatively.

No registry, SDK probe runner, Dart VM, interpreter or dcflight runtime is
packaged in the generated application.
