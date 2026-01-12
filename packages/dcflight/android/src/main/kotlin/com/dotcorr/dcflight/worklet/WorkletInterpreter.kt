/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.worklet

import android.util.Log
import kotlin.math.*

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
object WorkletInterpreter {
    private const val TAG = "WorkletInterpreter"
    
    /**
     * Execute a worklet by interpreting its IR
     * 
     * @param ir The serialized IR from Dart
     * @param elapsed Elapsed time (first parameter, usually)
     * @param config Additional parameters from workletConfig
     * @return The result of worklet execution
     */
    fun execute(ir: Map<String, Any?>, elapsed: Double, config: Map<String, Any?>?): Any? {
        try {
            val body = ir["body"] as? Map<String, Any?> ?: return null
            val returnType = ir["returnType"] as? String ?: "dynamic"
            
            // Build context with elapsed time and config parameters
            val context = mutableMapOf<String, Any?>(
                "elapsed" to elapsed
            )
            
            // Add parameters from config
            config?.forEach { (key, value) ->
                context[key] = value
            }
            
            // Interpret the body
            val result = interpretNode(body, context)
            
            // Convert result to appropriate type
            return when (returnType) {
                "double", "int" -> (result as? Number)?.toDouble() ?: 0.0
                "String" -> result?.toString() ?: ""
                "bool" -> result as? Boolean ?: false
                else -> result
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error interpreting worklet: ${e.message}", e)
            return null
        }
    }
    
    /**
     * Interpret a single IR node
     */
    private fun interpretNode(node: Map<String, Any?>, context: Map<String, Any?>): Any? {
        val type = node["type"] as? String ?: return null
        
        return when (type) {
            "literal" -> {
                val value = node["value"]
                val valueType = node["valueType"] as? String ?: "dynamic"
                when (valueType) {
                    "double" -> (value as? Number)?.toDouble() ?: 0.0
                    "int" -> (value as? Number)?.toInt() ?: 0
                    "String" -> value?.toString() ?: ""
                    "bool" -> value as? Boolean ?: false
                    else -> value
                }
            }
            
            "variable" -> {
                val name = node["name"] as? String ?: return null
                context[name] ?: 0.0
            }
            
            "binaryOp" -> {
                val operator = node["operator"] as? String ?: return null
                val left = interpretNode(node["left"] as Map<String, Any?>, context) as? Number ?: return null
                val right = interpretNode(node["right"] as Map<String, Any?>, context) as? Number ?: return null
                
                val leftDouble = left.toDouble()
                val rightDouble = right.toDouble()
                
                when (operator) {
                    "add" -> leftDouble + rightDouble
                    "subtract" -> leftDouble - rightDouble
                    "multiply" -> leftDouble * rightDouble
                    "divide" -> if (rightDouble != 0.0) leftDouble / rightDouble else 0.0
                    "modulo" -> leftDouble % rightDouble
                    "equals" -> if (leftDouble == rightDouble) 1.0 else 0.0
                    "notEquals" -> if (leftDouble != rightDouble) 1.0 else 0.0
                    "lessThan" -> if (leftDouble < rightDouble) 1.0 else 0.0
                    "greaterThan" -> if (leftDouble > rightDouble) 1.0 else 0.0
                    "lessThanOrEqual" -> if (leftDouble <= rightDouble) 1.0 else 0.0
                    "greaterThanOrEqual" -> if (leftDouble >= rightDouble) 1.0 else 0.0
                    "and" -> if (leftDouble != 0.0 && rightDouble != 0.0) 1.0 else 0.0
                    "or" -> if (leftDouble != 0.0 || rightDouble != 0.0) 1.0 else 0.0
                    else -> {
                        Log.w(TAG, "Unknown binary operator: $operator")
                        0.0
                    }
                }
            }
            
            "unaryOp" -> {
                val operator = node["operator"] as? String ?: return null
                val operand = interpretNode(node["operand"] as Map<String, Any?>, context) as? Number ?: return null
                val operandDouble = operand.toDouble()
                
                when (operator) {
                    "negate" -> -operandDouble
                    "not" -> if (operandDouble == 0.0) 1.0 else 0.0
                    else -> {
                        Log.w(TAG, "Unknown unary operator: $operator")
                        operandDouble
                    }
                }
            }
            
            "functionCall" -> {
                val functionName = node["functionName"] as? String ?: return null
                val arguments = (node["arguments"] as? List<Map<String, Any?>>)?.map { 
                    interpretNode(it, context) 
                } ?: emptyList()
                
                // Handle WorkletRuntime calls (Reanimated-like API)
                when {
                    functionName.startsWith("WorkletRuntime.") -> {
                        executeWorkletRuntimeCall(functionName, arguments, context)
                    }
                    functionName.startsWith("Math.") -> {
                        val func = functionName.substring(5)
                        executeMathFunction(func, arguments)
                    }
                    functionName.contains(".") -> {
                        // Handle property access (list.length, string.substring, etc.)
                        executePropertyAccess(functionName, arguments, context)
                    }
                    else -> {
                        executeMathFunction(functionName, arguments)
                    }
                }
            }
            
            "conditional" -> {
                val condition = interpretNode(node["condition"] as Map<String, Any?>, context) as? Number ?: return null
                val thenBranch = node["thenBranch"] as? Map<String, Any?>
                val elseBranch = node["elseBranch"] as? Map<String, Any?>?
                
                if (condition.toDouble() != 0.0) {
                    thenBranch?.let { interpretNode(it, context) }
                } else {
                    elseBranch?.let { interpretNode(it, context) }
                }
            }
            
            "returnStatement" -> {
                val expression = node["expression"] as? Map<String, Any?>?
                expression?.let { interpretNode(it, context) }
            }
            
            else -> {
                Log.w(TAG, "Unknown node type: $type")
                null
            }
        }
    }
    
    /**
     * Execute a math function
     */
    private fun executeMathFunction(functionName: String, arguments: List<Any?>): Double {
        val args = arguments.mapNotNull { (it as? Number)?.toDouble() }
        
        return when (functionName) {
            "sin" -> if (args.isNotEmpty()) sin(args[0]) else 0.0
            "cos" -> if (args.isNotEmpty()) cos(args[0]) else 0.0
            "tan" -> if (args.isNotEmpty()) tan(args[0]) else 0.0
            "asin" -> if (args.isNotEmpty()) asin(args[0]) else 0.0
            "acos" -> if (args.isNotEmpty()) acos(args[0]) else 0.0
            "atan" -> if (args.isNotEmpty()) atan(args[0]) else 0.0
            "atan2" -> if (args.size >= 2) atan2(args[0], args[1]) else 0.0
            "exp" -> if (args.isNotEmpty()) exp(args[0]) else 0.0
            "log" -> if (args.isNotEmpty()) ln(args[0]) else 0.0
            "log10" -> if (args.isNotEmpty()) log10(args[0]) else 0.0
            "sqrt" -> if (args.isNotEmpty()) sqrt(args[0]) else 0.0
            "pow" -> if (args.size >= 2) Math.pow(args[0], args[1]) else 0.0
            "abs" -> if (args.isNotEmpty()) abs(args[0]) else 0.0
            "max" -> if (args.isNotEmpty()) args.maxOrNull() ?: 0.0 else 0.0
            "min" -> if (args.isNotEmpty()) args.minOrNull() ?: 0.0 else 0.0
            "floor" -> if (args.isNotEmpty()) floor(args[0]) else 0.0
            "ceil" -> if (args.isNotEmpty()) ceil(args[0]) else 0.0
            "round" -> if (args.isNotEmpty()) round(args[0]) else 0.0
            else -> {
                Log.w(TAG, "Unknown math function: $functionName")
                0.0
            }
        }
    }
    
    /**
     * Execute property access (list.length, string.substring, etc.)
     */
    private fun executePropertyAccess(propertyAccess: String, arguments: List<Any?>, context: Map<String, Any?>): Any? {
        val parts = propertyAccess.split(".")
        if (parts.size != 2) return null
        
        val objectName = parts[0]
        val property = parts[1]
        val obj = context[objectName]
        
        return when (property) {
            "length" -> {
                when (obj) {
                    is List<*> -> obj.size.toDouble()
                    is String -> obj.length.toDouble()
                    else -> 0.0
                }
            }
            "substring" -> {
                if (obj is String && arguments.size >= 1) {
                    val start = (arguments[0] as? Number)?.toInt() ?: 0
                    if (arguments.size >= 2) {
                        val end = (arguments[1] as? Number)?.toInt() ?: obj.length
                        obj.substring(start, end.coerceIn(0, obj.length))
                    } else {
                        obj.substring(start.coerceIn(0, obj.length))
                    }
                } else {
                    ""
                }
            }
            "[]" -> {
                // Index access
                if (arguments.isNotEmpty()) {
                    val index = (arguments[0] as? Number)?.toInt() ?: 0
                    when (obj) {
                        is List<*> -> obj.getOrNull(index)
                        is String -> obj.getOrNull(index)?.toString()
                        else -> null
                    }
                } else {
                    null
                }
            }
            "clamp" -> {
                if (obj is Number && arguments.size >= 2) {
                    val value = obj.toDouble()
                    val min = (arguments[0] as? Number)?.toDouble() ?: 0.0
                    val max = (arguments[1] as? Number)?.toDouble() ?: 0.0
                    value.coerceIn(min, max)
                } else {
                    obj
                }
            }
            else -> null
        }
    }
    
    /**
     * Execute WorkletRuntime calls (Reanimated-like API).
     * Supports:
     * - WorkletRuntime.getView(viewId).setProperty(property, value)
     */
    private fun executeWorkletRuntimeCall(functionName: String, arguments: List<Any?>, context: Map<String, Any?>): Any? {
        // Parse function name like "WorkletRuntime.getView" or "WorkletRuntime.getView.setProperty"
        val parts = functionName.split(".")
        if (parts.size < 2) return null
        
        val apiName = parts[0] // "WorkletRuntime"
        if (apiName != "WorkletRuntime") return null
        
        val method = parts[1] // "getView"
        
        return when (method) {
            "getView" -> {
                // WorkletRuntime.getView(viewId)
                if (arguments.isNotEmpty()) {
                    val viewId = (arguments[0] as? Number)?.toInt() ?: return null
                    
                    // Return a proxy object that can be chained
                    val viewProxy = WorkletRuntime.getView(viewId)
                    if (viewProxy != null) {
                        // If this is part of a chain (e.g., .setProperty), handle it
                        if (parts.size >= 3) {
                            val chainMethod = parts[2]
                            handleWorkletRuntimeChain(viewProxy, chainMethod, arguments.drop(1))
                        } else {
                            // Otherwise return the proxy (for future chaining)
                            viewProxy
                        }
                    } else {
                        null
                    }
                } else {
                    null
                }
            }
            else -> null
        }
    }
    
    /**
     * Handle chained WorkletRuntime calls (e.g., getView(viewId).setProperty(...)).
     */
    private fun handleWorkletRuntimeChain(viewProxy: WorkletViewProxy, method: String, arguments: List<Any?>): Any? {
        return when (method) {
            "setProperty" -> {
                // viewProxy.setProperty(property, value)
                if (arguments.size >= 2) {
                    val property = arguments[0] as? String ?: return null
                    val value = arguments[1]
                    viewProxy.setProperty(property, value)
                    true
                } else {
                    null
                }
            }
            else -> {
                Log.w(TAG, "Unknown WorkletRuntime method: $method")
                null
            }
        }
    }
}

