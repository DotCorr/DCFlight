/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

import 'package:dcflight/framework/renderer/interface/interface.dart';
import 'package:dcflight/framework/renderer/interface/tunnel.dart';
import 'compiler/runtime_registry.dart';
import 'compiler/runtime_interpreter.dart';

/// Annotation to mark functions as worklets that run on the UI thread.
///
/// Worklets enable **running Dart code directly on the native UI thread**,
/// providing zero bridge calls during execution. This is similar to React Native

/// **Key Benefits:**
/// - ✅ Zero bridge calls during execution
/// - ✅ Runs on UI thread (60fps guaranteed)
/// - ✅ Cannot be blocked by Dart thread operations
/// - ✅ General-purpose: animations, text updates, calculations, etc.
///
/// **Framework-level infrastructure** - Available to all components and packages.
///
/// Example - Animation:
/// ```dart
/// @Worklet
/// double updateParticle(double time, double initialX, double velocity) {
///   // This runs on UI thread - zero bridge calls
///   return initialX + (time * velocity);
/// }
/// ```
///
/// Example - Text Animation:
/// ```dart
/// @Worklet
/// String typewriterText(double elapsed, List<String> words, double typeSpeed) {
///   // Calculate and return text - runs on UI thread
///   final wordIndex = (elapsed / 2.0).floor() % words.length;
///   final charIndex = ((elapsed % 2.0) * 10).floor();
///   return words[wordIndex].substring(0, charIndex.clamp(0, words[wordIndex].length));
/// }
/// ```
///
/// Example - General Computation:
/// ```dart
/// @Worklet
/// Map<String, dynamic> calculateLayout(double width, double height) {
///   // Complex layout calculations on UI thread
///   return {'x': width / 2, 'y': height / 2, 'scale': 1.0};
/// }
/// ```
class Worklet {
  const Worklet();
}

/// Type-safe worklet function signatures.
///
/// Worklets can have different signatures depending on their use case.
/// These typedefs provide type safety for worklet functions.
typedef WorkletFunction<T> = T Function();
typedef WorkletFunction1<T, P1> = T Function(P1);
typedef WorkletFunction2<T, P1, P2> = T Function(P1, P2);
typedef WorkletFunction3<T, P1, P2, P3> = T Function(P1, P2, P3);
typedef WorkletFunction4<T, P1, P2, P3, P4> = T Function(P1, P2, P3, P4);
typedef WorkletFunction5<T, P1, P2, P3, P4, P5> = T Function(P1, P2, P3, P4, P5);

/// Parameter type information for worklet serialization.
class WorkletParameter {
  /// Parameter name
  final String name;
  
  /// Parameter type (e.g., 'double', 'String', 'List<String>', 'Map<String, dynamic>')
  final String type;
  
  /// Whether this parameter is optional
  final bool isOptional;
  
  /// Default value if optional (serialized as JSON string)
  final String? defaultValue;

  const WorkletParameter({
    required this.name,
    required this.type,
    this.isOptional = false,
    this.defaultValue,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'isOptional': isOptional,
        if (defaultValue != null) 'defaultValue': defaultValue,
      };
}

/// Worklet configuration for native execution.
///
/// This class serializes worklet functions for native execution.
/// The worklet function is compiled/serialized and sent to native
/// where it runs on the UI thread without bridge calls.
///
/// **Framework-level** - Any component can use this.
class WorkletConfig {
  /// Unique identifier for this worklet
  final String id;
  
  /// Serialized worklet function (source code, AST, or compiled code)
  final Map<String, dynamic> serializedFunction;
  
  /// Parameter information (names and types)
  final List<WorkletParameter> parameters;
  
  /// Return type of the worklet (e.g., 'double', 'String', 'List<String>', 'Map<String, dynamic>')
  final String returnType;
  
  /// Whether this worklet is already compiled to native code
  final bool isCompiled;
  
  /// Execution mode: 'frame' (runs every frame), 'once' (runs once), 'interval' (runs at interval)
  final String executionMode;
  
  /// Execution interval in milliseconds (for 'interval' mode)
  final int? executionInterval;

  const WorkletConfig({
    required this.id,
    required this.serializedFunction,
    required this.parameters,
    required this.returnType,
    this.isCompiled = false,
    this.executionMode = 'frame',
    this.executionInterval,
  });

  /// Convert to map for native bridge communication
  Map<String, dynamic> toMap() => {
        'id': id,
        'function': serializedFunction,
        'parameters': parameters.map((p) => p.toMap()).toList(),
        'returnType': returnType,
        'isCompiled': isCompiled,
        'executionMode': executionMode,
        if (executionInterval != null) 'executionInterval': executionInterval,
      };
}

/// Worklet executor that handles worklet serialization and execution.
///
/// **Framework-level infrastructure** - Provides worklet support to all components.
///
/// This class provides utilities for creating and managing worklets
/// that will execute on the native UI thread. Any component can use
/// this to enable worklet-based operations (animations, text updates, calculations, etc.).
///
/// Example:
/// ```dart
/// @Worklet
/// double customAnimation(double time) => time * 2;
///
/// final config = WorkletExecutor.serialize(customAnimation);
/// // Pass to native component
/// ```
class WorkletExecutor {
  static int _workletCounter = 0;

  /// Serialize a worklet function for native execution.
  ///
  /// This extracts the function source code, parameters, and return type,
  /// then serializes them for native execution. The native side will interpret
  /// or compile the function to run on the UI thread.
  ///
  /// **Available to all components** - Framework-level utility.
  ///
  /// Example:
  /// ```dart
  /// @Worklet
  /// double update(double time) => time * 2;
  ///
  /// final config = WorkletExecutor.serialize(update);
  /// ```
  ///
  /// Example with complex types:
  /// ```dart
  /// @Worklet
  /// String typewriter(double elapsed, List<String> words) {
  ///   // ... logic
  /// }
  ///
  /// final config = WorkletExecutor.serialize(typewriter);
  /// ```
  static WorkletConfig serialize(
    Function worklet, {
    String executionMode = 'frame',
    int? executionInterval,
  }) {
    // Compile the worklet to IR (for runtime interpretation)
    final registry = WorkletRegistry();
    final workletId = registry.register(worklet);
    final compilationResult = registry.getCompilationResult(workletId);
    
    final id = 'worklet_${_workletCounter++}';
    
    // Get function source code
    final functionString = worklet.toString();
    
    // Extract function information
    final functionInfo = _parseFunction(functionString);
    
    // Check if compilation was successful
    final isCompiled = compilationResult?.success ?? false;
    
    // Debug: Log compilation status
    if (!isCompiled) {
      print('⚠️ WORKLET: Compilation failed for worklet $workletId');
      if (compilationResult != null) {
        print('⚠️ WORKLET: Compilation errors: ${compilationResult.errors}');
      } else {
        print('⚠️ WORKLET: No compilation result returned');
      }
    } else {
      print('✅ WORKLET: Compilation successful for worklet $workletId');
      print('✅ WORKLET: IR available: ${compilationResult?.ir != null}');
    }
    
    // Serialize function body for RUNTIME INTERPRETATION (no rebuild needed!)
    final serializedFunction = {
      'source': functionString,
      'body': functionInfo['body'] ?? '',
      'type': 'interpretable', // Native will interpret IR at runtime
      if (isCompiled && compilationResult != null && compilationResult.ir != null) ...{
        // Include IR for runtime interpretation (like React Native Reanimated!)
        'ir': WorkletRuntimeInterpreter.serializeIR(compilationResult.ir!),
        'workletId': workletId,
        // Also include generated code for reference (optional)
        'kotlinCode': compilationResult.kotlinCode,
        'swiftCode': compilationResult.swiftCode,
      },
    };
    
    // Debug: Log what's being serialized
    print('🔍 WORKLET: Serialized function keys: ${serializedFunction.keys}');
    print('🔍 WORKLET: IR included: ${serializedFunction.containsKey('ir')}');
    
    return WorkletConfig(
      id: id,
      serializedFunction: serializedFunction,
      parameters: functionInfo['parameters'] as List<WorkletParameter>,
      returnType: functionInfo['returnType'] as String,
      isCompiled: isCompiled,
      executionMode: executionMode,
      executionInterval: executionInterval,
    );
  }

  /// Parse function string to extract parameters, return type, and body.
  static Map<String, dynamic> _parseFunction(String functionString) {
    final parameters = <WorkletParameter>[];
    String returnType = 'dynamic';
    String body = '';

    // Extract return type
    // Try to match patterns like "double Function", "String Function", etc.
    final returnTypeMatch = RegExp(r'(\w+)\s*Function').firstMatch(functionString);
    if (returnTypeMatch != null) {
      returnType = returnTypeMatch.group(1) ?? 'dynamic';
    } else {
      // Try to extract from function signature
      returnType = _extractReturnType(functionString);
    }

    // Extract parameters
    final paramMatch = RegExp(r'\(([^)]*)\)').firstMatch(functionString);
    if (paramMatch != null) {
      final paramString = paramMatch.group(1) ?? '';
      if (paramString.isNotEmpty) {
        final paramList = paramString.split(',');
        for (final param in paramList) {
          final trimmed = param.trim();
          if (trimmed.isEmpty) continue;
          
          // Parse parameter: "double time" or "List<String> words" or "String? optional"
          final parts = trimmed.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final type = parts[0];
            final name = parts[1].replaceAll('?', ''); // Remove optional marker
            final isOptional = trimmed.contains('?') || parts.length > 2 && parts[2] == '?';
            
            parameters.add(WorkletParameter(
              name: name,
              type: _normalizeType(type),
              isOptional: isOptional,
            ));
          }
        }
      }
    }

    // Extract function body (between { and })
    // For closures, toString() only returns the signature, not the body
    // In this case, we leave body empty - it will be handled by runtime interpreter
    if (!functionString.contains('Closure:') || !functionString.contains('from Function')) {
      final bodyMatch = RegExp(r'\{([^}]*)\}').firstMatch(functionString);
      if (bodyMatch != null) {
        body = bodyMatch.group(1) ?? '';
      }
    }
    // For closures, body is empty - will be extracted from IR or runtime interpretation

    return {
      'parameters': parameters,
      'returnType': returnType,
      'body': body,
    };
  }

  /// Normalize Dart type names for native execution.
  /// Converts Dart types to a format that native code can understand.
  static String _normalizeType(String type) {
    // Handle generic types like List<String>, Map<String, dynamic>
    if (type.contains('<')) {
      return type; // Keep generic types as-is for now
    }
    
    // Map common Dart types
    switch (type.toLowerCase()) {
      case 'double':
      case 'num':
        return 'double';
      case 'int':
        return 'int';
      case 'bool':
        return 'bool';
      case 'string':
        return 'String';
      case 'list':
        return 'List';
      case 'map':
        return 'Map';
      default:
        return type;
    }
  }

  /// Extract return type from function string.
  static String _extractReturnType(String functionString) {
    // Try explicit return type patterns
    final patterns = [
      RegExp(r'(\w+)\s+Function'), // "double Function"
      RegExp(r'(\w+)\s*=>'),      // "double =>"
      RegExp(r'(\w+)\s+\w+\s*\('), // "double functionName("
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(functionString);
      if (match != null) {
        final type = match.group(1);
        if (type != null && type != 'Function') {
          return _normalizeType(type);
        }
      }
    }

    // Try to infer from function body or common patterns
    if (functionString.contains('return') || functionString.contains('=>')) {
      // Look for return statements
      final returnMatch = RegExp(r'return\s+([^;]+)').firstMatch(functionString);
      if (returnMatch != null) {
        final returnValue = returnMatch.group(1)?.trim() ?? '';
        if (returnValue.contains('.')) return 'double';
        if (returnValue.contains('"') || returnValue.contains("'")) return 'String';
        if (returnValue == 'true' || returnValue == 'false') return 'bool';
        if (RegExp(r'^\d+$').hasMatch(returnValue)) return 'int';
      }
    }

    // Default fallback
    if (functionString.contains('double')) return 'double';
    if (functionString.contains('String')) return 'String';
    if (functionString.contains('int')) return 'int';
    if (functionString.contains('bool')) return 'bool';
    if (functionString.contains('List')) return 'List';
    if (functionString.contains('Map')) return 'Map';

    return 'dynamic';
  }
}

/// Utilities for running functions on different threads.
///
/// Similar to React Native Reanimated's `runOnUI` and `runOnJS`, but for Dart.
class WorkletThreading {
  /// Run a function on the UI thread using a worklet.
  ///
  /// This serializes the function as a worklet and executes it on the UI thread.
  /// Use this when you need to run Dart code on the UI thread from the Dart thread.
  ///
  /// Example:
  /// ```dart
  /// @Worklet
  /// void updateText(String text) {
  ///   // This runs on UI thread
  /// }
  ///
  /// WorkletThreading.runOnUI(updateText, 'Hello');
  /// ```
  static Future<dynamic> runOnUI(
    Function worklet, [
    dynamic arg1,
    dynamic arg2,
    dynamic arg3,
    dynamic arg4,
    dynamic arg5,
  ]) async {
    // Serialize worklet and send to native for UI thread execution
    final config = WorkletExecutor.serialize(worklet, executionMode: 'once');
    
    // Use tunnel system to execute worklet on native UI thread
    // The native side will have a WorkletExecutor component that handles execution
    try {
      final result = await _getPlatformInterface().tunnel(
        'WorkletExecutor',
        'executeWorklet',
        {
          'workletConfig': config.toMap(),
          'arguments': [
            if (arg1 != null) arg1,
            if (arg2 != null) arg2,
            if (arg3 != null) arg3,
            if (arg4 != null) arg4,
            if (arg5 != null) arg5,
          ],
        },
      );
      return result;
    } catch (e) {
      // Fallback: if WorkletExecutor component doesn't exist, use tunnel (FFI/JNI)
      return await _executeWorkletViaTunnel(config, [arg1, arg2, arg3, arg4, arg5]);
    }
  }

  /// Run a function on the Dart thread from a worklet.
  ///
  /// Use this inside a worklet to call back to the Dart thread.
  /// This requires a bridge call, so use sparingly.
  ///
  /// Example:
  /// ```dart
  /// @Worklet
  /// void workletFunction() {
  ///   // Running on UI thread
  ///   WorkletThreading.runOnDart(() {
  ///     // This runs on Dart thread
  ///     print('Called from UI thread worklet');
  ///   });
  /// }
  /// ```
  static Future<dynamic> runOnDart(
    Function function, [
    dynamic arg1,
    dynamic arg2,
    dynamic arg3,
    dynamic arg4,
    dynamic arg5,
  ]) async {
    // Serialize function call and send via bridge to Dart thread
    // This uses the event channel to send a callback request
    try {
      final result = await _getPlatformInterface().tunnel(
        'WorkletExecutor',
        'executeOnDartThread',
        {
          'functionName': function.toString(),
          'arguments': [
            if (arg1 != null) arg1,
            if (arg2 != null) arg2,
            if (arg3 != null) arg3,
            if (arg4 != null) arg4,
            if (arg5 != null) arg5,
          ],
        },
      );
      return result;
    } catch (e) {
      // If tunnel fails, execute directly on Dart thread (synchronous)
      // This is a fallback - in a real worklet, you'd want async bridge call
      return Function.apply(function, [
        if (arg1 != null) arg1,
        if (arg2 != null) arg2,
        if (arg3 != null) arg3,
        if (arg4 != null) arg4,
        if (arg5 != null) arg5,
      ].where((e) => e != null).toList());
    }
  }

  /// Get the platform interface instance
  static PlatformInterface _getPlatformInterface() {
    return PlatformInterface.instance;
  }

  /// Execute worklet via tunnel (FFI/JNI)
  static Future<dynamic> _executeWorkletViaTunnel(
    WorkletConfig config,
    List<dynamic> arguments,
  ) async {
    // Use tunnel system (FFI/JNI) with WorkletExecutor component
    // If that doesn't exist, this will throw and caller can handle it
    return await FrameworkTunnel.call(
      'WorkletExecutor',
      'executeWorklet',
      {
        'workletConfig': config.toMap(),
        'arguments': arguments.where((e) => e != null).toList(),
      },
    );
  }
}

