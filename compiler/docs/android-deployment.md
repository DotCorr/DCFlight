# Authored Android SDK versions

AndroidConfiguration exposes compileSdk, minSdk, targetSdk and validateNativeAvailability from Dart and JSON. The canonical IR stores integer base API levels; decimal/minor and preview SDKs reject. Defaults remain compile35/min26/target35. The current generated backends require minSdk26 or newer, and minSdk <= targetSdk <= compileSdk. This explicitly preserves the supported Android native toolchain floor; it does not claim old Android backend compatibility.

```dart
const AndroidConfiguration(
  compileSdk: 36,
  minSdk: 26,
  targetSdk: 36,
  validateNativeAvailability: true,
)
```

JSON uses the same names under nativeConfiguration.android. NativeImplementation additionally accepts androidMinSdk and androidCompileSdk; these are operation requirements, not a maximum runtime version. targetSdk selects Android compatibility behavior and does not prevent the app running on a newer OS. [Android version configuration](https://developer.android.com/studio/publish/versioning).

New ordinary Gradle projects include `apply from: 'native-versions.gradle'` at top level. The generated script sets all three versions and checks the final default configuration plus each enabled application variant before preBuild. A user-owned app/build.gradle without this hook stops synchronization; the compiler does not overwrite it. An override in a product flavor or defaultConfig that contradicts authored versions fails the build. The helper remains development-time Gradle input and is not packaged in the APK. Variant checks use the native [AGP application variant API](https://developer.android.com/reference/tools/gradle-api/8.9/com/android/build/api/variant/ApplicationVariant).

Strict native API availability validation is a separate connected compiler check: `validateNativeAvailability: true` requires exact retained SDK and XML evidence for each authored catalog call. False preserves compatibility with previously indexed records whose requirements are unknown; unknown never means runtime-supported. Known API requirements must still be checked. Permissions, feature flags, extension alternatives and physical device behavior are not certified by base API version facts. A finite known removal cannot be treated as safe on all future runtime OS versions.

The build slice has a real AGP8.9.2/Gradle8.11.1 compile36/min26/target36 APK build, merged-manifest checks, and negative native Gradle runs for default minimum, flavor minimum and compile SDK overrides. This slice alone is not full application API availability enforcement: its API/sequence/operation integration and final combined native verification must also pass before release. Configuration-cache support has not been verified.
