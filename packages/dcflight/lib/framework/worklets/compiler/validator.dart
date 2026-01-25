/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import 'ir_generator.dart';

/// Validates that a worklet only uses UI-thread-safe operations
class WorkletValidator {
  /// Allowed function names (native math functions)
  static const allowedFunctions = [
    'Math.sin',
    'Math.cos',
    'Math.tan',
    'Math.asin',
    'Math.acos',
    'Math.atan',
    'Math.atan2',
    'Math.exp',
    'Math.log',
    'Math.log10',
    'Math.sqrt',
    'Math.pow',
    'Math.abs',
    'Math.max',
    'Math.min',
    'Math.floor',
    'Math.ceil',
    'Math.round',
    'sin',
    'cos',
    'tan',
    'asin',
    'acos',
    'atan',
    'atan2',
    'exp',
    'log',
    'log10',
    'sqrt',
    'pow',
    'abs',
    'max',
    'min',
    'floor',
    'ceil',
    'round',
  ];

  /// Allowed property/method access patterns
  static const allowedPropertyAccess = [
    'length', // List.length, String.length
    'substring', // String.substring(start, end)
    'clamp', // num.clamp(min, max)
    'floor', // num.floor
    'ceil', // num.ceil
    'round', // num.round
    'abs', // num.abs
  ];

  /// Validate a worklet IR
  static ValidationResult validate(WorkletIR ir) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate return type
    if (!_isValidType(ir.returnType)) {
      errors.add('Unsupported return type: ${ir.returnType}');
    }

    // Validate parameters
    for (final param in ir.parameters) {
      if (!_isValidType(param.type)) {
        errors.add('Unsupported parameter type: ${param.type}');
      }
    }

    // Validate body
    _validateNode(ir.body, errors, warnings);

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  static void _validateNode(IRNode node, List<String> errors, List<String> warnings) {
    switch (node.type) {
      case IRNodeType.literal:
        // Literals are always safe
        break;

      case IRNodeType.variable:
        // Variables are safe (local only)
        break;

      case IRNodeType.binaryOp:
        final binary = node as IRBinaryOpNode;
        _validateNode(binary.left, errors, warnings);
        _validateNode(binary.right, errors, warnings);
        break;

      case IRNodeType.unaryOp:
        final unary = node as IRUnaryOpNode;
        _validateNode(unary.operand, errors, warnings);
        break;

      case IRNodeType.functionCall:
        final call = node as IRFunctionCallNode;
        final functionName = call.functionName;
        
        // Check if it's a property access (object.property)
        if (functionName.contains('.')) {
          final parts = functionName.split('.');
          if (parts.length == 2) {
            final property = parts[1];
            if (!allowedPropertyAccess.contains(property) && 
                !allowedFunctions.contains(functionName)) {
              // Check if it's an index access (object.[])
              if (property == '[]') {
                // Index access is allowed
              } else {
                errors.add('Property/method "${functionName}" is not allowed in worklets. '
                    'Only ${allowedPropertyAccess.join(", ")} are supported.');
              }
            }
          }
        } else if (!allowedFunctions.contains(functionName)) {
          errors.add('Function "${functionName}" is not allowed in worklets. '
              'Only native math functions are supported.');
        }
        
        for (final arg in call.arguments) {
          _validateNode(arg, errors, warnings);
        }
        break;

      case IRNodeType.conditional:
        final conditional = node as IRConditionalNode;
        _validateNode(conditional.condition, errors, warnings);
        _validateNode(conditional.thenBranch, errors, warnings);
        if (conditional.elseBranch != null) {
          _validateNode(conditional.elseBranch!, errors, warnings);
        }
        break;

      case IRNodeType.returnStatement:
        final returnStmt = node as IRReturnNode;
        if (returnStmt.expression != null) {
          _validateNode(returnStmt.expression!, errors, warnings);
        }
        break;

      case IRNodeType.block:
        final block = node as IRBlockNode;
        for (final stmt in block.statements) {
          _validateNode(stmt, errors, warnings);
        }
        break;
    }
  }

  static bool _isValidType(String type) {
    const validTypes = [
      'double',
      'int',
      'String',
      'bool',
      'void',
    ];
    
    if (validTypes.contains(type)) {
      return true;
    }
    
    // Check for List<T> and Map<K, V>
    if (type.startsWith('List<') && type.endsWith('>')) {
      final innerType = type.substring(5, type.length - 1);
      return _isValidType(innerType);
    }
    
    if (type.startsWith('Map<')) {
      return true; // Map<String, dynamic> is valid
    }
    
    return false;
  }
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  @override
  String toString() {
    if (isValid) {
      return 'Validation passed';
    }
    final buffer = StringBuffer();
    buffer.writeln('Validation failed:');
    for (final error in errors) {
      buffer.writeln('  ❌ $error');
    }
    for (final warning in warnings) {
      buffer.writeln('  ⚠️  $warning');
    }
    return buffer.toString();
  }
}

