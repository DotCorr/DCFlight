# DCFlight Architecture: Pure Signals

## One API: `signal()` for Everything

DCFlight uses **pure signals** like SolidJS/Angular - the engine automatically optimizes.

```dart
final count = signal(0);
final showMenu = signal(false);

DCFView(
  children: [
    // Signal in prop → direct native update
    DCFText(content: () => "Count: ${count()}"),
    
    // Signal in structure → smart reconciliation
    if (showMenu()) Menu(),
  ],
)
```

**Developer doesn't think about optimization - engine handles it automatically!**

## How It Works

### Signal in Props → Direct Updates (< 1ms)
```dart
DCFText(
  content: () => "Count: ${count()}",  // Function reads signal
)
```

1. Engine calls function during initial render
2. Tracks: signal was read
3. Subscribes text view to signal
4. **`count.set(1)` → `updateView()` directly on text node**
5. NO component re-render!

**Performance:** < 1ms latency, 1000s updates/second

### Signal in Structure → Reconciliation (~5ms)
```dart
if (showMenu()) Menu()  // Reading signal during render
```

1. Signal read during `component.render()`
2. Component subscribes to signal
3. **`showMenu.set(true)` → `component.scheduleUpdate()`**
4. Re-render + smart reconciliation (reuses unchanged views)

**Performance:** ~5-10ms latency, still very fast

## API Reference

### Create Signal
```dart
final count = signal(0);
final name = signal("World");
```

### Read Signal
```dart
// In props (auto-subscribes view)
content: () => "Count: ${count()}"

// In structure (auto-subscribes component)
if (count() > 10) BigNumber()

// Get value without tracking
final value = count.value;  // For logging, debugging
```

### Update Signal
```dart
count.set(5);           // Set directly
count.update((v) => v + 1);  // Update based on old value
```

### Computed Signals
```dart
final doubled = computed(() => count() * 2);
// Auto-updates when count changes
```

### Effects
```dart
effect(() {
  print('Count changed to: ${count()}');
  // Runs automatically when count changes
});
```

## Comparison to Other Frameworks

| Framework | API | DCFlight |
|-----------|-----|----------|
| **SolidJS** | `createSignal()` | ✅ `signal()` - same! |
| **Angular** | `signal()` | ✅ `signal()` - same! |
| **React** | `useState()` | ⚠️ Different (always re-renders) |
| **Vue** | `ref()` / `reactive()` | ✅ Similar to `signal()` |

## Migration from useState

```dart
// Old way (still works)
final count = useState(0);
count.setState(count.state + 1);

// New way (recommended)
final count = signal(0);
count.set(count() + 1);
```

**`useState` is kept for backward compatibility but just wraps `signal()` internally.**

## Performance Characteristics

### Direct Updates (Signal in Props)
- **Latency:** < 1ms
- **Throughput:** 1000s of updates/second  
- **Memory:** O(1) per signal
- **Use for:** Text, colors, numbers, animations, user input

### Reconciliation (Signal in Structure)
- **Latency:** ~5-10ms
- **Throughput:** 100s of updates/second
- **Memory:** O(n) for tree nodes
- **Use for:** Adding/removing children, conditional rendering, navigation

But you don't think about this - engine picks automatically!

## Why This Architecture?

1. **Simple Mental Model**
   - ONE API: `signal()`
   - Engine optimizes automatically
   - No cognitive overhead

2. **Best Performance**
   - Direct updates when possible
   - Smart reconciliation when needed
   - Developer doesn't choose

3. **Industry Standard**
   - Same as SolidJS
   - Same as Angular
   - Proven approach

## Example

```dart
class MyApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    // All state is signals
    final count = signal(0);
    final name = signal("World");
    final showDetails = signal(false);
    
    // Computed values
    final doubled = computed(() => count() * 2);
    final greeting = computed(() => "Hello, ${name()}!");
    
    return DCFView(
      children: [
        // Direct updates
        DCFText(content: () => greeting()),
        DCFText(content: () => "Count: ${count()} (x2 = ${doubled()})"),
        
        // Event handlers
        DCFButton(
          onPress: () => count.set(count() + 1),
          child: DCFText(content: "Increment"),
        ),
        
        // Conditional rendering (reconciliation)
        if (showDetails())
          DetailsPanel(),
        
        DCFButton(
          onPress: () => showDetails.set(!showDetails()),
          child: DCFText(
            content: () => showDetails() ? "Hide" : "Show",
          ),
        ),
      ],
    );
  }
}
```

---

**The Rule:** Use `signal()` for everything. Engine handles the rest.
