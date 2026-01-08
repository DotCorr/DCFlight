# Worklet Usage Guide

## Quick Start

### 1. Define a Worklet

```dart
import 'package:dcflight/dcflight.dart';

@Worklet
double elasticBounce(double time, double damping, double frequency) {
  return Math.sin(time * frequency) * Math.exp(-time * damping);
}
```

### 2. Use in Component

```dart
ReanimatedView(
  worklet: elasticBounce,
  workletConfig: {
    'damping': 0.8,
    'frequency': 10.0,
  },
)
```

### 3. Generate Native Code (Before Building)

Run the generation script to write native code to files:

```bash
dart scripts/generate_worklets.dart
```

Or programmatically:

```dart
import 'package:dcflight/framework/worklets/compiler/build_hook.dart';

// In your main() or build script
await WorkletBuildHook.writeGeneratedCode();
```

### 4. Include Generated Files in Build

**Android:**
- File: `android/src/main/kotlin/com/dotcorr/dcflight/worklets/GeneratedWorklets.kt`
- Automatically included if in `src/main/kotlin`

**iOS:**
- File: `ios/Classes/Worklets/GeneratedWorklets.swift`
- Add to Xcode project manually or via podspec

### 5. Rebuild Native App

```bash
flutter build apk  # Android
flutter build ios   # iOS
```

## How It Works

1. **Compilation (Automatic)**
   - When you use `@Worklet`, the system automatically compiles it
   - Generates Kotlin (Android) and Swift (iOS) code
   - Includes code in `WorkletConfig`

2. **Build-Time (Manual)**
   - Run `generate_worklets.dart` to write code to files
   - Include files in native build
   - Functions are compiled into the app

3. **Runtime (Automatic)**
   - Native code detects compiled worklets
   - Uses reflection to call generated functions
   - Falls back to pattern matching if needed

## Supported Operations

See [WORKLET_SUPPORTED_OPERATIONS.md](./WORKLET_SUPPORTED_OPERATIONS.md) for full list.

**Supported:**
- ✅ Math operations (`+`, `-`, `*`, `/`, `%`)
- ✅ Math functions (`Math.sin`, `Math.cos`, etc.)
- ✅ List operations (`list[index]`, `list.length`)
- ✅ String operations (`string.substring`, `string.length`)
- ✅ Conditionals (`? :`)
- ✅ Property access (`object.property`)

**Not Supported:**
- ❌ Loops (`for`, `while`)
- ❌ Async operations
- ❌ I/O operations
- ❌ Complex object creation

## Examples

### Text Animation (Typewriter)

```dart
@Worklet
String typewriter(double elapsed, List<String> words, double speed) {
  final wordIndex = (elapsed / 2.0).floor() % words.length;
  final charIndex = ((elapsed % 2.0) * speed).floor();
  final word = words[wordIndex];
  return word.substring(0, charIndex.clamp(0, word.length));
}

AnimatedText(
  worklet: typewriter,
  workletConfig: {
    'words': ['Hello', 'World'],
    'speed': 10.0,
  },
)
```

### Numeric Animation

```dart
@Worklet
double pulse(double time) {
  return Math.sin(time * Math.PI * 2) * 0.5 + 0.5;
}

ReanimatedView(
  worklet: pulse,
  // Result is applied to view properties automatically
)
```

### Complex Calculation

```dart
@Worklet
double elasticBounce(double time, double damping, double frequency) {
  return Math.sin(time * frequency) * Math.exp(-time * damping);
}

ReanimatedView(
  worklet: elasticBounce,
  workletConfig: {
    'damping': 0.8,
    'frequency': 10.0,
  },
)
```

## Troubleshooting

### "GeneratedWorklets class not found"

**Solution:** Run the generation script:
```bash
dart scripts/generate_worklets.dart
```

Then rebuild your native app.

### "Function not found in GeneratedWorklets"

**Solution:** 
1. Check that the worklet compiled successfully
2. Verify the generated file exists
3. Ensure the file is included in the native build
4. Rebuild the native app

### "Compilation failed"

**Solution:**
- Check that your worklet only uses supported operations
- See [WORKLET_SUPPORTED_OPERATIONS.md](./WORKLET_SUPPORTED_OPERATIONS.md)
- Check compiler logs for specific errors

## Performance

- ✅ Zero bridge calls during execution
- ✅ Runs on UI thread (60fps guaranteed)
- ✅ Cannot be blocked by Dart thread
- ✅ Optimized by native compilers

## Next Steps

- See [WORKLET_BUILD_INTEGRATION.md](./WORKLET_BUILD_INTEGRATION.md) for build integration details
- See [WORKLET_COMPILATION_ROADMAP.md](../architecture/WORKLET_COMPILATION_ROADMAP.md) for architecture details

