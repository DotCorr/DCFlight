/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import 'ast_extractor.dart';
import 'ir_generator.dart';
import 'validator.dart';
import 'kotlin_generator.dart';
import 'swift_generator.dart';

/// Complete worklet compilation pipeline
class WorkletCompiler {
  /// Compile a worklet function to native code
  static CompilationResult compile(
    Function worklet, {
    String packageName = 'com.dotcorr.dcflight.worklets',
  }) {
    try {
      // Step 1: Extract AST
      final ast = WorkletASTExtractor.extract(worklet);

      // Step 2: Generate IR
      final ir = IRGenerator.generate(ast);

      // Step 3: Validate
      final validation = WorkletValidator.validate(ir);
      if (!validation.isValid) {
        return CompilationResult(
          success: false,
          errors: validation.errors,
          warnings: validation.warnings,
        );
      }

      // Step 4: Generate native code
      final kotlinCode = KotlinCodeGenerator.generate(ir, packageName: packageName);
      final swiftCode = SwiftCodeGenerator.generate(ir);

      return CompilationResult(
        success: true,
        kotlinCode: kotlinCode,
        swiftCode: swiftCode,
        ir: ir,
        warnings: validation.warnings,
      );
    } catch (e) {
      return CompilationResult(
        success: false,
        errors: ['Compilation failed: $e'],
      );
    }
  }
}

/// Result of worklet compilation
class CompilationResult {
  final bool success;
  final String? kotlinCode;
  final String? swiftCode;
  final WorkletIR? ir;
  final List<String> errors;
  final List<String> warnings;

  CompilationResult({
    required this.success,
    this.kotlinCode,
    this.swiftCode,
    this.ir,
    this.errors = const [],
    this.warnings = const [],
  });

  @override
  String toString() {
    if (success) {
      return 'Compilation successful';
    } else {
      return 'Compilation failed:\n${errors.join('\n')}';
    }
  }
}

