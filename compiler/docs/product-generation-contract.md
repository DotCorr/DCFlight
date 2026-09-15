# Shared product generation contract (implementation in progress)

Snap is the acceptance application: camera, photos, stories, friends, conversations, map and account settings. Both native outputs must come from first-class Dart declarations backed by typed canonical IR. JSON remains an equivalent input. No manually maintained app-specific platform implementations may be treated as shared framework support.

## Required boundaries

- Keep v1 input/tests compatible. Extend generic presentation semantics; reusable high-level camera/messaging/map capabilities are allowed, declared in the registry and IR.
- Authoring code runs only by explicit local opt-in. MCP never evaluates arbitrary Dart. DC Dart compiles business functions into native objects; no frontend runtime ships.
- Code generators may emit ordinary app-owned native controllers, storage and API clients. No runtime graph interpreter, registry lookup, custom renderer, or dcflight dependency. Native SDKs for specific capabilities (e.g. platform map SDK) are disclosed normal native dependencies.
- Networking is real and asynchronous; loading, errors, cancellation and offline handling must be visible. Authentication tokens use platform secure storage.
- Backend is self-hostable, with accounts, friends, private conversations, media authorization, expiry and location sharing explicitly opt-in. No production-readiness claim until acceptance checks pass.

## Presentation extension

Node gains optional immutable Style and Motion, plus visibleWhen bool expression. Style fields: padding,gap,width,height,maxWidth,fill,color,background,borderColor,borderWidth,radius,fontSize,fontWeight,align,opacity. Width/height/maxWidth, padding/gap/radius/borderWidth are nonnegative integer logical points/dp. fontSize is a positive integer default-scale logical size that respects native text-size preferences: SwiftUI ScaledMetric relative to body and Android sp. Platform accessibility scaling curves may differ; the contract does not promise identical pixels. fill is boolean; opacity integer0..100; fontWeight enum regular/medium/semibold/bold; align start/center/end. Motion: kind fade/slide/scale; durationMs integer0..2000. Native reduce-motion settings take precedence. Native defaults never define shared spacing.

Generic additions: scroll(single child),spacer,card,icon(name),image(source),progressBar(value int0..100). Column/row/card/scroll child handling must have matching meaning across platforms. All existing inputs with no style preserve compatibility.

An explicit fontSize uses that font's natural line metrics rather than retaining an unrelated native theme line height. Android clears LocalTextStyle's lineHeight before merging authored typography; merely passing an unspecified Text argument does not reset inherited style. Both targets honor native text scaling. Full-screen accessibility layout and paired visual acceptance remain separate verification requirements.

## Work in progress

Root owns IR/validation/schema/compiler integration, backend service and shared app definition. Platform agents own native generator modules and native build checks. Dart agent owns ergonomic authoring/evaluation. Contracts for camera/messaging/service capabilities will be made explicit before integration.

## Social service and native feature contract

`Application.service: Optional[Service]` has `base_url: str`, `protocol: str='snap.v1'`, `development: bool=False`. JSON `service:{baseUrl,protocol,development}`. Production baseUrl must be HTTPS, no credentials/query/fragment. Explicit development permits only HTTP localhost/127.0.0.1; Android generator maps loopback to10.0.2.2 for the emulator. No public deployment is implied. API contract lives in services/snap/. No credentials are authored into the IR.

`Application.theme: Optional[Theme]` fields accent/background/surface/text/muted/danger hexRGBA colors, radius integer0..128 and padding integer0..128. Defaults in ir.py. A theme is compile-time configuration. No runtime theme registry.

Reusable feature node capability names: `camera`, `inbox`, `stories`, `friendMap`, `account` (empty props, no children); require service. Shared composition: `tabs` children `tab` wrappers; tab props `title:string` and `icon:literal semantic icon name`; exactly one child per tab. Tabs are ordinary native platform navigation. Root service feature shell must handle signed-out/signed-in authentication, deep conversation navigation/back, media preview sheet and retained selected tab. Feature screens use actual service requests from the versioned declared contract. Camera capability includes permission-aware capture/library import, image preview and send/story destinations; no dummy capture. Device-limited camera testing is reported separately.

Backend high-level semantics and UI are reusable feature implementations compiled into normal editable native source; no native manual app snippets required. Labels, tab order, theme, endpoint, feature presence come from shared Dart/JSON input. This is a high-level shared library API, distinct from claiming every OS method has cross-platform semantics. Root will add standalone generic routing in parallel.

Maps: iOS MapKit platform API. Android declared pinned MapLibre Native SDK using OpenFreeMap style `https://tiles.openfreemap.org/styles/liberty` with required provider attribution. No web maps/JS. Map SDK is an explicit ordinary native module, not a dcflight renderer. Location sharing opt-in; clients and server must respect disabled/stale state and friend authorization.


## Application display names and native source ownership

New projects bind `app.name` to a generated Android `native_app_name` string resource
and generated iOS `Native/AppInfo.plist`. Regenerating after an authored rename updates
these files while preserving the user-owned manifest and Xcode project. Android resource
quoting preserves spaces, quotes and backslashes. iOS build-setting interpolation in
an authored name (`$(...)` or `${...}`) is rejected.

Existing projects using generated `Native/TransportInfo.plist` or
`Native/ServiceInfo.plist` retain those bindings, with updated generated metadata.
Legacy projects that embed a literal name can regenerate while that name matches.
A rename then requires explicitly binding the user-owned manifest or Xcode target to
the generated resource, or generating into a new directory. The compiler reports the
required binding and does not rewrite user-owned files. Custom iOS plist paths require
an explicit migration. User-owned localized display-name overrides remain user-owned;
these default metadata bindings do not claim to replace native localization policy.
