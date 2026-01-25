/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit
import Foundation

/**
 * WorkletInterpreter - Runtime interpreter for worklets that executes IR directly without rebuilding!
 * 
 * This is like React Native Reanimated - worklets run at runtime by interpreting
 * the IR (Intermediate Representation) sent from Dart.
 * 
 * NO REBUILD NEEDED - just write @Worklet and it works!
 * 
 * This is a framework-level component - available to all components and packages.
 */
public class WorkletInterpreter {
    
    /**
     * Execute a worklet by interpreting its IR
     * 
     * @param ir The serialized IR from Dart
     * @param elapsed Elapsed time (first parameter, usually)
     * @param config Additional parameters from workletConfig
     * @return The result of worklet execution
     */
    public static func execute(_ ir: [String: Any], elapsed: CFTimeInterval, config: [String: Any]?) -> Any? {
        guard let body = ir["body"] as? [String: Any] else { return nil }
        let returnType = ir["returnType"] as? String ?? "dynamic"
        
        // Build context with elapsed time and config parameters
        var context: [String: Any] = [
            "elapsed": elapsed
        ]
        
        // Add parameters from config
        if let config = config {
            for (key, value) in config {
                context[key] = value
            }
        }
        
        // Interpret the body
        guard let result = interpretNode(body, context: context) else { return nil }
        
        // Convert result to appropriate type
        switch returnType {
        case "double", "int":
            return (result as? NSNumber)?.doubleValue ?? 0.0
        case "String":
            return (result as? String) ?? ""
        case "bool":
            return (result as? Bool) ?? false
        default:
            return result
        }
    }
    
    /**
     * Interpret a single IR node
     */
    private static func interpretNode(_ node: [String: Any], context: [String: Any]) -> Any? {
        guard let type = node["type"] as? String else { return nil }
        
        switch type {
        case "literal":
            let value = node["value"]
            let valueType = node["valueType"] as? String ?? "dynamic"
            switch valueType {
            case "double":
                return (value as? NSNumber)?.doubleValue ?? 0.0
            case "int":
                return (value as? NSNumber)?.intValue ?? 0
            case "String":
                return (value as? String) ?? ""
            case "bool":
                return (value as? Bool) ?? false
            default:
                return value
            }
            
        case "variable":
            guard let name = node["name"] as? String else { return nil }
            return context[name] ?? 0.0
            
        case "binaryOp":
            guard let operatorStr = node["operator"] as? String,
                  let leftNode = node["left"] as? [String: Any],
                  let rightNode = node["right"] as? [String: Any],
                  let left = interpretNode(leftNode, context: context) as? NSNumber,
                  let right = interpretNode(rightNode, context: context) as? NSNumber else {
                return nil
            }
            
            let leftDouble = left.doubleValue
            let rightDouble = right.doubleValue
            
            switch operatorStr {
            case "add": return leftDouble + rightDouble
            case "subtract": return leftDouble - rightDouble
            case "multiply": return leftDouble * rightDouble
            case "divide": return rightDouble != 0 ? leftDouble / rightDouble : 0.0
            case "modulo": return leftDouble.truncatingRemainder(dividingBy: rightDouble)
            case "equals": return leftDouble == rightDouble ? 1.0 : 0.0
            case "notEquals": return leftDouble != rightDouble ? 1.0 : 0.0
            case "lessThan": return leftDouble < rightDouble ? 1.0 : 0.0
            case "greaterThan": return leftDouble > rightDouble ? 1.0 : 0.0
            case "lessThanOrEqual": return leftDouble <= rightDouble ? 1.0 : 0.0
            case "greaterThanOrEqual": return leftDouble >= rightDouble ? 1.0 : 0.0
            case "and": return (leftDouble != 0 && rightDouble != 0) ? 1.0 : 0.0
            case "or": return (leftDouble != 0 || rightDouble != 0) ? 1.0 : 0.0
            default:
                print("⚠️ WORKLET: Unknown binary operator: \(operatorStr)")
                return 0.0
            }
            
        case "unaryOp":
            guard let operatorStr = node["operator"] as? String,
                  let operandNode = node["operand"] as? [String: Any],
                  let operand = interpretNode(operandNode, context: context) as? NSNumber else {
                return nil
            }
            
            let operandDouble = operand.doubleValue
            
            switch operatorStr {
            case "negate": return -operandDouble
            case "not": return operandDouble == 0 ? 1.0 : 0.0
            default:
                print("⚠️ WORKLET: Unknown unary operator: \(operatorStr)")
                return operandDouble
            }
            
        case "functionCall":
            guard let functionName = node["functionName"] as? String,
                  let argumentsNodes = node["arguments"] as? [[String: Any]] else {
                return nil
            }
            
            let arguments = argumentsNodes.compactMap { interpretNode($0, context: context) }
            
            // Handle WorkletRuntime calls (Reanimated-like API)
            if functionName.hasPrefix("WorkletRuntime.") {
                return executeWorkletRuntimeCall(functionName, arguments: arguments)
            }
            // Handle math functions
            else if functionName.hasPrefix("Math.") {
                let funcName = String(functionName.dropFirst(5))
                return executeMathFunction(funcName, arguments: arguments)
            } else if functionName.contains(".") {
                // Handle property access
                return executePropertyAccess(functionName, arguments: arguments, context: context)
            } else {
                return executeMathFunction(functionName, arguments: arguments)
            }
            
        case "conditional":
            guard let conditionNode = node["condition"] as? [String: Any],
                  let thenBranch = node["thenBranch"] as? [String: Any] else {
                return nil
            }
            
            let condition = interpretNode(conditionNode, context: context) as? NSNumber
            let conditionValue = condition?.doubleValue ?? 0.0
            
            if conditionValue != 0 {
                return interpretNode(thenBranch, context: context)
            } else if let elseBranch = node["elseBranch"] as? [String: Any] {
                return interpretNode(elseBranch, context: context)
            } else {
                return nil
            }
            
        case "returnStatement":
            if let expression = node["expression"] as? [String: Any] {
                return interpretNode(expression, context: context)
            }
            return nil
            
        default:
            print("⚠️ WORKLET: Unknown node type: \(type)")
            return nil
        }
    }
    
    /**
     * Execute a math function
     */
    private static func executeMathFunction(_ functionName: String, arguments: [Any]) -> Double {
        let args = arguments.compactMap { ($0 as? NSNumber)?.doubleValue }
        
        switch functionName {
        case "sin": return args.isEmpty ? 0.0 : sin(args[0])
        case "cos": return args.isEmpty ? 0.0 : cos(args[0])
        case "tan": return args.isEmpty ? 0.0 : tan(args[0])
        case "asin": return args.isEmpty ? 0.0 : asin(args[0])
        case "acos": return args.isEmpty ? 0.0 : acos(args[0])
        case "atan": return args.isEmpty ? 0.0 : atan(args[0])
        case "atan2": return args.count >= 2 ? atan2(args[0], args[1]) : 0.0
        case "exp": return args.isEmpty ? 0.0 : exp(args[0])
        case "log": return args.isEmpty ? 0.0 : log(args[0])
        case "log10": return args.isEmpty ? 0.0 : log10(args[0])
        case "sqrt": return args.isEmpty ? 0.0 : sqrt(args[0])
        case "pow": return args.count >= 2 ? pow(args[0], args[1]) : 0.0
        case "abs": return args.isEmpty ? 0.0 : abs(args[0])
        case "max": return args.max() ?? 0.0
        case "min": return args.min() ?? 0.0
        case "floor": return args.isEmpty ? 0.0 : floor(args[0])
        case "ceil": return args.isEmpty ? 0.0 : ceil(args[0])
        case "round": return args.isEmpty ? 0.0 : round(args[0])
        default:
            print("⚠️ WORKLET: Unknown math function: \(functionName)")
            return 0.0
        }
    }
    
    /**
     * Execute property access (list.length, string.substring, etc.)
     */
    private static func executePropertyAccess(_ propertyAccess: String, arguments: [Any], context: [String: Any]) -> Any? {
        let parts = propertyAccess.split(separator: ".")
        guard parts.count == 2 else { return nil }
        
        let objectName = String(parts[0])
        let property = String(parts[1])
        guard let obj = context[objectName] else { return nil }
        
        switch property {
        case "length":
            if let list = obj as? [Any] {
                return Double(list.count)
            } else if let str = obj as? String {
                return Double(str.count)
            }
            return 0.0
            
        case "substring":
            guard let str = obj as? String else { return "" }
            if arguments.count >= 1, let start = (arguments[0] as? NSNumber)?.intValue {
                if arguments.count >= 2, let end = (arguments[1] as? NSNumber)?.intValue {
                    let startIdx = str.index(str.startIndex, offsetBy: max(0, min(start, str.count)))
                    let endIdx = str.index(str.startIndex, offsetBy: max(0, min(end, str.count)))
                    return String(str[startIdx..<endIdx])
                } else {
                    let startIdx = str.index(str.startIndex, offsetBy: max(0, min(start, str.count)))
                    return String(str[startIdx...])
                }
            }
            return str
            
        case "[]":
            // Index access
            if arguments.count >= 1, let index = (arguments[0] as? NSNumber)?.intValue {
                if let list = obj as? [Any], index >= 0 && index < list.count {
                    return list[index]
                } else if let str = obj as? String, index >= 0 && index < str.count {
                    let idx = str.index(str.startIndex, offsetBy: index)
                    return String(str[idx])
                }
            }
            return nil
            
        case "clamp":
            if let num = obj as? NSNumber, arguments.count >= 2,
               let minValue = (arguments[0] as? NSNumber)?.doubleValue,
               let maxValue = (arguments[1] as? NSNumber)?.doubleValue {
                let value = num.doubleValue
                return max(minValue, min(maxValue, value))
            }
            return obj
            
        case "floor":
            if let num = obj as? NSNumber {
                return floor(num.doubleValue)
            }
            return obj
            
        case "ceil":
            if let num = obj as? NSNumber {
                return ceil(num.doubleValue)
            }
            return obj
            
        case "round":
            if let num = obj as? NSNumber {
                return round(num.doubleValue)
            }
            return obj
            
        case "abs":
            if let num = obj as? NSNumber {
                return abs(num.doubleValue)
            }
            return obj
            
        default:
            return nil
        }
    }
    
    /**
     * Execute WorkletRuntime calls (Reanimated-like API).
     * Supports:
     * - WorkletRuntime.getView(viewId).setProperty(property, value)
     */
    private static func executeWorkletRuntimeCall(_ functionName: String, arguments: [Any]) -> Any? {
        // Parse function name like "WorkletRuntime.getView" or "WorkletRuntime.getView.setProperty"
        let parts = functionName.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        
        let apiName = String(parts[0]) // "WorkletRuntime"
        guard apiName == "WorkletRuntime" else { return nil }
        
        let method = String(parts[1]) // "getView"
        
        switch method {
        case "getView":
            // WorkletRuntime.getView(viewId)
            guard arguments.count >= 1,
                  let viewId = (arguments[0] as? NSNumber)?.intValue else {
                return nil
            }
            
            // Return a proxy object that can be chained
            if let viewProxy = dcflight.WorkletRuntime.getView(viewId) {
                // If this is part of a chain (e.g., .setProperty), handle it
                if parts.count >= 3 {
                    let chainMethod = String(parts[2])
                    return handleWorkletRuntimeChain(viewProxy, method: chainMethod, arguments: Array(arguments.dropFirst(1)))
                }
                // Otherwise return the proxy (for future chaining)
                return viewProxy
            }
            return nil
            
        default:
            return nil
        }
    }
    
    /**
     * Handle chained WorkletRuntime calls (e.g., getView(viewId).setProperty(...)).
     */
    private static func handleWorkletRuntimeChain(_ viewProxy: dcflight.WorkletViewProxy, method: String, arguments: [Any]) -> Any? {
        switch method {
        case "setProperty":
            // viewProxy.setProperty(property, value)
            guard arguments.count >= 2,
                  let property = arguments[0] as? String else {
                return nil
            }
            let value = arguments[1]
            viewProxy.setProperty(property, value)
            return true
            
        default:
            print("⚠️ WORKLET: Unknown WorkletRuntime method: \(method)")
            return nil
        }
    }
}

