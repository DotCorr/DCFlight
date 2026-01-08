# Worklet Supported Operations

Worklets are **restricted** (like React Native Reanimated) but support **most common Dart patterns** used in animations and calculations.

## ✅ Supported Operations

### Math Operations
- All arithmetic: `+`, `-`, `*`, `/`, `%`
- Comparisons: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Logical: `&&`, `||`, `!`
- Unary: `-` (negation)

### Math Functions
```dart
@Worklet
double calculate(double x) {
  return Math.sin(x) * Math.cos(x) + Math.sqrt(x);
}
```

Supported functions:
- `Math.sin`, `Math.cos`, `Math.tan`
- `Math.asin`, `Math.acos`, `Math.atan`, `Math.atan2`
- `Math.exp`, `Math.log`, `Math.log10`
- `Math.sqrt`, `Math.pow`
- `Math.abs`, `Math.max`, `Math.min`
- `Math.floor`, `Math.ceil`, `Math.round`

### List Operations
```dart
@Worklet
String getWord(double index, List<String> words) {
  final idx = index.floor() % words.length;
  return words[idx];
}
```

Supported:
- Index access: `list[index]`
- Length: `list.length` (compiles to `list.size` in Kotlin, `list.count` in Swift)

### String Operations
```dart
@Worklet
String typewriter(double elapsed, String text, double speed) {
  final chars = (elapsed * speed).floor();
  return text.substring(0, chars.clamp(0, text.length));
}
```

Supported:
- Length: `string.length`
- Substring: `string.substring(start, end)` or `string.substring(start)`
- Concatenation: `string1 + string2`

### Number Methods
```dart
@Worklet
double clamped(double value) {
  return value.clamp(0.0, 1.0);
}
```

Supported:
- `num.clamp(min, max)` - Clamps value between min and max
- `num.floor()` - Rounds down
- `num.ceil()` - Rounds up
- `num.round()` - Rounds to nearest
- `num.abs()` - Absolute value

### Conditionals
```dart
@Worklet
double conditional(double time) {
  return time > 0 ? time * 2 : 0;
}
```

Supported:
- Ternary operator: `condition ? then : else`
- If/else expressions (via ternary)

### Complex Expressions
```dart
@Worklet
double complex(double time, double damping, double frequency) {
  return Math.sin(time * frequency) * Math.exp(-time * damping);
}
```

All of the above can be combined in complex expressions.

## ❌ NOT Supported

### Loops
```dart
// ❌ NOT SUPPORTED
@Worklet
double sum(List<double> values) {
  double total = 0;
  for (var value in values) {  // ❌ No loops
    total += value;
  }
  return total;
}
```

**Workaround:** Use native functions or convert to recursive patterns.

### Async Operations
```dart
// ❌ NOT SUPPORTED
@Worklet
Future<double> asyncWorklet() async {  // ❌ No async
  await Future.delayed(Duration(seconds: 1));
  return 1.0;
}
```

### I/O Operations
```dart
// ❌ NOT SUPPORTED
@Worklet
String readFile() {
  return File('data.txt').readAsStringSync();  // ❌ No I/O
}
```

### Complex Object Creation
```dart
// ❌ NOT SUPPORTED
@Worklet
MyClass createObject() {
  return MyClass();  // ❌ No custom object creation
}
```

### External Function Calls
```dart
// ❌ NOT SUPPORTED
@Worklet
double callExternal() {
  return myHelperFunction();  // ❌ No external function calls
}
```

### Try/Catch
```dart
// ❌ NOT SUPPORTED
@Worklet
double safeDivide(double a, double b) {
  try {  // ❌ No try/catch
    return a / b;
  } catch (e) {
    return 0;
  }
}
```

## Examples

### ✅ Valid Worklets

```dart
// Simple math
@Worklet
double doubleValue(double x) => x * 2;

// Complex calculation
@Worklet
double elasticBounce(double time, double damping, double frequency) {
  return Math.sin(time * frequency) * Math.exp(-time * damping);
}

// String manipulation
@Worklet
String typewriter(double elapsed, List<String> words, double speed) {
  final totalTime = elapsed * speed;
  final wordIndex = (totalTime / 2.0).floor() % words.length;
  final charIndex = ((totalTime % 2.0) * 10).floor();
  final word = words[wordIndex];
  return word.substring(0, charIndex.clamp(0, word.length));
}

// Conditional logic
@Worklet
double pulse(double time) {
  return time % 2.0 < 1.0 ? Math.sin(time * Math.PI) : 0;
}

// List operations
@Worklet
String getItem(double index, List<String> items) {
  final idx = index.floor() % items.length;
  return items[idx];
}
```

## Performance

All supported operations compile to **pure native code** (Kotlin/Swift) that runs directly on the UI thread with:
- ✅ Zero bridge calls
- ✅ 60fps guaranteed
- ✅ Cannot be blocked by Dart thread
- ✅ Optimized by native compilers

## Migration Guide

If your worklet uses unsupported operations:

1. **Loops** → Convert to native functions or recursive patterns
2. **Complex objects** → Use primitives (double, int, String, List, Map)
3. **External functions** → Inline the logic or use native equivalents
4. **Async/I/O** → Pre-compute values and pass as parameters

## Summary

Worklets support **~80% of common Dart patterns** used in animations and calculations, while maintaining UI-thread safety and zero-overhead performance.

