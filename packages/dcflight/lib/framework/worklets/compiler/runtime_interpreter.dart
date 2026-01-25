/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

library;

import 'ir_generator.dart';

/// Serializes worklet IR to a format that native code can interpret at runtime
/// This allows worklets to run WITHOUT rebuilding the app - just like React Native Reanimated!
class WorkletRuntimeInterpreter {
  /// Serialize IR to a simple JSON format that native can interpret
  static Map<String, dynamic> serializeIR(WorkletIR ir) {
    return {
      'functionName': ir.functionName,
      'returnType': ir.returnType,
      'parameters': ir.parameters.map((p) => {
        'name': p.name,
        'type': p.type,
        'isOptional': p.isOptional,
      }).toList(),
      'body': _serializeNode(ir.body),
    };
  }

  static Map<String, dynamic> _serializeNode(IRNode node) {
    switch (node.type) {
      case IRNodeType.literal:
        final literal = node as IRLiteralNode;
        return {
          'type': 'literal',
          'value': literal.value,
          'valueType': literal.valueType,
        };

      case IRNodeType.variable:
        final variable = node as IRVariableNode;
        return {
          'type': 'variable',
          'name': variable.name,
        };

      case IRNodeType.binaryOp:
        final binary = node as IRBinaryOpNode;
        return {
          'type': 'binaryOp',
          'operator': binary.operator.toString().split('.').last,
          'left': _serializeNode(binary.left),
          'right': _serializeNode(binary.right),
        };

      case IRNodeType.unaryOp:
        final unary = node as IRUnaryOpNode;
        return {
          'type': 'unaryOp',
          'operator': unary.operator.toString().split('.').last,
          'operand': _serializeNode(unary.operand),
        };

      case IRNodeType.functionCall:
        final call = node as IRFunctionCallNode;
        return {
          'type': 'functionCall',
          'functionName': call.functionName,
          'arguments': call.arguments.map(_serializeNode).toList(),
        };

      case IRNodeType.conditional:
        final conditional = node as IRConditionalNode;
        return {
          'type': 'conditional',
          'condition': _serializeNode(conditional.condition),
          'thenBranch': _serializeNode(conditional.thenBranch),
          if (conditional.elseBranch != null) 'elseBranch': _serializeNode(conditional.elseBranch!),
        };

      case IRNodeType.returnStatement:
        final returnStmt = node as IRReturnNode;
        return {
          'type': 'returnStatement',
          if (returnStmt.expression != null) 'expression': _serializeNode(returnStmt.expression!),
        };

      case IRNodeType.block:
        final block = node as IRBlockNode;
        return {
          'type': 'block',
          'statements': block.statements.map(_serializeNode).toList(),
        };
    }
  }
}

