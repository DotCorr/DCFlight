# DCFPlatformView — Cheap DCF embedding in Flutter

## Goal

Build a way to embed **DCF content inside a Flutter app** that is **as cheap to render as a normal Flutter view** — i.e. avoid the usual platform-view cost (extra layers, sync jank, per-view overhead). Ground the design in **DCF’s architecture**; if we get it right for DCF, the same approach can translate to Flutter (generic cheap embed).

## Why platform views are expensive today

- **Hybrid composition**: Flutter is drawn into a texture; platform views are separate native layers. Result: two compositing paths, Flutter FPS can drop, and you pay per platform view.
- **Texture / virtual display**: Each platform view can be rendered into a texture; Flutter draws that texture. Cost: texture upload, virtual display, and scrolling/animations can feel janky.
- **N views ⇒ N costs**: Every `UiKitView` / `AndroidView` is another native view, another sync point, and another place where frame boundaries and hit-testing add overhead.

A “normal” Flutter view is just part of Flutter’s single layer tree — one compositing pass, no extra buffers. We want to get as close as possible to that.

## Core idea: align with DCF’s architecture

**DCF’s model** (standalone app):

- **One root view** — the app has a single native root (e.g. `UIView` / Android `View`); the framework owns it.
- **Dart → VDOM → bridge → native** — components render to a virtual tree; the engine diffs and sends updates over the bridge; native builds the real view hierarchy under that root.
- **No platform views** — DCF doesn’t embed Flutter’s canvas; it renders real native views. One tree, one root, direct native performance.

So DCF is already “one root, one tree.” When we embed DCF **inside Flutter**, we must give Flutter something to composite. The only way to stay true to DCF and keep cost low is:

- **One platform view = DCF’s root.** Flutter gets a single “hole” that is exactly the native root view DCF would use anyway. No extra wrappers, no N platform views for N DCF trees.
- **Many logical embeds (if needed)** can share that one root: one surface, multiple regions (clip/viewport), so we still have **N logical DCF embeds → 1 physical surface**.

The breakthrough is: **honor DCF’s architecture** — one root, one bridge, one native tree — and expose that as **one** platform view to Flutter. Then cost is “one layer” regardless of how many `DCFPlatformView` widgets you use (by sharing that root and using regions).

## Architecture options

### Option A — Single platform view + union frame (simplest)

- One native view (e.g. one `UIView` / `Android View`) that is the **DCF root** (or a container that hosts all DCF content).
- Flutter exposes a single `PlatformView` (or one hybrid composition “hole”) for that view.
- Flutter-side: each `DCFPlatformView` widget is **layout-only** (like a placeholder). It reports its layout rect to a central “DCF surface manager.”
- The manager:
  - Computes the **union** of all `DCFPlatformView` rects (or a single full-screen rect if we want to avoid overlapping).
  - Tells native: “DCF surface lives at (x, y, w, h).”
  - Native: one view at that frame; DCF tree is laid out inside it, with **clip regions** (or sub-viewports) so each logical region shows the right part of the DCF tree.

**Cost**: One platform view, one compositing step. No per-embed platform view.

**Trade-off**: Overlapping or non-contiguous regions need to be handled by clipping/viewport inside the single DCF surface (doable with your existing Yoga/native layout).

### Option B — Single texture (DCF renders to texture, Flutter draws it)

- DCF (native) renders into a **single** offscreen buffer (e.g. GPU texture or software bitmap).
- Flutter side: **one** `Texture` widget (or one TextureLayer) that displays that texture.
- A “DCF surface manager” again:
  - Collects layout of all `DCFPlatformView` placeholders.
  - Updates the texture when the DCF tree or layout changes (e.g. repaint DCF into the buffer, then notify Flutter to use the new texture).

**Cost**: One texture, one Flutter layer. No platform view at all. Cost is texture update when DCF content changes (and possibly one extra copy).

**Trade-off**: Need a robust way to get pixels from DCF (e.g. render to FBO or readback). Slightly more latency on updates than Option A.

### Option C — Custom embedder / single view as sibling (long term)

- Use Flutter’s embedding API so that **one** native view is a sibling of the Flutter view, and the framework positions it (e.g. from layout). So we don’t go through `PlatformView` at all; we have one “foreign” view that the embedder composites.
- This would require changes or hooks at the Flutter embedding layer (not just app/plugin code). Worth considering for a future “official” cheap embed story.

**Recommendation for DCF**: Start with **Option A** (single platform view = DCF root + union frame + clip/viewport). It matches DCF’s one-root model, keeps implementation in plugin/native code, and gives “as cheap as one platform view” regardless of how many `DCFPlatformView` widgets you have. Option B can be a follow-up for apps that prefer to avoid platform views entirely (e.g. pure texture path).

## Flutter translation

Once we have “N embeds ⇒ 1 surface” working for DCF:

- The **pattern** is generic: a “surface manager” that aggregates layout of N placeholder widgets and drives one native view or one texture.
- For **Flutter at large**, the same idea could be:
  - A widget like `CheapPlatformView` or `SharedPlatformView` that registers a region with a global manager; the manager owns one (or a few) platform views and positions/clips content per region.
  - Or an API where multiple “slots” share one platform view and the framework handles clipping/viewport. That would need framework-level support to be first-class.

So DCFPlatformView is both a concrete feature (embed DCF in Flutter cheaply) and a **proof of concept** that “single shared surface” can make embeds much cheaper and that the same approach could translate to Flutter.

## Implementation outline (Option A)

1. **Flutter (DCFlight plugin)**
   - New widget: `DCFPlatformView({ required DCFComponentNode content, ... })`.
   - Widget is a `RenderProxyBox` (or similar) that:
     - Takes layout from Flutter (constraints → size).
     - Registers (id, rect) with a **DCFSurfaceManager** (global or inherited).
     - Does **not** create a `PlatformView` by itself.
   - **DCFSurfaceManager** (singleton or provided by a `DCFSurfaceScope`):
     - Collects all registered rects (and tree of DCF content per region if we support multiple roots).
     - Computes union rect (or full-screen policy).
     - Communicates with native: “surface frame = (x,y,w,h)”, “regions = [ (id, rect), ... ]”.
     - Creates **one** platform view (e.g. via a single `UiKitView`/`AndroidView` that fills the union and is positioned by the overlay/stack that holds it).

2. **Native (iOS/Android)**
   - One “DCF surface” view (e.g. `DCFSurfaceView`) that:
     - Hosts the DCF root (or a container that lays out multiple DCF subtrees by region).
     - Receives frame updates from Dart (union rect).
     - Receives region list; uses clipping or sub-viewports so each logical region shows the correct DCF content (or one big DCF tree with scroll/layout so that only the visible part matters).
   - Reuse existing DCF engine: same bridge, VDOM, Yoga, native components. Only the “root” is this one shared view and layout is driven by Flutter’s rects.

3. **Lifecycle**
   - When the first `DCFPlatformView` is built → create the single platform view and start DCF.
   - When the last one is disposed → remove platform view, tear down DCF for that surface.
   - Layout changes (e.g. scroll, resize) → update rects in manager → native updates frame and regions.

This keeps the “one platform view” invariant and makes cost similar to “one normal Flutter view” (one layer, one sync), and the same idea can later be generalized for Flutter.

## Summary

| Aspect | DCF standalone | DCF embedded in Flutter (DCFPlatformView) |
|--------|----------------|------------------------------------------|
| Root owner | DCF (native window root) | Flutter (Flutter owns window; DCF gets one root view) |
| What Flutter sees | N/A | **One** platform view = DCF root |
| DCF pipeline | Dart → VDOM → bridge → native views | Same: one root, same bridge, same native tree |
| Cost | One native tree | One platform view (one “hole”), one native tree under it |

**Bottom line**: DCF stays DCF — one root, one bridge, direct native views. When embedded in Flutter, that root **is** the only platform view. Many logical embeds share it via one surface + regions. Same architecture; the same idea can translate to Flutter as a generic cheap-embed pattern.

## Next steps

1. **Spike (Option A)**  
   Implement `DCFSurfaceManager` + single platform view in the dcflight plugin; one full-screen or union rect, one DCF root. Validate that one `DCFPlatformView` in a Flutter app has cost comparable to one normal view.

2. **Multiple regions**  
   Extend so multiple `DCFPlatformView` widgets register different rects; native uses one view + clip/viewport (or multiple DCF roots in one container) to show the right content per region.

3. **Option B (texture)**  
   If needed, add a path where DCF renders to a texture and Flutter shows it via a single `Texture` widget (no platform view).

4. **Document for Flutter**  
   Extract the “single shared surface” pattern into a short proposal or doc that could inform a future Flutter API (e.g. shared platform view or cheap embed).
