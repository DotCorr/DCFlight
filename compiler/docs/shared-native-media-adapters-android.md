# Android native media adapter extraction

Status: audited proposal, not implemented shared media capability coverage. The previous SocialActivity screen generator is not a source for new screen composition. Its existing device tests prove selected adapter operations only; they do not prove the forthcoming shared media flows.

## Shared contract required before implementation

Aligned with the iOS adapter review:

- `MediaState(name)` is initially empty; `MediaRef(name)` refers to an immutable, transient native photo payload. It is not an authorable filesystem path, URI, base64 string, JSON value, restored state, or DC Dart pointer. A native value contains a private payload, MIME type, byte count and dimensions. Only checked native acquisition/download effects create one. Clearing/replacing it releases its payload; sign-out explicitly clears private media. Temporary storage, if required, is app-private, excluded from backup and removed on release/startup recovery.
- Extend `Projection` with `mediaBytes`, `mediaWidth`, `mediaHeight`, `hasMedia`; these yield typed scalar inputs to actual DC Dart policy functions. No native function decides upload eligibility, story duration, recipient selection, consent policy, or navigation.
- `PhotoOptions(maxEdge, jpegQuality, maxInputBytes, maxOutputBytes, maxDecodedPixels)` is authored and validated. Normalize EXIF orientation, downsample before decode, preserve aspect ratio, strip source metadata by re-encoding JPEG, and reject oversized outputs. Output replacement is atomic. Defaults must be shared documented defaults, not values privately chosen by either platform generator.
- `PickPhotoEffect(target, options, success, cancel, failure)` uses the native system photo picker, single image selection only. Cancellation preserves prior media. Native picker chrome is platform-owned; the application owns every surrounding explanation, button and flow. No broad photo-library permission is added for a picker operation.
- `CameraResource(name)` and `cameraPreview(resource, accessibilityLabel, readyTarget, failure)` describe one live native preview surface. Generic authored layout provides all controls and overlays. `CameraEffect(resource, operation, target?, options?, success?, cancel?, failure)` has explicit permission/start, capture, switch, stop operations. Capture requires a mounted foreground preview. Every pending acquisition has exactly one completion; capture while unavailable is failure, not silent success. Stop/unmount/background cancels outstanding work and closes hardware. Switch reports unavailable lenses without choosing another lens secretly.
- `RequestEffect.body` becomes a disjoint JSON object or `MediaBody(MediaRef)`. Media requests stream exact normalized bytes with payload MIME type, normal declared auth/path, existing response decoding and authored success/failure. No app endpoint is embedded in an adapter. Existing JSON output atomicity and cancellation guarantees remain.
- `image(media: MediaRef, fit, accessibilityLabel)` renders local media. A separate typed `RemoteMedia(path, bearer, maxBytes)` image source supports private media in repeated chat/story rows. Paths may use scoped typed collection fields as encoded components. Image loading has native bounded concurrency and per-view cancellation; it must not call the scalar model's single-request channel, which would cancel unrelated requests. No credentials in disk-cache keys/logs, no redirect credentials, no persistent private image cache. All error/empty/loading UI is authored via state/events or child nodes; image adapter adds no copy.
- `MapSpec(collection, latitudeField, longitudeField, titleField?, selection?, action?, camera, nativeOptions)` is a visual primitive. Coordinates are validated integer microdegrees, avoiding a new floating-point logic ABI: latitude ±90,000,000 and longitude ±180,000,000. Selection uses the collection key and authored action. Initial camera center/zoom is authored; the adapter must not focus the first friend. Map markers do not request location permission, fetch friends, publish coordinates, create empty states, or add app headings. Provider attribution remains native and visible. Android uses the declared content-locked MapLibre dependency; provider style URL is explicit module configuration, not a secret backend default.
- `PermissionEffect(capability, resultTarget, success, failure)` and `LocationEffect(latitudeTarget, longitudeTarget, accuracyTarget?, timeoutMs, success, cancel, failure)` remain separate from map rendering. Only foreground one-shot location initially. Results update atomically, reject stale callbacks and invalid/out-of-range coordinates. Publishing is a separate authored request reached through DC Dart consent policy. Consent withdrawal cancels pending acquisition immediately and separately requests server revocation; failed revocation must remain visible through authored state.
- Full stories require generic typed clock/timer and lifecycle hooks, not a hidden native 24-hour rule. The shared source calculates remaining duration using DC Dart, schedules expiry/removal and rechecks upon foregrounding. Timer cancellation on route removal/logout prevents stale private pixels. Choose a documented timestamp representation deliberately; current int32 scalar Unix seconds has a 2038 limit. This is a separate unresolved IR decision, not silently implemented as native product logic.

Generic `overlay` and button child content are also needed for authored shutter/album/flip composition. A native camera adapter must never add those controls itself.

## What can be reused and what must change

`templates/android_social/NativeCamera.java` contains Camera2/ImageReader and JPEG normalization mechanics. Extraction must remove all human-facing strings and hardcoded 2048/85 limits. The existing code does not transform the preview for resized/rotated viewfinders. Its capture session callbacks do not consistently check the camera generation; disconnect/error callbacks can clear a newer device. The image callback checks `closed` but not capture generation. Failures do not consistently complete the pending capture callback. These are correctness requirements for a new adapter, not permission to relabel the old class as complete.

The current normalizer bounds compressed input at 32 MiB and downscales a long edge, but needs an explicit decoded pixel budget, checked output size and guaranteed bitmap disposal on all error paths. A failed normalization must not leak source buffers or replace previously valid media.

The map and location code inside `SocialActivity.java` mixes native calls with `/map`, `/location`, consent copy, toast messages, first-friend camera policy and story/account decisions. Extract API mechanics only. New `MapView` ownership must forward create/start/resume/pause/stop/destroy/low-memory events, update markers when typed collections change, discard removed markers, preserve stable selection and report provider failures through typed events. No Activity screen builder is reused.

The old `ApiClient` is not the new effects executor: it contains fixed `/v1`, stringified human errors and permissive UTF-8 decoding. Extend the already strict generated `NativeEffects` transport for media bodies instead. Binary image loads require their own bounded channels while sharing session cancellation scope.

## Required native verification

1. Camera available/unavailable/permission denied, capture callback exactly once, switch with no front lens, background/dispose during open/capture, surface resize and rotation.
2. EXIF rotations/mirrors, extreme aspect ratios, malformed images, compressed-input/pixel/output bounds; confirm re-encoded dimensions and metadata removal.
3. Picker cancel preserves prior media; replacement and logout release private payload; stale picker/camera callbacks cannot restore cleared media.
4. Actual media upload/download/private-access denial against service; JSON and media output failures remain atomic. UI images loading concurrently must not cancel chat requests.
5. Map empty/update/remove/select and provider error; attribution visible; no permission request from display alone; opt-out while location acquisition is pending prevents later publication.
6. Shared authored story deadline hides/removes loaded pixels at expiry and after foreground restoration. Validate long-running timer arithmetic and timestamp bounds.

These are new acceptance tests. The earlier 37-test legacy Snap instrumentation and current 40-test shared collections harness do not cover this extension.

## Primary API references

- [Android Camera2 preview orientation and resizing](https://developer.android.com/media/camera/camera2/camera-preview)
- [Android photo picker](https://developer.android.com/training/data-storage/shared/photo-picker)
- [MapLibre Native Android documentation](https://maplibre.org/maplibre-native/android/)

## Camera, location and map resources

The generic Android backend now lowers authored camera resources to Camera2 with a UI-owned TextureView, lifecycle-bound capture session and capability-checked autofocus. Display changes refresh preview transforms, including 180-degree rotations that leave view dimensions unchanged. Captured JPEGs pass through the same bounded, orientation-aware media normalization used by the photo picker. Capture callbacks are generation checked so clearing a media slot cannot restore a late photo.

Permission and one-shot location effects contain no consent or publication policy. They return typed facts to the authored flow. Coordinates round to microdegrees with ties away from zero; accuracy rounds up to whole meters. Disabled location services return unavailable, and readings older than the request are rejected.

MapLibre is an explicit, content-locked native dependency. The authored style URL, attribution, region, typed marker fields and annotation subtree are compiled directly. Invalid marker coordinates clear the map and expose the authored failure view; corrected data retries without a provider reload. Marker rasterization responds to referenced state, density and font scale changes. Map resources do not fetch friends, ask permission or publish a location.

`tools/verify_android_resources.py` builds a separate instrumentation APK against the exact installed generated app. It exercises generated Camera2 resources using an offscreen SurfaceTexture consumer, plus coordinate rounding and native preview transforms. This is native API evidence, not a photo-picker or touchscreen journey. Consult its generated report for the actual pass status; merely building the fixture is not execution evidence.

`tools/verify_android_map.py` builds a separate instrumentation APK with compile-only access to the installed application's exact generated NativeMap function. It mounts native test content, loads the declared provider style, checks nonblank compiled annotation pixels, changes annotation state, and verifies invalid-coordinate removal followed by recovery. No touchscreen input or application account changes are part of this test. Its report hashes the installed application APK.

## Camera placeholder layout

The camera preview places loading and failure children at the vertical center and logical start of its authored frame on both platforms. Child styles control width, padding and text alignment; centered, padded copy belongs in the shared authoring tree. Android must not use the default top-start Box alignment. The live native camera surface still fills the preview frame. This contract does not equalize screen sizes or replace native navigation chrome.
