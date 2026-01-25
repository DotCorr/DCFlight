/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import 'dart:io';
import 'runtime_registry.dart';

/// Writes generated native code to files
class WorkletCodeWriter {
  /// Write all compiled worklets to native source files
  static Future<void> writeAll({
    String androidOutputDir = 'android/src/main/kotlin/com/dotcorr/dcflight/worklets',
    String iosOutputDir = 'ios/Classes/Worklets',
  }) async {
    final registry = WorkletRegistry();
    final workletIds = registry.getCompiledWorkletIds();

    if (workletIds.isEmpty) {
      return;
    }

    // Collect all Kotlin and Swift code
    final kotlinBuffer = StringBuffer();
    final swiftBuffer = StringBuffer();

    // Kotlin header
    kotlinBuffer.writeln('package com.dotcorr.dcflight.worklets');
    kotlinBuffer.writeln();
    kotlinBuffer.writeln('import kotlin.math.*');
    kotlinBuffer.writeln();
    kotlinBuffer.writeln('object GeneratedWorklets {');

    // Swift header
    swiftBuffer.writeln('import Foundation');
    swiftBuffer.writeln();
    swiftBuffer.writeln('enum GeneratedWorklets {');

    // Add each compiled worklet
    for (final workletId in workletIds) {
      final result = registry.getCompilationResult(workletId);
      if (result != null && result.success && result.ir != null) {
        // Use the full generated code directly
        if (result.kotlinCode != null) {
          // Extract just the function from the generated code
          final kotlinFunction = _extractFullFunctionFromKotlin(result.kotlinCode!);
          if (kotlinFunction.isNotEmpty) {
            kotlinBuffer.writeln('    $kotlinFunction');
            kotlinBuffer.writeln();
          }
        }
        if (result.swiftCode != null) {
          // Extract just the function from the generated code
          final swiftFunction = _extractFullFunctionFromSwift(result.swiftCode!);
          if (swiftFunction.isNotEmpty) {
            swiftBuffer.writeln('    $swiftFunction');
            swiftBuffer.writeln();
          }
        }
      }
    }

    // Kotlin footer
    kotlinBuffer.writeln('}');

    // Swift footer
    swiftBuffer.writeln('}');

    // Write files
    final androidFile = File(androidOutputDir);
    if (!await androidFile.exists()) {
      await androidFile.create(recursive: true);
    }
    await File('$androidOutputDir/GeneratedWorklets.kt').writeAsString(kotlinBuffer.toString());

    final iosFile = File(iosOutputDir);
    if (!await iosFile.exists()) {
      await iosFile.create(recursive: true);
    }
    await File('$iosOutputDir/GeneratedWorklets.swift').writeAsString(swiftBuffer.toString());
  }

  static String _extractFullFunctionFromKotlin(String kotlinCode) {
    // Extract the full function from generated Kotlin code
    // Look for the function inside the object
    final match = RegExp(r'fun\s+(\w+)\s*\(([^)]*)\)\s*:\s*(\w+)\s*\{([^}]+)\}').firstMatch(kotlinCode);
    if (match != null) {
      final functionName = match.group(1)!;
      final parameters = match.group(2)!;
      final returnType = match.group(3)!;
      final functionBody = match.group(4)!.trim();
      return 'fun $functionName($parameters): $returnType {\n        $functionBody\n    }';
    }
    return '';
  }

  static String _extractFullFunctionFromSwift(String swiftCode) {
    // Extract the full function from generated Swift code
    // Look for the function inside the enum
    final match = RegExp(r'static\s+func\s+(\w+)\s*\(([^)]*)\)\s*->\s*(\w+)\s*\{([^}]+)\}').firstMatch(swiftCode);
    if (match != null) {
      final functionName = match.group(1)!;
      final parameters = match.group(2)!;
      final returnType = match.group(3)!;
      final functionBody = match.group(4)!.trim();
      return 'static func $functionName($parameters) -> $returnType {\n        $functionBody\n    }';
    }
    return '';
  }
}

