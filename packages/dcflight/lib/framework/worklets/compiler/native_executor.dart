/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

/// Helper class for native code to execute compiled worklets
/// 
/// This provides the interface that native code should use to call
/// generated worklet functions. The actual implementation is in native code.
class WorkletNativeExecutor {
  /// Execute a compiled worklet by ID
  /// 
  /// Native code should implement this to call the generated function
  /// from GeneratedWorklets object/enum.
  /// 
  /// Parameters:
  /// - workletId: The ID of the compiled worklet
  /// - arguments: The arguments to pass to the worklet function
  /// 
  /// Returns the result of the worklet execution
  static dynamic execute(String workletId, List<dynamic> arguments) {
    // This is a placeholder - actual implementation is in native code
    // Native code should:
    // 1. Look up the function name from workletId
    // 2. Call GeneratedWorklets.functionName(...arguments)
    // 3. Return the result
    throw UnimplementedError(
      'WorkletNativeExecutor.execute() must be implemented in native code. '
      'Call GeneratedWorklets functions directly from native code.',
    );
  }

  /// Get the function name for a worklet ID
  /// 
  /// The function name is derived from the worklet ID and can be used
  /// to call the generated function directly.
  static String getFunctionName(String workletId) {
    // Extract function name from worklet ID
    // Format: functionName_hashCode
    final parts = workletId.split('_');
    if (parts.length >= 2) {
      return parts[0];
    }
    return 'worklet_$workletId';
  }
}

