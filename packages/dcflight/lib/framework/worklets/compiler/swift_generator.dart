/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import 'ir_generator.dart';

/// Generates Swift source code from WorkletIR
class SwiftCodeGenerator {
  static String generate(WorkletIR ir) {
    final buffer = StringBuffer();
    
    // Imports
    buffer.writeln('import Foundation');
    buffer.writeln();
    
    // Enum to hold generated worklets
    buffer.writeln('enum GeneratedWorklets {');
    buffer.writeln();
    
    // Generate function
    final functionName = _sanitizeFunctionName(ir.functionName);
    final returnType = _dartToSwiftType(ir.returnType);
    final parameters = ir.parameters.map((p) {
      final paramType = _dartToSwiftType(p.type);
      final defaultValue = p.isOptional && p.defaultValue != null
          ? ' = ${_convertDefaultValue(p.defaultValue!, p.type)}'
          : '';
      return '_ ${p.name}: $paramType$defaultValue';
    }).where((p) => p.isNotEmpty).join(', ');
    
    buffer.writeln('    static func $functionName($parameters) -> $returnType {');
    buffer.writeln('        return ${_generateExpression(ir.body)}');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('}');
    
    return buffer.toString();
  }

  static String _generateExpression(IRNode node) {
    switch (node.type) {
      case IRNodeType.literal:
        final literal = node as IRLiteralNode;
        return _generateLiteral(literal);

      case IRNodeType.variable:
        final variable = node as IRVariableNode;
        return variable.name;

      case IRNodeType.binaryOp:
        final binary = node as IRBinaryOpNode;
        final left = _generateExpression(binary.left);
        final right = _generateExpression(binary.right);
        final op = _swiftOperator(binary.operator);
        return '($left $op $right)';

      case IRNodeType.unaryOp:
        final unary = node as IRUnaryOpNode;
        final operand = _generateExpression(unary.operand);
        final op = _swiftUnaryOperator(unary.operator);
        return '$op$operand';

      case IRNodeType.functionCall:
        final call = node as IRFunctionCallNode;
        final functionName = call.functionName;
        
        // Handle property access and method calls
        if (functionName.contains('.')) {
          final parts = functionName.split('.');
          if (parts.length == 2) {
            final object = parts[0];
            final property = parts[1];
            
            // Handle index access (list[index])
            if (property == '[]') {
              if (call.arguments.isNotEmpty) {
                final index = _generateExpression(call.arguments[0]);
                return '$object[$index]';
              }
            }
            
            // Handle length property
            if (property == 'length') {
              return '$object.count';
            }
            
            // Handle substring method
            if (property == 'substring') {
              if (call.arguments.length == 2) {
                final start = _generateExpression(call.arguments[0]);
                final end = _generateExpression(call.arguments[1]);
                return '$object.substring(with: $object.index($object.startIndex, offsetBy: $start)..<$object.index($object.startIndex, offsetBy: $end))';
              } else if (call.arguments.length == 1) {
                final start = _generateExpression(call.arguments[0]);
                return '$object.substring(from: $object.index($object.startIndex, offsetBy: $start))';
              }
            }
            
            // Handle clamp method
            if (property == 'clamp') {
              if (call.arguments.length == 2) {
                final min = _generateExpression(call.arguments[0]);
                final max = _generateExpression(call.arguments[1]);
                return 'max($min, min($max, $object))';
              }
            }
            
            // Handle numeric methods
            if (property == 'floor') {
              return 'floor($object)';
            }
            if (property == 'ceil') {
              return 'ceil($object)';
            }
            if (property == 'round') {
              return 'round($object)';
            }
            if (property == 'abs') {
              return 'abs($object)';
            }
          }
        }
        
        // Regular function calls
        final args = call.arguments.map(_generateExpression).join(', ');
        final swiftFunctionName = _swiftFunctionName(functionName);
        return '$swiftFunctionName($args)';

      case IRNodeType.conditional:
        final conditional = node as IRConditionalNode;
        final condition = _generateExpression(conditional.condition);
        final thenBranch = _generateExpression(conditional.thenBranch);
        final elseBranch = conditional.elseBranch != null
            ? _generateExpression(conditional.elseBranch!)
            : 'nil';
        return '($condition ? $thenBranch : $elseBranch)';

      case IRNodeType.returnStatement:
        final returnStmt = node as IRReturnNode;
        if (returnStmt.expression != null) {
          return _generateExpression(returnStmt.expression!);
        }
        return '()';

      case IRNodeType.block:
        final block = node as IRBlockNode;
        final statements = block.statements.map(_generateExpression).join('\n        ');
        return statements;

    }
  }

  static String _generateLiteral(IRLiteralNode literal) {
    switch (literal.valueType) {
      case 'double':
        return literal.value.toString();
      case 'int':
        return literal.value.toString();
      case 'String':
        return '"${literal.value}"';
      case 'bool':
        return literal.value ? 'true' : 'false';
      default:
        return literal.value.toString();
    }
  }

  static String _swiftOperator(IROperator op) {
    switch (op) {
      case IROperator.add:
        return '+';
      case IROperator.subtract:
        return '-';
      case IROperator.multiply:
        return '*';
      case IROperator.divide:
        return '/';
      case IROperator.modulo:
        return '%';
      case IROperator.equals:
        return '==';
      case IROperator.notEquals:
        return '!=';
      case IROperator.lessThan:
        return '<';
      case IROperator.greaterThan:
        return '>';
      case IROperator.lessThanOrEqual:
        return '<=';
      case IROperator.greaterThanOrEqual:
        return '>=';
      case IROperator.and:
        return '&&';
      case IROperator.or:
        return '||';
      default:
        throw Exception('Unsupported operator: $op');
    }
  }

  static String _swiftUnaryOperator(IROperator op) {
    switch (op) {
      case IROperator.negate:
        return '-';
      case IROperator.not:
        return '!';
      default:
        throw Exception('Unsupported unary operator: $op');
    }
  }

  static String _swiftFunctionName(String dartName) {
    // Map Dart math functions to Swift
    if (dartName.startsWith('Math.')) {
      final function = dartName.substring(5);
      return function.toLowerCase(); // Swift math functions are lowercase
    }
    return dartName;
  }

  static String _dartToSwiftType(String dartType) {
    switch (dartType) {
      case 'double':
        return 'Double';
      case 'int':
        return 'Int';
      case 'String':
        return 'String';
      case 'bool':
        return 'Bool';
      case 'void':
        return 'Void';
      default:
        if (dartType.startsWith('List<')) {
          final innerType = dartType.substring(5, dartType.length - 1);
          return '[${_dartToSwiftType(innerType)}]';
        }
        if (dartType.startsWith('Map<')) {
          return '[String: Any]';
        }
        return dartType;
    }
  }

  static String _sanitizeFunctionName(String name) {
    // Ensure valid Swift identifier
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  static String _convertDefaultValue(String value, String type) {
    switch (type) {
      case 'double':
        return value;
      case 'int':
        return value;
      case 'String':
        return '"$value"';
      case 'bool':
        return value;
      default:
        return value;
    }
  }
}

