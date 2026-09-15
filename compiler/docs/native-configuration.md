# Native project configuration

dcflight supports general typed Info.plist values, entitlement dictionaries, and
structured Android manifest declarations from both Dart and JSON. These are
compiler inputs. Generated applications consume ordinary native files and do not
load this configuration through a dcflight runtime.

```dart
nativeConfiguration: NativeConfiguration(
  ios: IOSConfiguration(
    infoPlist: {
      'NSMicrophoneUsageDescription': PlistValue.string('Record audio.'),
      'CFBundleURLTypes': PlistValue.array([
        PlistValue.dictionary({
          'CFBundleURLSchemes': PlistValue.array([PlistValue.string('example')]),
        }),
      ]),
    },
    entitlements: {
      'com.apple.developer.associated-domains': PlistValue.array([
        PlistValue.string('applinks:example.com'),
      ]),
    },
  ),
  android: AndroidConfiguration(
    sourceSets: ['debug', 'release'],
    manifest: ManifestElement('manifest', children: [
      ManifestElement('uses-permission', attributes: {
        'android:name': 'android.permission.RECORD_AUDIO',
      }),
      ManifestElement('uses-feature', attributes: {
        'android:name': 'android.hardware.microphone',
        'android:required': 'false',
      }),
      ManifestElement('queries', children: [
        ManifestElement('package', attributes: {'android:name': 'com.example.other'}),
      ]),
    ]),
  ),
)
```

Use this property on `App` or `RoutedApp`. The equivalent JSON uses
`nativeConfiguration.ios.infoPlist`, `.ios.entitlements`, and `.android.manifest`.
Plist values are tagged objects, such as `{"type":"string","value":"Record audio."}`.

## Typed values and manifest expressiveness

`PlistValue` provides string, integer, real, boolean, data, date, array, and
dictionary constructors. Data uses canonical base64; dates use UTC
`YYYY-MM-DDTHH:MM:SSZ`. Arrays and dictionaries nest recursively. Values become
immutable canonical IR; binary/date native representations are produced only
during plist emission. Validation bounds depth, size, numeric range, XML characters,
names, and namespaces. App identity keys must remain consistent with `App`.

`ManifestElement` supports native element names, string attributes and nested
children. This covers permissions and attributes, hardware features, activities,
services, providers, receivers, intent filters, queries and metadata without a
new JSON-only path for each tag. Declare the actual referenced native classes and
resources in the project. Android's native tools validate native semantics.

Standard `android` and `tools` namespaces are bound automatically. Additional
namespaces, such as `dist`, can be declared with `AndroidConfiguration.namespaces`.
Unbound prefixes, namespace rebinding and ambiguous aliases are rejected. Extension
elements still require an appropriate native module/build configuration; declaring
`dist:module` does not turn an ordinary app into a dynamic-feature module.

## Generated files and updates

- iOS emits `Native/AppInfo.plist` and `Native/App.entitlements`. New Xcode projects
  bind them with `INFOPLIST_FILE` and `CODE_SIGN_ENTITLEMENTS`.
- Android emits generated manifest overlays in the declared source sets, normally
  `app/src/debug/AndroidManifest.xml` and `app/src/release/AndroidManifest.xml`.
  Android's own manifest merger combines them with user-owned main manifests and
  native libraries. Declare other build types/flavors in `sourceSets` as needed;
  this setting does not create Gradle build types or flavors.
- Inferred shared permissions join the generated overlays. Adding camera/location
  features updates them without overwriting the user-owned main manifest.
- Regeneration replaces/removes authored metadata and stale generated overlays.
  Existing generated-file edits raise conflicts. User-owned files remain untouched.
- Previously configured projects retain empty generated bindings when configuration
  is cleared, preventing references to a missing entitlement file.
- Older user-owned Xcode projects without the entitlement binding require an
  explicit binding migration or a fresh output directory. Generation reports this
  before synchronization. Existing user-owned overlay files also require conflict
  resolution; they are never silently overwritten.

## Android build versions

`AndroidConfiguration` also accepts `compileSdk`, `minSdk`, `targetSdk` and
`validateNativeAvailability` in both authoring forms. See [SDK version authoring](android-deployment.md)
for defaults, variant checks and migration of existing user-owned Gradle files,
and [native API requirements](android-native-version-validation.md) for the
strict catalog-evidence checks. A permission declaration and a sufficient API
level are separate requirements.

## Native rules still apply

Configuration authoring is not authorization to use a capability. Provisioning
profiles, developer-account approval, runtime permission grants, app extensions,
native implementations, and OS availability remain native platform requirements.
Gradle build settings and higher-priority variant manifests retain their normal
native precedence. This is not certification of every manifest value or every SDK
API, and it does not add general shared runtime permission flows beyond the existing
supported contracts.

References: [Apple entitlements](https://developer.apple.com/documentation/bundleresources/entitlements),
[Apple Info.plist](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Introduction/Introduction.html),
[Android manifest merging](https://developer.android.com/build/manage-manifests).
