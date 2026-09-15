# Corrected shared application source contract

The Snap screen-template implementation is not the requested architecture. Do not add new app-level copy, field ordering, dialogs, navigation decisions or layout choices to platform templates. Preserve proven OS/service adapters, but replace whole-screen implementations with emission from shared authoring.

## First structural correction: authored routes and UI trees

Canonical `RoutedApplication` extends the existing typed application with `routes: tuple[Route, ...]` and `navigation_actions: tuple[NavigationAction, ...]`. It is independent of Dart and JSON. It retains states/actions/logic and ordinary typed nodes. Version2 authoring adds:

- `routes`: objects `{id, title, body, presentation?}`. `presentation` is `page` (default), `sheet`, or `fullScreen`. Route bodies are normal primitive UI trees. Root may be a navigation host or tabs. No social-screen shorthand is allowed in this path.
- `navigationActions`: objects `{id, op, route?}`. `op` is `push`, `replace`, `back`, `present`, or `dismiss`. Push/replace target page routes, present targets sheet/fullScreen. Back/dismiss have no target. Node `action` references are validated against both ordinary actions and navigation actions.
- `navigationStack` node: `{id,type:'navigationStack',props:{initialRoute:'routeId'}}` with no children. Initial route must be a page.
- `tabs` and `tab` are generic native navigation structures. A tab has literal title/icon and exactly one navigationStack child. Route bodies may contain tabs as their root; nested stacks preserve independent native histories.

No platform backend invents route titles, button labels, empty states or app dialogs. A route's primitive tree supplies all UI content and layout. Native generators emit direct SwiftUI NavigationStack/TabView/sheet or Android Compose Material3 NavigationBar/NavHost/modal implementations. Android button-row navigation is not accepted as a substitute.

Parameters, typed records/lists, async effects and DC Dart state orchestration follow as explicit typed extensions; unsupported input must fail. They are not to be hidden in backend app templates. This initial contract must not be called the complete shared app architecture or used to claim Snap migration finished.

## Shared logic boundary

DC Dart0.1.1 can already operate on caller-owned state and UTF8 buffers through native addresses. The compiler's uint64 ABI extension removes its prior32-bit-only boundary. Generated typed state/record/buffer adapters will expose that safely; UI/backend event handlers must forward declared events and execute declared native effects, not independently decide app flow. No runtime graph interpreter, renderer, VM or dcflight dependency is introduced.

## Acceptance

Changing authored wording, field order, spacing or route destination must change both generated targets through the same input. Tests must demonstrate that parity and reject app-level text/flow in backend templates. Native widgets/permission panels may retain platform appearance; product behavior and authored content have one source.

## Generation receipts

New receipts include a per-target generator identity: compiler version, a fingerprint
of compiler Python sources/native templates/data, and a fingerprint of the effective
reviewed registry mappings. A compiler-only or mapping-only change followed by a
single-target regeneration leaves the other target visibly mismatched, even when the
authoring document and typed IR have not changed. Regenerate both targets to align them.
Paths in the fingerprint are package-relative, so relocation does not itself change
the identity. Bytecode caches are excluded. External SDK/toolchain and native dependency
evidence remains separate; this is not a reproducible-binary claim.

Older receipts do not establish compiler identity. `generatorIdentityRecorded` reports
whether every compared target contains that evidence; older recorded authoring inputs
can still match without proving that the same compiler produced them. The metadata is
local and editable, not a signed attestation, and never ships in the native app.

Each compile writes development-only `.dcflight/source.json` with the normalized authoring document hash, typed IR hash, node count and targets generated in that run. It does not embed the authoring document or its private defaults. `.dcflight/nodes.json` identifies the actual Swift node files and Kotlin source locations. These receipts are evidence of source identity, not proof of visual or behavioral equivalence; use native builds and paired interaction checks for that.

### Current generated-source integrity

`dcflight audit OUTPUT` reports `generatedIntegrity` separately from `sourceConsistency`.
Matching input receipts establish what was used for generation; they cannot establish
that the files have remained unchanged. The integrity check hashes all generated files
against `.dcflight/state.json`, including generation receipts and native logic artifacts.
A changed, missing or unsafe tracked generated file causes the audit to fail. It does
not overwrite or discard edits: reconcile intentional changes in the shared authoring
source or move custom implementations into user-owned files, then regenerate normally.

User-owned file edits and untracked additions are outside this integrity claim. A missing
baseline is reported as unknown, not matched. The baseline is local editable metadata,
not a signed attestation. Matching hashes do not prove generator correctness, identical
platform appearance, installed binary identity or complete user journeys. Keep native
build and paired visual/interaction checks as separate release requirements.

## Native route state and conditional chrome

Android route content stays in one stable Compose call site inside its Scaffold. A blank authored title makes only the top bar conditional on native stack history; it must not switch between a bare content branch and a Scaffold branch. Such a switch recreates remembered scroll/input state while the outgoing destination is still composing. Native Navigation and rememberScrollState retain route-local state; no dcflight navigation runtime is shipped. Product state changes may still change content height independently of scroll restoration.

### iOS destination router ownership

Each native route root and each `navigationDestination` explicitly receives its host's `NavigationRouter` environment object. The enclosing NavigationStack environment alone is insufficient for nested native stacks: a pushed view can otherwise resolve another host's router, so a flow clears state but its back action does not pop the displayed destination. Keep explicit bindings on both content entry points.

### Installed iOS photo-flow verification

`tools/verify_snap_ios_ui.py` drives the already installed, signed-in `com.dotcorr.snapshared` app using XCTest. It requires Xcode, xcodegen, an explicit simulator UDID, and the exact accessibility label of a known QA photo already in that simulator's Photos library. Supply fresh `--work` and `--report` paths and `--photo-label`; the test selects only that fixture, checks preview centering, cancels the composer, then cancels a second picker request. It never publishes the draft. The runner and tiny test host are isolated development tools, not generated app dependencies.

The Photos picker runs in Apple's `com.apple.mobileslideshow.photospicker` extension. Its image/control accessibility bounds are queried there; taps use verified in-window coordinates when the extension does not report standard hittability. Artifacts include XCTest results, screenshots, logs and installed app hashes. This harness assumes an English simulator and existing QA account state; it is not complete authentication, physical-device or production acceptance.

The harness rejects multiple PhotosPicker instances on the selected simulator before running, since XCTest may otherwise attach to an obsolete extension process. It reports their PIDs and does not stop processes automatically. Run native UI checks separately from other tests that drive the same simulator.

### Untitled tab-container roots

When a route root is an untitled tab container and its outer path is empty, iOS renders the container directly. Each authored tab already owns a native NavigationStack; wrapping all those stacks in another native stack makes a push cover the tabs. Ordinary page routes and nonempty outer paths retain their native stack. An explicitly titled container retains its outer title chrome; this correction does not silently discard an authored title. Root-reset and modal-dismiss environments remain on the stable outer Group. This is compiler-generated native view composition, with no application-specific route names or runtime interpreter.

The installed Snap photo-flow test additionally requires Camera’s tab control to remain hittable while its composer is pushed, before testing cancellation.

## Authored native title display

A route accepts `titleDisplay: "compact" | "large"` in JSON. Dart exposes `TitleDisplay.compact` and `TitleDisplay.large` on Screen; the canonical Route stores a typed TitleDisplay enum. Omitted values use compact, so title size no longer depends on an iOS automatic default that differs from Android. This intentionally changes previously implicit iOS large titles; author large when that presentation is wanted.

```dart
Screen(id: 'composer', title: 'Share a photo',
  titleDisplay: TitleDisplay.compact, body: composerBody)
```

Compact emits SwiftUI navigationBarTitleDisplayMode(.inline) and Compose TopAppBar. Large emits SwiftUI .large and Compose LargeTopAppBar. A large mode requires a nonempty title. This setting chooses native title size, not a custom renderer; OS font metrics, colors, transitions and native scroll behavior remain platform-owned. A shared collapsing-scroll policy is not introduced by this setting. Untitled routes still suppress root title chrome and preserve native back navigation when pushed.

Snap explicitly authors a compact composer title. Its installed iOS photo test checks compact navigation-bar height, visible tabs, photo selection and cancellation. Native compiler checks exercise both compact and large modes; those build checks are distinct from runtime interaction evidence.
