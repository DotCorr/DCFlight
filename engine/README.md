# DCFlight Engine — flutter_zero

DCFlight's Dart runtime is now **DotCorr/flutter_zero** — a stripped-down
Dart embedder with no Skia, no Impeller, and no `dart:ui` rendering layer.

## What lives here

```
engine/flutter_zero/     ← git clone of github.com/DotCorr/flutter_zero
```

The `flutter_zero` fork provides:
- Dart VM + isolates (full speed, AOT/JIT)
- `dart:ui` – minimal surface: `PlatformDispatcher`, `FlutterView` stubs
- `PlatformDispatcher.instance.registerHotRestartListener()` — hot restart hook
- All six platforms: iOS, Android, macOS, Windows, Linux, Web
- Full compatibility with the existing `flutter` CLI tool

## What is gone

| Removed | DCFlight replacement |
|---------|----------------------|
| Skia / Impeller rendering | Native views via FFI (iOS) + JNI (Android) |
| `dart:ui` Paint/Canvas/Paragraph | – (not needed) |
| `package:flutter` SDK | `dcf_dart_compat.dart` + `dart:ui` minimal |
| `WidgetsFlutterBinding` | – (not needed) |
| `runApp()` | `DCFlight.go(app: ...)` |
| `StatefulWidget.reassemble()` hot-reload | `PlatformDispatcher.registerHotRestartListener` |

## Using the flutter_zero CLI

```bash
# Point your PATH to the DotCorr flutter_zero bin instead of the stock flutter SDK
export PATH="$(pwd)/engine/flutter_zero/bin:$PATH"
flutter --version      # should say flutter_zero
flutter run            # builds and runs with the stripped engine
```

Or set it as your SDK in VS Code / Android Studio by pointing
`flutter.sdkPath` to `engine/flutter_zero`.

## Updating

```bash
cd engine/flutter_zero
git pull origin master
```

## Architecture divergence

DCFlight no longer inherits Google Flutter's rendering assumptions.
The engine is now purely a **Dart runtime + platform embedder**.
The UI layer is built entirely in native Swift/Kotlin via FFI/JNI,
orchestrated by the DCFlight Dart framework.
