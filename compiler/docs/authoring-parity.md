# Typed authoring parity and native metadata

Every registry component must have a named Dart node. The parity test checks the
registry against the authoring library so adding a JSON-only component fails CI.
Counter (including Counter.bind), Divider, Progress and NativeView use the same
canonical node capabilities as JSON. Progress is indeterminate; ProgressBar is
numeric. All four expose the common style, motion and conditional properties.
RoutedApp forwards nativeOperations and sdkCatalog from App.

Routed Android uses native Compose HorizontalDivider and CircularProgressIndicator.
NativeView uses the native Compose AndroidView interoperability API. For routed
apps the user-owned Java factory is UserViews.v_NAME(android.content.Context,
AuthoredState), returning android.view.View. The existing non-routed Java contract
uses (android.app.Activity, AppModel). The Swift factory remains
UserViews.v_NAME(model: AppModel), returning a SwiftUI View. These factories are
explicit platform escape hatches, not automatically generated SDK wrappers.
The compiler never supplies their implementation or overwrites user-owned source.

## Permission synchronization

Existing Android main manifests remain user-owned. Generation now rejects an
existing manifest that lacks a required generated permission, limits its SDK range,
or removes that permission. This validation runs before synchronization, so a
failed update leaves files untouched. It does not automatically rewrite the user
manifest. The nativeConfiguration path now supplies generated permission overlays and
uses the native manifest merger; see native-configuration.md. The legacy path
continues to reject missing permissions instead of rewriting a user-owned manifest.

Current shared permission contracts cover camera and location. Generated iOS plist
purpose strings and Android permissions exist for these capabilities. General typed Info.plist authoring, entitlement file/binding generation, and
structured manifest authoring are now available through nativeConfiguration; see
[native configuration](native-configuration.md). Native authorization and complete
platform API coverage remain separate requirements. Indexed SDK declarations are not
proof of those deployment requirements or full platform coverage.
