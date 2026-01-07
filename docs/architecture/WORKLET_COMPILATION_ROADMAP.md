# Worklet Compilation Roadmap - Full Native Code Generation

## Vision

Compile Dart worklets directly to native code (Kotlin/Swift) that runs on the UI thread with zero bridge calls, similar to React Native Reanimated's worklet system.

## Current State

- ✅ Framework-level worklet infrastructure
- ✅ Serialization system
- ✅ Pattern-based implementations (typewriter)
- ❌ General-purpose Dart-to-native compilation
- ❌ Native code generation

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Dart Source                           │
│  @Worklet                                                │
│  double myWorklet(double time) => time * 2;             │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Worklet Compiler (Dart)                     │
│  - Parse @Worklet functions                             │
│  - Extract AST                                          │
│  - Validate (only UI-thread-safe operations)            │
│  - Generate intermediate representation (IR)            │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Code Generator                              │
│  - Convert IR to native code                            │
│  - Android: Generate Kotlin                             │
│  - iOS: Generate Swift                                   │
└──────────────────────┬──────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   Kotlin    │ │    Swift    │ │   Future:   │
│   Source    │ │   Source    │ │   C++/JNI   │
└─────────────┘ └─────────────┘ └─────────────┘
```

## Implementation Phases

### Phase 1: AST Extraction & Validation (Week 1-2)

**Goal:** Extract and validate worklet functions

```dart
// Use analyzer package to parse Dart code
import 'package:analyzer/dart/ast/ast.dart';

class WorkletASTExtractor {
  FunctionDeclaration extractWorklet(CompilationUnit unit) {
    // Find @Worklet annotated functions
    // Extract function body AST
    // Validate: no async, no I/O, no complex objects
  }
}
```

**Deliverables:**
- AST extraction from `@Worklet` functions
- Validation rules (UI-thread-safe operations only)
- Error reporting for invalid worklets

### Phase 2: Intermediate Representation (Week 2-3)

**Goal:** Create platform-agnostic IR

```dart
class WorkletIR {
  String returnType;  // 'double', 'String', etc.
  List<IRParameter> parameters;
  IRExpression body;  // Tree of operations
}

class IRExpression {
  IRNodeType type;  // LITERAL, BINARY_OP, FUNCTION_CALL, etc.
  dynamic value;
  List<IRExpression> children;
}
```

**Supported Operations:**
- ✅ Math operations (+, -, *, /, %, pow, sin, cos, etc.)
- ✅ Comparisons (==, !=, <, >, <=, >=)
- ✅ Conditionals (if/else, ternary)
- ✅ Variables (local only)
- ✅ Function calls (to native math functions)
- ❌ Loops (for/while) - convert to recursive or native functions
- ❌ Async operations
- ❌ I/O operations
- ❌ Complex object creation

### Phase 3: Kotlin Code Generation (Week 3-4)

**Goal:** Generate Kotlin functions from IR

```kotlin
// Generated from: @Worklet double myWorklet(double time) => time * 2;
fun worklet_12345(time: Double): Double {
    return time * 2.0
}
```

**Implementation:**
```dart
class KotlinCodeGenerator {
  String generate(WorkletIR ir) {
    // Convert IR to Kotlin source code
    // Handle type mappings (double, String, List, etc.)
    // Generate efficient native code
  }
}
```

### Phase 4: Swift Code Generation (Week 4-5)

**Goal:** Generate Swift functions from IR

```swift
// Generated from: @Worklet double myWorklet(double time) => time * 2;
func worklet_12345(time: Double) -> Double {
    return time * 2.0
}
```

### Phase 5: Build-Time Integration (Week 5-6)

**Goal:** Automatically compile worklets during build

**Build Process:**
1. Dart analyzer scans for `@Worklet` functions
2. Extract and validate worklets
3. Generate native code (Kotlin/Swift)
4. Include generated files in native build
5. Register worklets at runtime

**Build Script:**
```yaml
# pubspec.yaml
builders:
  worklet_compiler:
    enabled: true
    output_dir: generated/
```

### Phase 6: Runtime Execution (Week 6-7)

**Goal:** Execute compiled worklets on UI thread

**Android:**
```kotlin
// Generated worklet functions are compiled into APK
// Called directly from UI thread via reflection or direct call
val result = WorkletRegistry.execute("worklet_12345", elapsed)
```

**iOS:**
```swift
// Generated worklet functions are compiled into app
// Called directly from UI thread
let result = WorkletRegistry.execute("worklet_12345", elapsed: elapsed)
```

## Technical Challenges

### 1. Type System Mapping

**Dart → Native:**
- `double` → `Double` (Kotlin) / `Double` (Swift)
- `int` → `Int` / `Int`
- `String` → `String` / `String`
- `List<T>` → `List<T>` / `Array<T>`
- `Map<K, V>` → `Map<K, V>` / `Dictionary<K, V>`

### 2. Math Functions

**Native Math Libraries:**
- Android: `kotlin.math.*`
- iOS: `Foundation` / `Darwin`

**Mapping:**
```dart
// Dart
Math.sin(x)
Math.cos(x)
Math.pow(x, y)

// Generated Kotlin
kotlin.math.sin(x)
kotlin.math.cos(x)
kotlin.math.pow(x, y)

// Generated Swift
sin(x)
cos(x)
pow(x, y)
```

### 3. String Operations

**Supported:**
- Concatenation (`+`)
- Substring (`substring`)
- Length (`length`)
- Index access (`[index]`)

**Not Supported:**
- Regex
- Complex formatting
- File I/O

### 4. List Operations

**Supported:**
- Length (`length`)
- Index access (`[index]`)
- Iteration (via native loops)

**Not Supported:**
- Dynamic resizing
- Complex transformations

## Example: Full Compilation Flow

### Input (Dart)
```dart
@Worklet
double elasticBounce(double time, double damping, double frequency) {
  return Math.sin(time * frequency) * Math.exp(-time * damping);
}
```

### Intermediate Representation
```json
{
  "returnType": "double",
  "parameters": [
    {"name": "time", "type": "double"},
    {"name": "damping", "type": "double"},
    {"name": "frequency", "type": "double"}
  ],
  "body": {
    "type": "BINARY_OP",
    "op": "*",
    "left": {
      "type": "FUNCTION_CALL",
      "name": "sin",
      "args": [{
        "type": "BINARY_OP",
        "op": "*",
        "left": {"type": "VARIABLE", "name": "time"},
        "right": {"type": "VARIABLE", "name": "frequency"}
      }]
    },
    "right": {
      "type": "FUNCTION_CALL",
      "name": "exp",
      "args": [{
        "type": "BINARY_OP",
        "op": "*",
        "left": {"type": "UNARY_OP", "op": "-", "arg": {"type": "VARIABLE", "name": "time"}},
        "right": {"type": "VARIABLE", "name": "damping"}
      }]
    }
  }
}
```

### Generated Kotlin
```kotlin
package com.dotcorr.dcflight.worklets

import kotlin.math.*

object GeneratedWorklets {
    fun worklet_elasticBounce(time: Double, damping: Double, frequency: Double): Double {
        return sin(time * frequency) * exp(-time * damping)
    }
}
```

### Generated Swift
```swift
import Foundation

enum GeneratedWorklets {
    static func worklet_elasticBounce(time: Double, damping: Double, frequency: Double) -> Double {
        return sin(time * frequency) * exp(-time * damping)
    }
}
```

## Performance Benefits

### Before (Current - Pattern Matching)
- Pattern detection overhead
- Limited to predefined patterns
- Maintenance burden (add patterns manually)

### After (Full Compilation)
- ✅ Zero overhead - direct native function calls
- ✅ Any valid worklet compiles automatically
- ✅ Type-safe at compile time
- ✅ Optimized by native compilers (Kotlin/Swift)
- ✅ Can use native SIMD/vectorization
- ✅ Full IDE support (autocomplete, refactoring)

## Migration Path

### Step 1: Build Compiler Infrastructure
- AST extraction
- IR generation
- Code generation (Kotlin/Swift)

### Step 2: Build-Time Integration
- Dart build system integration
- Automatic worklet discovery
- Native code generation

### Step 3: Runtime System
- Worklet registry
- Function lookup and execution
- Fallback to pattern matching for unsupported cases

### Step 4: Gradual Migration
- Keep pattern matching as fallback
- Compile new worklets automatically
- Migrate existing patterns to compiled versions

## Success Metrics

- ✅ 100% of valid worklets compile successfully
- ✅ Zero bridge calls during execution
- ✅ <0.1% CPU usage for animations
- ✅ 60fps guaranteed (no frame drops)
- ✅ Compile time < 1 second for typical app
- ✅ Generated code is readable and debuggable

## Timeline Estimate

- **Phase 1-2:** 2-3 weeks (AST + IR)
- **Phase 3-4:** 2-3 weeks (Code generation)
- **Phase 5:** 1-2 weeks (Build integration)
- **Phase 6:** 1 week (Runtime)
- **Testing & Polish:** 1-2 weeks

**Total: 7-11 weeks** for full implementation

## Alternative: Hybrid Approach (Faster)

For faster implementation, we can:

1. **Start with expression compiler** (simpler subset)
   - Only support math expressions initially
   - Expand gradually

2. **Use existing Dart-to-JS compilers as reference**
   - Learn from `dart2js` architecture
   - Adapt for native targets

3. **Leverage LLVM/WebAssembly**
   - Compile Dart worklets to WASM
   - Run WASM on UI thread (both platforms)
   - Faster than full native compilation

## Next Steps

1. ✅ Document architecture (this file)
2. ⏳ Implement AST extraction
3. ⏳ Design IR format
4. ⏳ Build Kotlin code generator
5. ⏳ Build Swift code generator
6. ⏳ Integrate with build system
7. ⏳ Test with real worklets

## References

- React Native Reanimated: https://github.com/software-mansion/react-native-reanimated
- Dart Analyzer: https://pub.dev/packages/analyzer
- Kotlin Native: https://kotlinlang.org/docs/native-overview.html
- Swift Package Manager: https://swift.org/package-manager/

