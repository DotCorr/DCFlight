/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

/// A Context object created by createContext.
/// 
/// Every Context object comes with a Provider component that allows
/// consuming components to subscribe to context changes.
/// 
/// Similar to React's Context API: https://reactjs.org/docs/context.html
class DCFContext<T> {
  /// The default value provided to createContext
  final T? defaultValue;
  
  /// Unique identifier for this context
  final String _id;
  
  /// Create a new context
  DCFContext._(this.defaultValue, this._id);
  
  /// Create a context with an optional default value
  /// 
  /// Example:
  /// ```dart
  /// final ThemeContext = createContext<Theme>(defaultValue: Theme.light);
  /// ```
  factory DCFContext.create({T? defaultValue}) {
    final id = 'context_${DateTime.now().millisecondsSinceEpoch}_${Object().hashCode}';
    return DCFContext<T>._(defaultValue, id);
  }
  
  @override
  String toString() => 'DCFContext<$T>(id: $_id)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DCFContext<T> && runtimeType == other.runtimeType && _id == other._id;
  
  @override
  int get hashCode => _id.hashCode;
}

/// Create a new context with an optional default value
/// 
/// Example:
/// ```dart
/// final ThemeContext = createContext<Theme>(defaultValue: Theme.light);
/// 
/// class MyApp extends DCFStatefulComponent {
///   @override
///   DCFComponentNode render() {
///     return DCFContextProvider(
///       context: ThemeContext,
///       value: Theme.dark,
///       child: MyComponent(),
///     );
///   }
/// }
/// 
/// class MyComponent extends DCFStatefulComponent {
///   @override
///   DCFComponentNode render() {
///     final theme = useContext(ThemeContext);
///     return DCFText(text: 'Current theme: ${theme.name}');
///   }
/// }
/// ```
DCFContext<T> createContext<T>({T? defaultValue}) {
  return DCFContext<T>.create(defaultValue: defaultValue);
}

