# Shared native media and timed state

This is development-time typed authoring. The generated application owns ordinary native image values, controls, HTTP operations and timer callbacks. No registry, JSON interpreter, Dart VM or dcflight engine is shipped.

`RoutedApp.media` contains `MediaState(name: ...)`, initially empty. `MediaRef(name: ...)` identifies that transient slot. It cannot contain a user-authored filename, URL, URI, base64 value or pointer. `PickPhotoEffect` selects one still image through the OS library picker and normalizes it before publishing the replacement atomically. Its `success`, `cancel` and `failure` are explicit authored flow identities. Cancellation preserves the previous value. `ClearMediaEffect` clears the slot and invalidates pending acquisition for it; `CancelEffect` also invalidates pending acquisition. The first slice supports `source: 'library'` only; camera capture is rejected.

`PhotoOptions` has shared defaults, not platform-selected product policy:

| Option | Default | Accepted range |
| --- | --- | --- |
| maxEdge | 2048 | 32–4096 |
| jpegQuality | 85 | 1–100 |
| maxInputBytes | 33554432 | 1–33554432 |
| maxOutputBytes | 8388608 | 1–8388608 |
| maxDecodedPixels | 20000000 | 1–40000000 |

Native mechanics enforce compressed-input/decode/output bounds, orientation normalization and metadata-stripping JPEG encoding. DC Dart remains responsible for application acceptance and destination decisions. `MediaMetadata.bytes/width/height` return scalar integer projections of trusted native metadata; absent media returns zero. `present` is Boolean. `MediaBody(mediaRef)` is a disjoint binary request body, encoded canonically as `{"mediaBody":{"media":"name"}}`; the existing authored path, bearer and response/output machinery applies to upload. JSON bodies remain supported.

`LocalImage` renders a transient slot. `RemoteImage` takes an origin-relative string or typed path parts, explicit bearer state and explicit byte/pixel/edge limits. Path fields can refer to the enclosing repeated record only. Both image nodes require authored `loading` and `failure` child nodes and an accessibility label. These become exactly two canonical children in that order. Private downloads have per-view cancellation and bounded native decoding; they must not use the application's serial JSON request channel or a persistent public image cache. Clearing auth/source or removing the view disposes the old private image.

`ReadCollectionEffect` atomically copies fields from a keyed record into typed scalar state before invoking its success flow. Missing keys invoke its failure flow. `ClockEffect(target:, failure:)` reads Unix epoch seconds with checked Int32 range. **Dates outside 1970–2038 fail closed**; this is an explicit current canonical scalar limitation, not a claim of unlimited timestamp support. A future wider scalar representation requires coordinated IR/native changes.

`Timer(id:, intervalMs:, action:)` is explicitly authored and lives with the model; allowed interval is 250–3600000 milliseconds. Its reachable flow graph may contain only shared selectors, Clock, Set, ClearMedia, ClearCollection, ReadCollection and Invoke effects. Navigation, HTTP, picker and secure-store operations are rejected transitively until timer UI ownership is defined. Native lifetime cleanup must cancel the timer. The shared Snap story flow reads the clock and calls the same compiled `decideStoryExpiry` on both targets; the native adapter contains no 24-hour application rule.

`Flag(Ref<bool>)` explicitly projects a Boolean to integer 0/1 for a C-compatible shared function input. Actual DC Dart 0.1.1 compilation of a bare top-level function with a Dart `bool` parameter currently fails with `Reference to dart:core::bool is not bound to an AST node`. The sample therefore uses explicit Flag projection and `u32` signatures. No upstream compiler patch was made or left unreleased, and semantic Boolean UI state is retained. Presence validation uses byte length zero rather than a hidden coercion.

The shared Snap source now authors library photo composition, raw upload, photo messages, story publication/list/view/delete, and timed selected-story expiry. It clears private payloads, identifiers and lists on logout/session expiration. Native picker behavior, normalized images, real transport and actual mobile execution require independent native tests; source lowering alone is not evidence of those behaviors. Camera preview/capture, permission requests, location reads and native maps use the separate typed contracts documented in [shared-device-contract.md](shared-device-contract.md). Physical-device acceptance remains separate from simulator and native helper verification.
