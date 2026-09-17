# Android social feature generation

`Application.service` with a native `tabs` composition compiles through `backends/android_social.py`. Tab labels, ordering, icons, endpoint and theme are emitted as constants. There is no packaged node graph, registry, interpreter, dcflight library, Dart VM or WebView.

Generated app sources:

- `SocialActivity.java`: native authentication, tab/navigation controllers, conversations, friend requests, photo previews, stories, account controls and explicit foreground location consent.
- `ApiClient.java`: asynchronous HTTP requests, bounded responses, timeouts, credential-bearing redirects forbidden, generation-based cancellation and connection teardown.
- `SessionStore.java`: AES-GCM encrypted session data with a non-exported AndroidKeyStore key. Application backup is disabled.
- `NativeCamera.java`: Camera2 preview/capture and orientation-aware image normalization. Imported/captured images become JPEG quality85, maximum2048 on the longest side; uploads use the shared policy's8MiB bound. Camera and location resources are released when backgrounded.
- `MainActivity.java`: a small user-owned subclass. Other application sources remain normal editable generated files governed by synchronization conflict checks.

The four business gates call the released DC Dart AOT library through generated `SharedLogic` JNI methods. There is no Java reimplementation of those rules. Native code validates representable input sizes before invoking the shared methods.

Android uses the explicitly declared MapLibre Native OpenGL12.3.1 module. The compiler module lock resolves exact native AAR/JAR content; this is an ordinary native mapping SDK. The OpenFreeMap style retains map attribution. Loading errors are shown; friend coordinates come only from the authorized backend. Development HTTP is restricted to the emulator loopback alias10.0.2.2; all other cleartext traffic is refused.

The service contract is `../server/api-contract.json`. Private media always uses authenticated `/v1/media/{id}` requests. There are no public attachment URLs, fabricated message receipts, synthetic friends or fake locations. Conversations poll while foregrounded; push notifications are not implemented.

## Verification boundaries

Generation tests cover shared configuration, source ownership, policy call sites, encryption and cleartext boundaries. Native Java compilation has passed against Android35 and resolved MapLibre artifacts. The first real Snap APK build has passed with its actual DC Dart arm64 library. These checks do not establish camera hardware behavior, successful map-provider access, or complete interactive product acceptance. Those require the separate emulator/device and backend acceptance checks.

Current limitations requiring device acceptance include camera preview transform/aspect behavior across sensor orientations and vendors, permission denial/retry flows, offline recovery and media memory use on older devices. No store-readiness claim is made by a successful build.
