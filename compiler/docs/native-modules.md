# Native dependencies are development-time inputs

A native dependency is an ordinary library linked by the generated platform project. It does not install an application-side registry, interpreter or compiler. Maps use MapKit on iOS and a declared MapLibre native Android library. MapLibre's map rendering is that native component's implementation, not a dcflight cross-platform UI renderer.

Declare a reviewed data-only manifest, then resolve it with the platform package tool:

```
dcflight module install examples/native-modules/maplibre.android.json --out native-modules/maplibre --gradle /path/to/gradle --java-home /path/to/jdk
dcflight module verify native-modules/maplibre/module.lock.json
dcflight module export-android native-modules/maplibre/module.lock.json --catalog modules.db --javap /path/to/javap
```

Android declarations require an exact Maven coordinate/version and explicit permissions. Resolution selects runtime library variants, not sources/documentation; all transitive AAR/JAR files receive SHA-256 locks. Lock verification detects declaration and artifact changes. Installation does not overwrite an existing directory. Resolution, emission, compilation and execution are separate evidence levels.

When the app already uses native libraries such as Compose, resolve the module together with that trusted project's runtime graph:

```
dcflight module install examples/native-modules/maplibre.android.json --out native-modules/maplibre-aligned --android-project /path/to/native/android --gradle /path/to/gradle --java-home /path/to/jdk
```

This runs a temporary reviewed Gradle initialization script against the app's `debugRuntimeClasspath`. It adds the declared module only in memory, resolves compatible versions with the host dependencies and locks every resolved runtime artifact. The declared module's own version must remain unchanged. The host project is trusted build code; this is not a sandbox for third-party Gradle scripts.

For an aligned lock, all locked AAR/JAR bytes remain in the generated project. Its Gradle include excludes Maven duplicates of those modules only from application compile/runtime classpaths; compiler/plugin classpaths are untouched. No locked artifact is silently discarded. A re-lock operation temporarily disables these generated exclusions during resolution, without building the application. Re-resolve and verify native builds when changing host dependency requirements. Locks that select different versions of the same module cannot be combined without joint alignment.

`examples/native-modules/maplibre-compose/` records the Snap example's compatibility graph (see `examples/snap/`). This fixes the duplicate AndroidX/Kotlin classes produced by combining the earlier standalone MapLibre lock with Compose. A resolved graph still requires native compilation and execution before claiming compatibility.

Dart authors attach the locked module to the app:

```dart
modules: [NativeModule(id: 'maplibre', platform: 'android',
  lock: 'native-modules/maplibre/module.lock.json')],
```

The compiler checks the lock, copies the exact artifact bytes into the native project's `app/libs`, and writes ordinary Gradle dependencies. The generated native project builds without the module installer, original package cache, authoring SDK or module registry. The normal Android build toolchain still resolves its own build plugins. Shared logic currently targets ARM64, so module integration restricts the app to that ABI when shared logic is present. This avoids packaging a map library for an architecture with no application logic library.

`native-modules.gradle` and copied dependency artifacts are generator-owned. The application Gradle file and manifest remain user-owned after creation. Existing projects that predate modules must explicitly add the generated Gradle include and declared permissions; regeneration never silently rewrites user-owned files. Use a fresh output directory for an unambiguous first integration.

API export inspects bytecode using `javap`; it never runs package code. Signatures, concrete generic types and overload identities feed the existing catalog and typed native-call emitter. Unknown annotations, nullability, callback lifetimes and minimum platform versions are not invented. Unsupported generic shapes remain explicit. Catalog and MCP search work with the exported module scope. Neither signatures nor catalogs are bundled in the app.

SPM manifests can pin a credential-free HTTPS repository at a full immutable Git commit and verify a clean source checkout. Transitive SPM resolution, project integration and Swift module export are not implemented by this command yet; it does not report them as resolved or compiled. User-owned native project dependencies remain an explicit escape hatch.
