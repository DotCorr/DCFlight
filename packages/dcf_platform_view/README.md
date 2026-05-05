# dcf_platform_view

Use `runDCFApp` instead of `runApp` for full pipeline control and one native platform view.

## "Target of URI doesn't exist" for `package:dcf_platform_view/dcf_platform_view.dart`

If you open a **parent folder** (e.g. Dotcorr or DCFlight) as the project, the example’s relative `rootUri` for this package can make the analyzer fail to resolve it.

**Fix:** From this package root (`dcf_platform_view`), run:

```bash
cd example && flutter pub get
cd ..
dart scripts/fix_package_config.dart
```

This rewrites `example/.dart_tool/package_config.json` so `dcf_platform_view` uses an absolute `file://` URI; the analyzer will then find the package regardless of workspace root.

**Alternative:** Open **this folder** (`dcf_platform_view`) as the project in Cursor/VS Code so the relative path resolves.

## Run the example

```bash
cd example
flutter run
```
