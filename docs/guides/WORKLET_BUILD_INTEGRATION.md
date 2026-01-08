# Worklet Build-Time Integration

## Current Status

✅ **Compilation System Complete**
- Worklets are automatically compiled to Kotlin/Swift
- Generated code is included in `WorkletConfig`
- Native code detects compiled worklets

⚠️ **Build-Time Integration (Next Step)**
- Generated code needs to be written to files
- Files need to be included in native build
- Functions need to be called by name at runtime

## How It Works Now

### 1. Compilation (Automatic)
When you use `@Worklet`, the system automatically:
1. Extracts AST from your function
2. Generates IR
3. Validates (UI-thread-safe only)
4. Generates Kotlin and Swift code
5. Includes code in `WorkletConfig`

### 2. Runtime Detection
Native code detects compiled worklets:
```kotlin
// Android
if (isCompiled || workletType == "compiled") {
    // Compiled worklet detected
    // Generated Kotlin code available in functionData["kotlinCode"]
}
```

```swift
// iOS
if isCompiled || workletType == "compiled" {
    // Compiled worklet detected
    // Generated Swift code available in functionData["swiftCode"]
}
```

### 3. Execution (Current)
- **Text worklets**: Use pattern matching (works perfectly)
- **Numeric worklets**: Need build-time integration

## Next Steps: Build-Time Integration

### Option 1: Write Generated Code to Files (Recommended)

1. **During Development/Build:**
   ```dart
   // Write all compiled worklets to native source files
   await WorkletCodeWriter.writeAll(
     androidOutputDir: 'android/src/main/kotlin/com/dotcorr/dcflight/worklets',
     iosOutputDir: 'ios/Classes/Worklets',
   );
   ```

2. **Include in Native Build:**
   - Android: Files automatically included if in `src/main/kotlin`
   - iOS: Add files to Xcode project

3. **Call by Name at Runtime:**
   ```kotlin
   // Android
   val result = GeneratedWorklets.worklet_12345(elapsed, param1, param2)
   ```

   ```swift
   // iOS
   let result = GeneratedWorklets.worklet_12345(elapsed: elapsed, param1: param1, param2: param2)
   ```

### Option 2: Build Script Integration

Create a build script that:
1. Scans for `@Worklet` functions
2. Compiles them
3. Writes generated code to files
4. Includes files in native build

## Implementation Plan

### Phase 1: File Writing (Current)
- ✅ `WorkletCodeWriter.writeAll()` exists
- ⏳ Call it during build/development

### Phase 2: Build Integration
- Add build script or hook into Flutter build
- Automatically write files before native build

### Phase 3: Runtime Execution
- Update native code to call generated functions by name
- Use reflection or direct calls

### Phase 4: Hot Reload Support
- Regenerate files on hot reload
- Rebuild native code if needed

## Example: Complete Flow

### 1. Define Worklet
```dart
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

### 3. Compilation (Automatic)
- System compiles to Kotlin/Swift
- Code included in `WorkletConfig`

### 4. Build-Time (Future)
- Write generated code to files
- Include in native build

### 5. Runtime (Future)
- Native code calls `GeneratedWorklets.elasticBounce()`
- Zero bridge calls, pure UI thread execution

## Current Workaround

For now, compiled worklets:
- ✅ Are detected by native code
- ✅ Text worklets work via pattern matching
- ⏳ Numeric worklets need build-time integration

The compilation system is **complete and working**. The final step is build-time file writing and native function calls.

