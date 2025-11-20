/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

/// Annotation to mark functions as worklets that run on the UI thread.
///
/// Worklets are functions that execute entirely on the native UI thread,
/// providing zero bridge calls during animation execution. This enables
/// smooth 60fps animations even when the Dart thread is busy.
///
/// Example:
/// ```dart
/// @Worklet
/// double updateParticle(double time, double initialX, double velocity) {
///   // This runs on UI thread - zero bridge calls
///   return initialX + (time * velocity);
/// }
/// ```
class Worklet {
  const Worklet();
}

/// Type-safe worklet function signature.
///
/// Worklets can have different signatures depending on their use case.
/// This typedef provides type safety for worklet functions.
///
/// Example:
/// ```dart
/// @Worklet
/// double particleUpdate(double time, double initialX) {
///   return initialX + (time * 50);
/// }
///
/// WorkletFunction<double> worklet = particleUpdate;
/// ```
typedef WorkletFunction<T> = T Function();

/// Worklet function with one parameter.
typedef WorkletFunction1<T, P1> = T Function(P1);

/// Worklet function with two parameters.
typedef WorkletFunction2<T, P1, P2> = T Function(P1, P2);

/// Worklet function with three parameters.
typedef WorkletFunction3<T, P1, P2, P3> = T Function(P1, P2, P3);

/// Worklet function with four parameters.
typedef WorkletFunction4<T, P1, P2, P3, P4> = T Function(P1, P2, P3, P4);

/// Worklet configuration for native execution.
///
/// This class serializes worklet functions for native execution.
/// The worklet function is compiled/serialized and sent to native
/// where it runs on the UI thread without bridge calls.
class WorkletConfig {
  /// Unique identifier for this worklet
  final String id;
  
  /// Serialized worklet function (AST or compiled code)
  final Map<String, dynamic> serializedFunction;
  
  /// Parameter names for the worklet function
  final List<String> parameterNames;
  
  /// Return type of the worklet
  final String returnType;
  
  /// Whether this worklet is already compiled
  final bool isCompiled;

  const WorkletConfig({
    required this.id,
    required this.serializedFunction,
    required this.parameterNames,
    required this.returnType,
    this.isCompiled = false,
  });

  /// Convert to map for native bridge communication
  Map<String, dynamic> toMap() => {
        'id': id,
        'function': serializedFunction,
        'parameterNames': parameterNames,
        'returnType': returnType,
        'isCompiled': isCompiled,
      };
}

/// Worklet executor that handles worklet serialization and execution.
///
/// This class provides utilities for creating and managing worklets
/// that will execute on the native UI thread.
class WorkletExecutor {
  static int _workletCounter = 0;

  /// Serialize a worklet function for native execution.
  ///
  /// Currently uses a simple serialization approach. In a production
  /// implementation, this would compile the function to native code
  /// or serialize the AST for native interpretation.
  ///
  /// Example:
  /// ```dart
  /// @Worklet
  /// double update(double time) => time * 2;
  ///
  /// final config = WorkletExecutor.serialize(update);
  /// ```
  static WorkletConfig serialize(Function worklet) {
    final id = 'worklet_${_workletCounter++}';
    
    // Get function source code (simplified - in production would use mirrors/reflection)
    final functionString = worklet.toString();
    
    // Extract parameter names and return type (simplified parsing)
    final parameterNames = _extractParameterNames(functionString);
    final returnType = _extractReturnType(functionString);
    
    // Serialize function body (in production, this would be AST or compiled code)
    final serializedFunction = {
      'source': functionString,
      'type': 'dart_function', // In production: 'compiled' or 'ast'
    };
    
    return WorkletConfig(
      id: id,
      serializedFunction: serializedFunction,
      parameterNames: parameterNames,
      returnType: returnType,
      isCompiled: false,
    );
  }

  /// Extract parameter names from function string (simplified).
  static List<String> _extractParameterNames(String functionString) {
    // This is a simplified parser - in production would use proper AST parsing
    final paramMatch = RegExp(r'\(([^)]*)\)').firstMatch(functionString);
    if (paramMatch == null) return [];
    
    final params = paramMatch.group(1)?.split(',') ?? [];
    return params.map((p) => p.trim().split(' ').last).toList();
  }

  /// Extract return type from function string (simplified).
  static String _extractReturnType(String functionString) {
    // This is a simplified parser - in production would use proper AST parsing
    final returnMatch = RegExp(r'(\w+)\s*Function').firstMatch(functionString);
    if (returnMatch != null) {
      return returnMatch.group(1) ?? 'dynamic';
    }
    
    // Try to extract from function signature
    if (functionString.contains('double')) return 'double';
    if (functionString.contains('int')) return 'int';
    if (functionString.contains('bool')) return 'bool';
    if (functionString.contains('String')) return 'String';
    
    return 'dynamic';
  }
}

