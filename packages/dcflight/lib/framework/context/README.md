# DCFlight Context API

A React Context-like API for DCFlight that allows you to share values across the component tree without prop drilling.

## Usage

### 1. Create a Context

```dart
import 'package:dcflight/dcflight.dart';

// Create a context with an optional default value
final ThemeContext = createContext<Theme>(defaultValue: Theme.light);
final UserContext = createContext<User?>();
```

### 2. Provide a Context Value

Use `DCFContextProvider` to make a value available to all descendant components:

```dart
class App extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFContextProvider(
      context: ThemeContext,
      value: Theme.dark,
      child: MyComponent(),
    );
  }
}
```

### 3. Consume a Context Value

Use `useContext()` hook to access the context value:

```dart
class MyComponent extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final theme = useContext(ThemeContext);
    return DCFText(text: 'Current theme: ${theme.name}');
  }
}
```

## Complete Example

```dart
import 'package:dcflight/dcflight.dart';

// Define your context
final ThemeContext = createContext<Theme>(defaultValue: Theme.light);

// Theme class
class Theme {
  final String name;
  final String backgroundColor;
  final String textColor;
  
  Theme({required this.name, required this.backgroundColor, required this.textColor});
  
  static final light = Theme(
    name: 'light',
    backgroundColor: '#FFFFFF',
    textColor: '#000000',
  );
  
  static final dark = Theme(
    name: 'dark',
    backgroundColor: '#000000',
    textColor: '#FFFFFF',
  );
}

// App component that provides the theme
class App extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    return DCFContextProvider(
      context: ThemeContext,
      value: Theme.dark,
      child: MyComponent(),
    );
  }
}

// Component that consumes the theme
class MyComponent extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final theme = useContext(ThemeContext);
    return DCFView(
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFColors.fromHex(theme.backgroundColor),
      ),
      children: [
        DCFText(
          text: 'Current theme: ${theme.name}',
          styleSheet: DCFStyleSheet(
            color: DCFColors.fromHex(theme.textColor),
          ),
        ),
      ],
    );
  }
}
```

## Features

- ✅ **Scoped Values**: Different values can be provided at different levels of the tree
- ✅ **Default Values**: Optional default values when no provider is found
- ✅ **Type Safe**: Full type safety with generics
- ✅ **No Prop Drilling**: Avoid passing props through many component levels

## When to Use Context vs Store

- **Use Context** when:
  - You need scoped values (different values in different parts of the tree)
  - You want to avoid prop drilling
  - The value is configuration/theme-related

- **Use Store** when:
  - You need global state accessible from anywhere
  - The state needs to persist across component trees
  - You need reactive updates across the entire app










