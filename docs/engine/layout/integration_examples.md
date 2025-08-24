# UseWebDefaults Integration Examples

## Basic Integration

### App Initialization
```dart
import 'package:dcflight/dcflight.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable web defaults before starting DCFlight
  await LayoutConfig.enableWebDefaults();
  
  await DCFlight.start(app: MyApp());
}
```

### Feature Flag Integration
```dart
class FeatureFlags {
  static bool get useWebCompatibleLayouts => 
    Platform.isAndroid || Platform.isIOS || kIsWeb;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (FeatureFlags.useWebCompatibleLayouts) {
    await LayoutConfig.enableWebDefaults();
  }
  
  await DCFlight.start(app: MyApp());
}
```

## Layout Comparisons

### Before UseWebDefaults (Yoga Native)
```dart
DCFView(
  style: {
    'display': 'flex',
    // Implicit: flex-direction: 'column'
    // Implicit: align-content: 'flex-start'  
    // Implicit: flex-shrink: 0
  },
  children: [
    DCFText('Item 1'),
    DCFText('Item 2'),
    DCFText('Item 3'),
  ],
)
// Result: Vertical stack, items don't shrink
```

### After UseWebDefaults (Web Compatible)
```dart
DCFView(
  style: {
    'display': 'flex',
    // Implicit: flex-direction: 'row'
    // Implicit: align-content: 'stretch'
    // Implicit: flex-shrink: 1
  },
  children: [
    DCFText('Item 1'),
    DCFText('Item 2'),  
    DCFText('Item 3'),
  ],
)
// Result: Horizontal row, items can shrink
```

## Migration Patterns

### Explicit Layout (Recommended)
```dart
// Always specify layout explicitly to avoid surprises
DCFView(
  style: {
    'display': 'flex',
    'flex-direction': 'column', // Explicit direction
    'align-content': 'flex-start', // Explicit alignment
    'flex-shrink': 0, // Explicit shrink behavior
  },
  children: [...],
)
```

### Conditional Layout
```dart
DCFView(
  style: {
    'display': 'flex',
    'flex-direction': LayoutConfig.isWebDefaultsEnabled() 
      ? 'column'  // Override web default
      : 'row',    // Override yoga default
  },
  children: [...],
)
```

### CSS-to-DCFLight Migration
```css
/* Original CSS */
.container {
  display: flex;
  flex-direction: row;
  align-content: stretch;
  flex-shrink: 1;
}
```

```dart
// DCFlight with UseWebDefaults enabled
DCFView(
  style: {
    'display': 'flex',
    // All defaults now match CSS!
    // No need to specify: flex-direction, align-content, flex-shrink
  },
  children: [...],
)
```

## Testing Strategies

### Unit Testing Layout
```dart
testWidgets('Layout behaves consistently with web defaults', (tester) async {
  // Enable web defaults for test
  await LayoutConfig.enableWebDefaults();
  
  await tester.pumpWidget(MyLayout());
  
  // Test layout behavior
  expect(find.text('Item 1'), isHorizontallyAlignedWith(find.text('Item 2')));
});
```

### Integration Testing
```dart
group('Cross-platform layout consistency', () {
  setUp(() async {
    await LayoutConfig.enableWebDefaults();
  });
  
  testWidgets('Layout matches web behavior', (tester) async {
    // Test web-compatible layout behavior
  });
});
```

## Performance Considerations

### Initialization Timing
```dart
// ✅ Good: Enable before any views are created
void main() async {
  await LayoutConfig.enableWebDefaults();
  await DCFlight.start(app: MyApp());
}

// ❌ Bad: Changing after views exist may cause layout jumps  
void switchLayoutMode() async {
  await LayoutConfig.enableWebDefaults(); // May cause relayout
}
```

### Selective Usage
```dart
// For performance-critical sections, consider explicit properties
// instead of relying on global defaults
DCFView(
  style: {
    'display': 'flex',
    'flex-direction': 'column', // Explicit for performance
  },
  children: performanceCriticalContent,
)
```

## Debugging Tips

### Layout Debugging
```dart
// Enable detailed logging
DCFlight.setLogLevel(DCFLogLevel.debug);

// Check current defaults state
print('Web defaults enabled: ${LayoutConfig.isWebDefaultsEnabled()}');

// Use explicit properties while debugging
DCFView(
  style: {
    'display': 'flex',
    'flex-direction': 'row', // Make layout intention explicit
    'background-color': 'red', // Visual debugging
  },
  children: [...],
)
```

### Common Issues
1. **Layout jumps on enable**: Enable UseWebDefaults before creating any views
2. **Unexpected wrapping**: flex-shrink changes from 0→1, items now shrink
3. **Direction confusion**: flex-direction changes from column→row by default
4. **Alignment differences**: align-content changes from flex-start→stretch

## Best Practices Summary

1. **Enable early**: Set UseWebDefaults during app initialization
2. **Be explicit**: Specify layout properties explicitly for complex layouts
3. **Test thoroughly**: Layout behavior changes can be subtle
4. **Document choice**: Make UseWebDefaults decision explicit in project docs
5. **Gradual adoption**: Consider feature flags for gradual rollout
