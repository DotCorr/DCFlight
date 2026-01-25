/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:dcflight/dcflight.dart';


/// Provider component that makes a context value available to all
/// descendant components.
/// 
/// Example:
/// ```dart
/// final ThemeContext = createContext<Theme>();
/// 
/// class App extends DCFStatefulComponent {
///   @override
///   DCFComponentNode render() {
///     return DCFContextProvider(
///       context: ThemeContext,
///       value: Theme.dark,
///       child: MyComponent(),
///     );
///   }
/// }
/// ```
class DCFContextProvider<T> extends DCFStatelessComponent {
  /// The context to provide
  final DCFContext<T> context;
  
  /// The value to provide to descendants
  final T value;
  
  /// Child components that can consume this context
  final DCFComponentNode child;
  
  DCFContextProvider({
    required this.context,
    required this.value,
    required this.child,
    super.key,
  }) {
    child.parent = this;
  }
  
  @override
  DCFComponentNode render() {
    return child;
  }
}

