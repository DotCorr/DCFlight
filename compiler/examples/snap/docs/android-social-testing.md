# Native Android social integration checks

`tools/verify_snap_android.py` builds and executes a separate instrumentation APK against the installed generated `com.dotcorr.snap` app. The test APK contains only the fixture class, its compiler-generated nested classes and its own resource class. Application classes are compile-only references; no shared-logic or map libraries are copied into it.

The fixture executes the installed app's actual `ApiClient`, `SessionStore`, `NativeCamera.normalize` and `SharedLogic` classes. Its requests use the declared local backend through10.0.2.2. It creates three random disposable accounts, deletes those accounts in `finally`, and uses an isolated `nativeqa_` preference namespace and Keystore alias. The harness hashes the existing encrypted application session file before and after execution and requires it to remain identical. It never prints credentials.

Coverage includes37 assertions:

- Actual ART/JNI policy calls for2,000-character text,8MiB photos,24-hour story expiry and explicit location consent, including negative unsigned input rejection.
- Registration/login, encrypted-session roundtrip without persisted bearer plaintext, session clearing and token revocation.
- Friend request/acceptance, conversation creation and text delivery.
- Real Camera2 still capture to an offscreen `ImageReader`, generated image normalization, authenticated photo upload/download, and unauthorized-media denial.
- Friend-only stories,24-hour expiry metadata, deletion, friend-only location visibility and removal after disabling.

No UI clicks, screenshots, layout assertions or user navigation are automated by this harness. Instrumentation stops the target application process while testing; it preserves application data. Root visual testing uses CUA separately. Camera verification on the configured emulator captures the official software camera's test pattern, not a physical camera. Wall-clock24-hour expiry is checked through the real shared policy boundary and service metadata, not by waiting24hours or changing the backend clock.

Run with `--project` pointing to the generated project containing `android/`, `--work-dir` for the isolated test build, `--sdk`, `--java-home`, `--gradle`, `--serial` and `--report`. The installed target APK must byte-match `android/app/build/outputs/apk/debug/app-debug.apk`; the harness refuses to test a stale installation. The local backend and a camera permission granted through the app/device are prerequisites.
