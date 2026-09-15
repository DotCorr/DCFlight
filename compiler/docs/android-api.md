# Android native API catalog and direct call generation

`dcflight.platforms.android_api` consumes Android's metalava text API signatures at development time. It indexes classes, constructors, methods, fields and enum constants, preserving declarations, parameter types, annotation metadata, overload identities and SDK snapshot identity. Its output is ordinary Java, compiled by the Android toolchain. There is no reflective dispatch, runtime registry, embedded language engine or dcflight library in this path.

The Android 35 snapshot contains **3,372 classes and 51,865 members**, with no member declaration parsing misses. Of those, **48,948** pass the conservative emitter eligibility checks and **2,917** carry explicit unsupported reasons. An API being indexed, being eligible for emission, compiling against one SDK, and functioning on a device are separate claims. All **48,948 eligible members** have now passed real Java compilation against the supplied Android 35 `android.jar`, with zero unchecked warnings, plus a generated class dependency scan. The catalog itself reports zero native-tested members until the independent conformance report is associated with it; this prevents silently treating parsing as verification.

## Python integration

```python
from dcflight.platforms.android_api import AndroidAPI, JavaValue

api = AndroidAPI.from_file('/path/to/android-35.txt', api_level=35)

# Stable IDs include the owner and full overload parameter types.
member = api.get('android.widget.TextView#setText(java.lang.CharSequence)')
expression = api.emit(
    member.id,
    arguments=[JavaValue.literal('Continue')],
    receiver=JavaValue.reference('button', 'android.widget.Button'),
)
print(expression.source)
# ((android.widget.TextView) button).setText((java.lang.CharSequence) ("Continue"))

constructor = api.emit(
    'android.widget.Button#<init>(android.content.Context)',
    [JavaValue.reference('context', 'android.content.Context')],
)
# new android.widget.Button((android.content.Context) (context))

constant = api.emit('android.Manifest.permission#CAMERA')
# android.Manifest.permission.CAMERA

matches = api.search('android.hardware.camera2.', limit=50)
records = api.records()  # JSON-serializable AI/catalog descriptors
api.export('/path/to/catalog.json')
```

`NativeExpression` returns `source`, `java_type` and `member_id`. The caller places this expression in a suitable native method, handles return values and declares referenced symbols. A reference is a Java identifier and declared type, never a code snippet. Strings are escaped literals. Explicit casts lock the selected overload. Inheritance compatibility is derived conservatively from the SDK hierarchy; generic bounds are not mistaken for parent types. Constructors/static members reject receivers; instance members require a compatible reference. Nullable values and `@NonNull` parameters are checked. Missing metadata means unknown nullability, not a fabricated guarantee.

## Deliberate limits

- Concrete parameterized types, nested generics, wildcard bounds and arrays retain their full native types. Generic receivers use wildcard views to avoid unchecked raw calls. Free class/method type variables and unsupported type expressions are indexed but rejected for emission. References to flagged APIs, including flagged enclosing classes, are rejected. Protected APIs and constructors requiring an enclosing instance are rejected.
- This API emits calls and reads fields. It does not synthesize callback implementations, permission prompts, lifecycle ownership, threading, checked-exception handling or resource cleanup. Listener objects can be passed as typed references to user-owned native implementations.
- The snapshot level is not the minimum API level of a symbol. Records expose `minimumApi: null` until release-history ingestion exists. Apps targeting older devices need explicit native availability guards; the emitter does not invent those guards.
- Generated expressions are a compiler building block. Indexing alone does not add every platform capability to the semantic UI registry or make arbitrary calls available as shared application logic.
- No arbitrary Java source is accepted as a `JavaValue`. User-owned native source is a separate, explicit project boundary.

## Native conformance harness

```sh
python3 tools/verify_android_api.py \
  --api /path/to/android-35.txt \
  --android-jar /path/to/sdk/platforms/android-35/android.jar \
  --javac /path/to/jdk17/bin/javac \
  --limit 4096 \
  --report /path/to/android-conformance.json
```

The harness deterministically spreads probes across packages and member kinds, prioritizing UI, storage, intents, camera, media, location, vibration, notifications and permissions. Each probe uses the typed emitter. Java compilation checks actual member visibility, types, overloads and SDK compatibility. A class-file scan checks for forbidden compiler/runtime references. The report records exact tested IDs, input hashes, diagnostics and separate indexed/emittable/native-tested counts. Use `--limit 50000` to probe every currently eligible member. The harness does not execute APIs on a device and cannot certify runtime permission or lifecycle behavior.

## Build and launch Android apps

`dcflight.android_develop.run_android(project, device=None, sdk=None, java_home=None, gradle=None, build_only=False)` regenerates the Android target, builds its ordinary debug APK with Gradle, installs it using `adb`, and launches its native activity. `build_only=True` produces the APK without requiring a device or Platform-Tools. `android_doctor(...)` checks required tool paths. SDK discovery accepts `ANDROID_HOME`, `ANDROID_SDK_ROOT` and standard Android Studio locations. Device selection fails clearly for missing/unauthorized devices and requires an explicit serial when several are connected.

This is native build/install/relaunch, not state-preserving hot reload. The development command remains on the developer computer; the app contains only generated and user-owned native application code.
