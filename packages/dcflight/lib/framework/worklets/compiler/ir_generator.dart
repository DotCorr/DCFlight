/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import 'ast_extractor.dart';
import '../worklet.dart';

/// Intermediate Representation for worklet compilation
/// Platform-agnostic representation that can be converted to any target language

enum IROperator {
  add,
  subtract,
  multiply,
  divide,
  modulo,
  equals,
  notEquals,
  lessThan,
  greaterThan,
  lessThanOrEqual,
  greaterThanOrEqual,
  and,
  or,
  not,
  negate,
}

enum IRNodeType {
  literal,
  variable,
  binaryOp,
  unaryOp,
  functionCall,
  conditional,
  returnStatement,
  block,
}

/// Base IR node
abstract class IRNode {
  IRNodeType get type;
  Map<String, dynamic> toMap();
}

/// Literal value
class IRLiteralNode extends IRNode {
  final dynamic value;
  final String valueType;

  IRLiteralNode(this.value, this.valueType);

  @override
  IRNodeType get type => IRNodeType.literal;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'literal',
        'value': value,
        'valueType': valueType,
      };
}

/// Variable reference
class IRVariableNode extends IRNode {
  final String name;

  IRVariableNode(this.name);

  @override
  IRNodeType get type => IRNodeType.variable;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'variable',
        'name': name,
      };
}

/// Binary operation
class IRBinaryOpNode extends IRNode {
  final IROperator operator;
  final IRNode left;
  final IRNode right;

  IRBinaryOpNode(this.operator, this.left, this.right);

  @override
  IRNodeType get type => IRNodeType.binaryOp;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'binaryOp',
        'operator': operator.toString().split('.').last,
        'left': left.toMap(),
        'right': right.toMap(),
      };
}

/// Unary operation
class IRUnaryOpNode extends IRNode {
  final IROperator operator;
  final IRNode operand;

  IRUnaryOpNode(this.operator, this.operand);

  @override
  IRNodeType get type => IRNodeType.unaryOp;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'unaryOp',
        'operator': operator.toString().split('.').last,
        'operand': operand.toMap(),
      };
}

/// Function call
class IRFunctionCallNode extends IRNode {
  final String functionName;
  final List<IRNode> arguments;

  IRFunctionCallNode(this.functionName, this.arguments);

  @override
  IRNodeType get type => IRNodeType.functionCall;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'functionCall',
        'functionName': functionName,
        'arguments': arguments.map((a) => a.toMap()).toList(),
      };
}

/// Conditional expression
class IRConditionalNode extends IRNode {
  final IRNode condition;
  final IRNode thenBranch;
  final IRNode? elseBranch;

  IRConditionalNode(this.condition, this.thenBranch, this.elseBranch);

  @override
  IRNodeType get type => IRNodeType.conditional;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'conditional',
        'condition': condition.toMap(),
        'thenBranch': thenBranch.toMap(),
        if (elseBranch != null) 'elseBranch': elseBranch!.toMap(),
      };
}

/// Return statement
class IRReturnNode extends IRNode {
  final IRNode? expression;

  IRReturnNode(this.expression);

  @override
  IRNodeType get type => IRNodeType.returnStatement;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'returnStatement',
        if (expression != null) 'expression': expression!.toMap(),
      };
}

/// Block of statements
class IRBlockNode extends IRNode {
  final List<IRNode> statements;

  IRBlockNode(this.statements);

  @override
  IRNodeType get type => IRNodeType.block;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'block',
        'statements': statements.map((s) => s.toMap()).toList(),
      };
}

/// Complete IR representation of a worklet
class WorkletIR {
  final String functionName;
  final String returnType;
  final List<WorkletParameter> parameters;
  final IRNode body;

  WorkletIR({
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

/// Converts AST to IR (normalizes and validates)
class IRGenerator {
  static WorkletIR generate(WorkletAST ast) {
    final bodyIR = _convertNode(ast.body);
    return WorkletIR(
      functionName: ast.functionName,
      returnType: ast.returnType,
      parameters: ast.parameters,
      body: bodyIR,
    );
  }

  static IRNode _convertNode(WorkletASTNode node) {
    switch (node.type) {
      case WorkletASTNodeType.literal:
        final literal = node as WorkletLiteralNode;
        return IRLiteralNode(literal.value, literal.valueType);

      case WorkletASTNodeType.variable:
        final variable = node as WorkletVariableNode;
        return IRVariableNode(variable.name);

      case WorkletASTNodeType.binaryOp:
        final binary = node as WorkletBinaryOpNode;
        return IRBinaryOpNode(
          _convertOperator(binary.operator),
          _convertNode(binary.left),
          _convertNode(binary.right),
        );

      case WorkletASTNodeType.unaryOp:
        final unary = node as WorkletUnaryOpNode;
        return IRUnaryOpNode(
          _convertUnaryOperator(unary.operator),
          _convertNode(unary.operand),
        );

      case WorkletASTNodeType.functionCall:
        final call = node as WorkletFunctionCallNode;
        return IRFunctionCallNode(
          call.functionName,
          call.arguments.map(_convertNode).toList(),
        );

      case WorkletASTNodeType.conditional:
        final conditional = node as WorkletConditionalNode;
        return IRConditionalNode(
          _convertNode(conditional.condition),
          _convertNode(conditional.thenBranch),
          conditional.elseBranch != null ? _convertNode(conditional.elseBranch!) : null,
        );

      case WorkletASTNodeType.returnStatement:
        final returnStmt = node as WorkletReturnNode;
        return IRReturnNode(
          returnStmt.expression != null ? _convertNode(returnStmt.expression!) : null,
        );

      case WorkletASTNodeType.block:
        final block = node as WorkletBlockNode;
        return IRBlockNode(block.statements.map(_convertNode).toList());
    }
  }

  static IROperator _convertOperator(String op) {
    switch (op) {
      case '+':
        return IROperator.add;
      case '-':
        return IROperator.subtract;
      case '*':
        return IROperator.multiply;
      case '/':
        return IROperator.divide;
      case '%':
        return IROperator.modulo;
      case '==':
        return IROperator.equals;
      case '!=':
        return IROperator.notEquals;
      case '<':
        return IROperator.lessThan;
      case '>':
        return IROperator.greaterThan;
      case '<=':
        return IROperator.lessThanOrEqual;
      case '>=':
        return IROperator.greaterThanOrEqual;
      case '&&':
        return IROperator.and;
      case '||':
        return IROperator.or;
      default:
        throw Exception('Unknown operator: $op');
    }
  }

  static IROperator _convertUnaryOperator(String op) {
    switch (op) {
      case '-':
        return IROperator.negate;
      case '!':
        return IROperator.not;
      default:
        throw Exception('Unknown unary operator: $op');
    }
  }
}

