/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import 'dart:io';
import 'code_writer.dart';
import 'runtime_registry.dart';

/// Build-time hook for writing generated worklet code to native files
/// 
/// Call this during development or build to write all compiled worklets
/// to native source files that can be included in the build.
class WorkletBuildHook {
  /// Write all compiled worklets to native source files
  /// 
  /// This should be called:
  /// - During development (hot reload)
  /// - Before building native apps
  /// - In a build script
  /// 
  /// Example:
  /// ```dart
  /// // In main.dart or build script
  /// await WorkletBuildHook.writeGeneratedCode();
  /// ```
  static Future<void> writeGeneratedCode({
    String? projectRoot,
  }) async {
    // Find project root (where pubspec.yaml is)
    final root = projectRoot ?? _findProjectRoot();
    if (root == null) {
      print('⚠️  Could not find project root. Skipping worklet code generation.');
      return;
    }

    // Determine output directories relative to project root
    final androidDir = '$root/android/src/main/kotlin/com/dotcorr/dcflight/worklets';
    final iosDir = '$root/ios/Classes/Worklets';

    print('📝 Writing generated worklet code...');
    print('   Android: $androidDir');
    print('   iOS: $iosDir');

    try {
      await WorkletCodeWriter.writeAll(
        androidOutputDir: androidDir,
        iosOutputDir: iosDir,
      );
      print('✅ Generated worklet code written successfully');
    } catch (e) {
      print('❌ Error writing generated worklet code: $e');
      rethrow;
    }
  }

  /// Find the project root directory (where pubspec.yaml is)
  static String? _findProjectRoot() {
    var current = Directory.current;
    var maxDepth = 10;
    var depth = 0;

    while (depth < maxDepth) {
      final pubspec = File('${current.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        return current.path;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        // Reached filesystem root
        break;
      }
      current = parent;
      depth++;
    }

    return null;
  }

  /// Check if generated files need to be updated
  static bool needsUpdate() {
    final registry = WorkletRegistry();
    final workletIds = registry.getCompiledWorkletIds();
    return workletIds.isNotEmpty;
  }
}

