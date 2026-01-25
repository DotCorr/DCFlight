/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import 'ir_generator.dart';

/// Generates Kotlin source code from WorkletIR
class KotlinCodeGenerator {
  static String generate(WorkletIR ir, {String packageName = 'com.dotcorr.dcflight.worklets'}) {
    final buffer = StringBuffer();
    
    // Package declaration
    buffer.writeln('package $packageName');
    buffer.writeln();
    
    // Imports
    buffer.writeln('import kotlin.math.*');
    buffer.writeln();
    
    // Object to hold generated worklets
    buffer.writeln('object GeneratedWorklets {');
    buffer.writeln();
    
    // Generate function
    final functionName = _sanitizeFunctionName(ir.functionName);
    final returnType = _dartToKotlinType(ir.returnType);
    final parameters = ir.parameters.map((p) {
      final paramType = _dartToKotlinType(p.type);
      final defaultValue = p.isOptional && p.defaultValue != null
          ? ' = ${_convertDefaultValue(p.defaultValue!, p.type)}'
          : '';
      return '${p.name}: $paramType$defaultValue';
    }).where((p) => p.isNotEmpty).join(', ');
    
    buffer.writeln('    fun $functionName($parameters): $returnType {');
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
        final op = _kotlinOperator(binary.operator);
        return '($left $op $right)';

      case IRNodeType.unaryOp:
        final unary = node as IRUnaryOpNode;
        final operand = _generateExpression(unary.operand);
        final op = _kotlinUnaryOperator(unary.operator);
        return '$op$operand';

      case IRNodeType.functionCall:
        final call = node as IRFunctionCallNode;
        final args = call.arguments.map(_generateExpression).join(', ');
        final functionName = _kotlinFunctionName(call.functionName);
        return '$functionName($args)';

      case IRNodeType.conditional:
        final conditional = node as IRConditionalNode;
        final condition = _generateExpression(conditional.condition);
        final thenBranch = _generateExpression(conditional.thenBranch);
        final elseBranch = conditional.elseBranch != null
            ? _generateExpression(conditional.elseBranch!)
            : 'null';
        return 'if ($condition) $thenBranch else $elseBranch';

      case IRNodeType.returnStatement:
        final returnStmt = node as IRReturnNode;
        if (returnStmt.expression != null) {
          return _generateExpression(returnStmt.expression!);
        }
        return 'Unit';

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
        return literal.value.toString();
      default:
        return literal.value.toString();
    }
  }

  static String _kotlinOperator(IROperator op) {
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

  static String _kotlinUnaryOperator(IROperator op) {
    switch (op) {
      case IROperator.negate:
        return '-';
      case IROperator.not:
        return '!';
      default:
        throw Exception('Unsupported unary operator: $op');
    }
  }

  static String _kotlinFunctionName(String dartName) {
    // Map Dart math functions to Kotlin
    if (dartName.startsWith('Math.')) {
      final function = dartName.substring(5);
      return function; // Kotlin math functions are in kotlin.math.*
    }
    return dartName;
  }

  static String _dartToKotlinType(String dartType) {
    switch (dartType) {
      case 'double':
        return 'Double';
      case 'int':
        return 'Int';
      case 'String':
        return 'String';
      case 'bool':
        return 'Boolean';
      case 'void':
        return 'Unit';
      default:
        if (dartType.startsWith('List<')) {
          final innerType = dartType.substring(5, dartType.length - 1);
          return 'List<${_dartToKotlinType(innerType)}>';
        }
        if (dartType.startsWith('Map<')) {
          return 'Map<String, Any>';
        }
        return dartType;
    }
  }

  static String _sanitizeFunctionName(String name) {
    // Ensure valid Kotlin identifier
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

