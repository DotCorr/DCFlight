/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import 'worklet_compiler.dart';

/// Runtime registry for compiled worklets
/// Maps worklet IDs to their compiled native code
class WorkletRegistry {
  static final WorkletRegistry _instance = WorkletRegistry._internal();
  factory WorkletRegistry() => _instance;
  WorkletRegistry._internal();

  final Map<String, CompilationResult> _compiledWorklets = {};
  final Map<String, Function> _workletFunctions = {};

  /// Register a worklet function
  String register(Function worklet) {
    final workletId = _generateWorkletId(worklet);
    
    if (!_compiledWorklets.containsKey(workletId)) {
      // Compile the worklet
      final result = WorkletCompiler.compile(worklet);
      _compiledWorklets[workletId] = result;
      _workletFunctions[workletId] = worklet;
    }
    
    return workletId;
  }

  /// Get compilation result for a worklet ID
  CompilationResult? getCompilationResult(String workletId) {
    return _compiledWorklets[workletId];
  }

  /// Get the original worklet function
  Function? getWorkletFunction(String workletId) {
    return _workletFunctions[workletId];
  }

  /// Check if a worklet is compiled
  bool isCompiled(String workletId) {
    return _compiledWorklets.containsKey(workletId) &&
        _compiledWorklets[workletId]!.success;
  }

  /// Get all compiled worklet IDs
  List<String> getCompiledWorkletIds() {
    return _compiledWorklets.keys.where((id) => isCompiled(id)).toList();
  }

  /// Generate a unique ID for a worklet function
  String _generateWorkletId(Function worklet) {
    // Use function name and hash code
    final functionString = worklet.toString();
    final hash = functionString.hashCode;
    final nameMatch = RegExp(r'(\w+)\s*\([^)]*\)').firstMatch(functionString);
    final name = nameMatch?.group(1) ?? 'worklet';
    return '${name}_$hash';
  }

  /// Clear all registered worklets
  void clear() {
    _compiledWorklets.clear();
    _workletFunctions.clear();
  }
}

