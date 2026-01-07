/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

library;

import '../worklet.dart';

/// AST node types for worklet compilation
enum WorkletASTNodeType {
  literal,
  variable,
  binaryOp,
  unaryOp,
  functionCall,
  conditional,
  returnStatement,
  block,
}

/// Base AST node for worklet expressions
abstract class WorkletASTNode {
  WorkletASTNodeType get type;
  Map<String, dynamic> toMap();
}

/// Literal value (number, string, bool)
class WorkletLiteralNode extends WorkletASTNode {
  final dynamic value;
  final String valueType; // 'double', 'int', 'String', 'bool'

  WorkletLiteralNode(this.value, this.valueType);

  @override
  WorkletASTNodeType get type => WorkletASTNodeType.literal;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'literal',
        'value': value,
        'valueType': valueType,
      };
}

/// Variable reference
class WorkletVariableNode extends WorkletASTNode {
  final String name;

  WorkletVariableNode(this.name);

  @override
  WorkletASTNodeType get type => WorkletASTNodeType.variable;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'variable',
        'name': name,
      };
}

/// Binary operation (+, -, *, /, %, ==, !=, <, >, <=, >=)
class WorkletBinaryOpNode extends WorkletASTNode {
  final String operator;
  final WorkletASTNode left;
  final WorkletASTNode right;

  WorkletBinaryOpNode(this.operator, this.left, this.right);

  @override
  WorkletASTNodeType get type => WorkletASTNodeType.binaryOp;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'binaryOp',
        'operator': operator,
        'left': left.toMap(),
        'right': right.toMap(),
      };
}

/// Unary operation (-, !)
class WorkletUnaryOpNode extends WorkletASTNode {
  final String operator;
  final WorkletASTNode operand;

  WorkletUnaryOpNode(this.operator, this.operand);

  @override
  WorkletASTNodeType get type => WorkletASTNodeType.unaryOp;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'unaryOp',
        'operator': operator,
        'operand': operand.toMap(),
      };
}

/// Function call (Math.sin, Math.cos, etc.)
class WorkletFunctionCallNode extends WorkletASTNode {
  final String functionName;
  final List<WorkletASTNode> arguments;

  WorkletFunctionCallNode(this.functionName, this.arguments);

  @override
  WorkletASTNodeType get type => WorkletASTNodeType.functionCall;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'functionCall',
        'functionName': functionName,
        'arguments': arguments.map((a) => a.toMap()).toList(),
      };
}

/// Conditional expression (if/else or ternary)
class WorkletConditionalNode extends WorkletASTNode {
  final WorkletASTNode condition;
  final WorkletASTNode thenBranch;
  final WorkletASTNode? elseBranch;

  WorkletConditionalNode(this.condition, this.thenBranch, this.elseBranch);

  @override
  WorkletASTNodeType get type => WorkletASTNodeType.conditional;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'conditional',
        'condition': condition.toMap(),
        'thenBranch': thenBranch.toMap(),
        if (elseBranch != null) 'elseBranch': elseBranch!.toMap(),
      };
}

/// Return statement
class WorkletReturnNode extends WorkletASTNode {
  final WorkletASTNode? expression;

  WorkletReturnNode(this.expression);

  @override
  WorkletASTNodeType get type => WorkletASTNodeType.returnStatement;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'returnStatement',
        if (expression != null) 'expression': expression!.toMap(),
      };
}

/// Block of statements
class WorkletBlockNode extends WorkletASTNode {
  final List<WorkletASTNode> statements;

  WorkletBlockNode(this.statements);

  @override
  WorkletASTNodeType get type => WorkletASTNodeType.block;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'block',
        'statements': statements.map((s) => s.toMap()).toList(),
      };
}

/// Extracted worklet information
class WorkletAST {
  final String functionName;
  final String returnType;
  final List<WorkletParameter> parameters;
  final WorkletASTNode body;

  WorkletAST({
    required this.functionName,
    required this.returnType,
    required this.parameters,
    required this.body,
  });

  Map<String, dynamic> toMap() => {
        'functionName': functionName,
        'returnType': returnType,
        'parameters': parameters.map((p) => p.toMap()).toList(),
        'body': body.toMap(),
      };
}

/// Extracts AST from worklet functions using reflection and source parsing
class WorkletASTExtractor {
  /// Extract AST from a worklet function
  static WorkletAST extract(Function worklet) {
    // Extract everything from source code string
    final sourceCode = worklet.toString();
    
    // Extract function signature
    final signatureMatch = RegExp(r'(\w+)\s*\(([^)]*)\)\s*(?:->\s*(\w+))?').firstMatch(sourceCode);
    if (signatureMatch == null) {
      throw Exception('Could not parse function signature from: $sourceCode');
    }

    final functionName = signatureMatch.group(1) ?? 'worklet';
    final paramsStr = signatureMatch.group(2) ?? '';
    final returnType = signatureMatch.group(3) ?? _inferReturnType(sourceCode);

    // Parse parameters
    final parameters = _parseParameters(paramsStr);

    // Extract body AST from source code
    final body = _parseBody(sourceCode);

    return WorkletAST(
      functionName: functionName,
      returnType: returnType,
      parameters: parameters,
      body: body,
    );
  }

  static String _inferReturnType(String sourceCode) {
    // Try to infer return type from function body
    if (sourceCode.contains('return')) {
      final returnMatch = RegExp(r'return\s+([^;]+)').firstMatch(sourceCode);
      if (returnMatch != null) {
        final returnExpr = returnMatch.group(1)!.trim();
        if (RegExp(r'^-?\d+\.\d+').hasMatch(returnExpr)) {
          return 'double';
        }
        if (RegExp(r'^-?\d+$').hasMatch(returnExpr)) {
          return 'int';
        }
        if (returnExpr.startsWith('"') || returnExpr.startsWith("'")) {
          return 'String';
        }
      }
    }
    return 'dynamic';
  }

  static List<WorkletParameter> _parseParameters(String paramsStr) {
    final parameters = <WorkletParameter>[];
    if (paramsStr.trim().isEmpty) {
      return parameters;
    }

    final paramList = paramsStr.split(',');
    for (final param in paramList) {
      final trimmed = param.trim();
      if (trimmed.isEmpty) continue;
      
      // Parse parameter: "double time" or "List<String> words" or "String? optional"
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final type = parts[0];
        final name = parts[1].replaceAll('?', ''); // Remove optional marker
        final isOptional = trimmed.contains('?');
        
        parameters.add(WorkletParameter(
          name: name,
          type: _normalizeType(type),
          isOptional: isOptional,
        ));
      }
    }
    return parameters;
  }

  /// Normalize Dart type names for native execution
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

  /// Parse function body from source code string
  /// This is a simplified parser - in production, use analyzer package
  static WorkletASTNode _parseBody(String sourceCode) {
    // Extract body between { and }
    final bodyMatch = RegExp(r'\{([^}]*)\}').firstMatch(sourceCode);
    if (bodyMatch == null) {
      throw Exception('Could not extract function body from source');
    }

    final bodyCode = bodyMatch.group(1)!.trim();

    // Handle arrow functions (=>)
    if (bodyCode.contains('=>')) {
      final arrowMatch = RegExp(r'=>\s*(.+)$').firstMatch(bodyCode);
      if (arrowMatch != null) {
        final expression = arrowMatch.group(1)!.trim();
        return _parseExpression(expression);
      }
    }

    // Handle block with return statement
    if (bodyCode.startsWith('return ')) {
      final returnExpr = bodyCode.substring(7).trim();
      return WorkletReturnNode(_parseExpression(returnExpr));
    }

    // Parse as expression
    return _parseExpression(bodyCode);
  }

  /// Parse an expression into AST
  static WorkletASTNode _parseExpression(String expr) {
    expr = expr.trim();

    // Literal numbers
    if (RegExp(r'^-?\d+\.?\d*$').hasMatch(expr)) {
      if (expr.contains('.')) {
        return WorkletLiteralNode(double.parse(expr), 'double');
      } else {
        return WorkletLiteralNode(int.parse(expr), 'int');
      }
    }

    // Literal strings
    if (expr.startsWith('"') && expr.endsWith('"')) {
      final value = expr.substring(1, expr.length - 1);
      return WorkletLiteralNode(value, 'String');
    }

    // Literal bool
    if (expr == 'true' || expr == 'false') {
      return WorkletLiteralNode(expr == 'true', 'bool');
    }

    // Binary operators (order matters - parse in precedence order)
    final binaryOps = [
      ['*', '/', '%'],
      ['+', '-'],
      ['<', '>', '<=', '>=', '==', '!='],
      ['&&'],
      ['||'],
    ];

    for (final ops in binaryOps) {
      for (final op in ops) {
        final pattern = _escapeRegex(op);
        final regex = RegExp('(.+?)\\s*$pattern\\s*(.+)');
        final match = regex.firstMatch(expr);
        if (match != null) {
          final left = match.group(1)!.trim();
          final right = match.group(2)!.trim();
          return WorkletBinaryOpNode(
            op,
            _parseExpression(left),
            _parseExpression(right),
          );
        }
      }
    }

    // Unary operators
    if (expr.startsWith('-') && expr.length > 1) {
      return WorkletUnaryOpNode('-', _parseExpression(expr.substring(1)));
    }
    if (expr.startsWith('!') && expr.length > 1) {
      return WorkletUnaryOpNode('!', _parseExpression(expr.substring(1)));
    }

    // Property access (list.length, string.length, etc.)
    final propertyAccessMatch = RegExp(r'(\w+)\s*\.\s*(\w+)').firstMatch(expr);
    if (propertyAccessMatch != null) {
      final object = propertyAccessMatch.group(1)!;
      final property = propertyAccessMatch.group(2)!;
      // Convert property access to function call for native code generation
      return WorkletFunctionCallNode('$object.$property', []);
    }

    // Method calls (list.length, string.substring, etc.)
    final methodCallMatch = RegExp(r'(\w+)\s*\.\s*(\w+)\s*\(([^)]*)\)').firstMatch(expr);
    if (methodCallMatch != null) {
      final object = methodCallMatch.group(1)!;
      final method = methodCallMatch.group(2)!;
      final argsStr = methodCallMatch.group(3)!.trim();
      final arguments = argsStr.isEmpty
          ? <WorkletASTNode>[]
          : argsStr.split(',').map((a) => _parseExpression(a.trim())).toList();
      return WorkletFunctionCallNode('$object.$method', arguments);
    }

    // Index access (list[index], string[index])
    final indexAccessMatch = RegExp(r'(\w+)\s*\[\s*([^\]]+)\s*\]').firstMatch(expr);
    if (indexAccessMatch != null) {
      final object = indexAccessMatch.group(1)!;
      final indexExpr = indexAccessMatch.group(2)!.trim();
      final index = _parseExpression(indexExpr);
      return WorkletFunctionCallNode('$object.[]', [index]);
    }

    // Function calls (Math.sin, Math.cos, etc.)
    final functionCallMatch = RegExp(r'(\w+(?:\.\w+)?)\s*\(([^)]*)\)').firstMatch(expr);
    if (functionCallMatch != null) {
      final functionName = functionCallMatch.group(1)!;
      final argsStr = functionCallMatch.group(2)!.trim();
      final arguments = argsStr.isEmpty
          ? <WorkletASTNode>[]
          : argsStr.split(',').map((a) => _parseExpression(a.trim())).toList();
      return WorkletFunctionCallNode(functionName, arguments);
    }

    // Conditional (ternary)
    final ternaryMatch = RegExp(r'(.+?)\s*\?\s*(.+?)\s*:\s*(.+)').firstMatch(expr);
    if (ternaryMatch != null) {
      final condition = _parseExpression(ternaryMatch.group(1)!.trim());
      final thenBranch = _parseExpression(ternaryMatch.group(2)!.trim());
      final elseBranch = _parseExpression(ternaryMatch.group(3)!.trim());
      return WorkletConditionalNode(condition, thenBranch, elseBranch);
    }

    // Variable reference
    if (RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(expr)) {
      return WorkletVariableNode(expr);
    }

    // If we can't parse it, treat as variable (fallback)
    return WorkletVariableNode(expr);
  }

  static String _escapeRegex(String str) {
    return str.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');
  }
}

