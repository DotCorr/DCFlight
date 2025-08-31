/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.util.Log
import com.dotcorr.dcflight.components.DCFComponentRegistry
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONObject
import org.json.JSONArray

class DCMauiBridgeMethodChannel private constructor() : MethodCallHandler {

    companion object {
        private const val TAG = "DCMauiBridge"
        // CRITICAL FIX: Match iOS channel names exactly
        private const val CHANNEL_NAME = "com.dcmaui.bridge"
        private const val HOT_RESTART_CHANNEL = "dcflight/hot_restart"

        @JvmStatic
        val shared = DCMauiBridgeMethodChannel()

        // CRITICAL FIX: Add session token for hot restart detection like iOS
        @Volatile
        private var sessionToken: String? = null
    }

    private var methodChannel: MethodChannel? = null
    private var hotRestartChannel: MethodChannel? = null

    // CRITICAL FIX: Add views dictionary for compatibility with iOS
    val views = mutableMapOf<String, android.view.View>()

    fun initialize(messenger: BinaryMessenger) {
        Log.d(TAG, "Initializing bridge method channel")

        // Create method channel - EXACT iOS channel name
        methodChannel = MethodChannel(messenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler(this)

        // Create hot restart detection channel - EXACT iOS channel name  
        hotRestartChannel = MethodChannel(messenger, HOT_RESTART_CHANNEL)
        hotRestartChannel?.setMethodCallHandler { call, result ->
            handleHotRestartMethodCall(call, result)
        }

        Log.d(TAG, "Bridge method channel initialized")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "Received method call: ${call.method}")

        // Get the arguments - EXACT iOS pattern
        val args = call.arguments as? Map<String, Any>

        // Handle methods - EXACT same method names as iOS
        when (call.method) {
            "initialize" -> {
                handleInitialize(result)
            }

            "createView" -> {
                if (args != null) {
                    handleCreateView(args, result)
                } else {
                    result.error("ARGS_ERROR", "Arguments cannot be null", null)
                }
            }

            "updateView" -> {
                if (args != null) {
                    handleUpdateView(args, result)
                } else {
                    result.error("ARGS_ERROR", "Arguments cannot be null", null)
                }
            }

            "deleteView" -> {
                if (args != null) {
                    handleDeleteView(args, result)
                } else {
                    result.error("ARGS_ERROR", "Arguments cannot be null", null)
                }
            }

            "attachView" -> {
                if (args != null) {
                    handleAttachView(args, result)
                } else {
                    result.error("ARGS_ERROR", "Arguments cannot be null", null)
                }
            }

            "detachView" -> {
                if (args != null) {
                    handleDetachView(args, result)
                } else {
                    result.error("ARGS_ERROR", "Arguments cannot be null", null)
                }
            }

            "setChildren" -> {
                if (args != null) {
                    handleSetChildren(args, result)
                } else {
                    result.error("ARGS_ERROR", "Arguments cannot be null", null)
                }
            }

            "commitBatchUpdate" -> {
                if (args != null) {
                    handleCommitBatchUpdate(args, result)
                } else {
                    result.error("ARGS_ERROR", "Arguments cannot be null", null)
                }
            }

            // CRITICAL FIX: Add missing tunnel method like iOS
            "tunnel" -> {
                if (args != null) {
                    handleTunnel(args, result)
                } else {
                    result.error("ARGS_ERROR", "Arguments cannot be null", null)
                }
            }

            else -> {
                Log.w(TAG, "Unknown method: ${call.method}")
                result.notImplemented()
            }
        }
    }

    // CRITICAL FIX: Add tunnel handler exactly like iOS
    private fun handleTunnel(args: Map<String, Any>, result: Result) {
        val componentType = args["componentType"] as? String
        val method = args["method"] as? String
        val params = args["params"] as? Map<String, Any>

        if (componentType == null || method == null || params == null) {
            result.error("TUNNEL_ERROR", "Invalid tunnel parameters", null)
            return
        }

        Log.d(TAG, "🚇 Android Bridge: Tunneling $method to $componentType")

        // Execute on main thread like iOS
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            // Use component registry to find component class
            val componentClass = DCFComponentRegistry.shared.getComponent(componentType)
            if (componentClass == null) {
                result.error("COMPONENT_NOT_FOUND", "Component $componentType not registered", null)
                return@post
            }

            // Call tunnel method on component class
            val response = componentClass.handleTunnelMethod(method, params)
            if (response != null) {
                result.success(response)
            } else {
                result.error("METHOD_NOT_FOUND", "Method $method not found on $componentType", null)
            }
        }
    }

    // Initialize the bridge
    private fun handleInitialize(result: Result) {
        // Execute on main thread like iOS
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            // Initialize components and systems
            val success = DCMauiBridgeImpl.shared.initialize()
            result.success(success)
        }
    }

    // Create a view - EXACT iOS signature and JSON handling
    private fun handleCreateView(args: Map<String, Any>, result: Result) {
        val viewId = args["viewId"] as? String
        val viewType = args["viewType"] as? String
        val props = args["props"] as? Map<String, Any>

        if (viewId == null || viewType == null || props == null) {
            result.error("CREATE_ERROR", "Invalid view creation parameters", null)
            return
        }

        // CRITICAL FIX: Convert props to JSON like iOS
        val propsJson = try {
            JSONObject(props).toString()
        } catch (e: Exception) {
            result.error("JSON_ERROR", "Failed to serialize props", null)
            return
        }

        // Execute on main thread like iOS
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.createView(viewId, viewType, propsJson)
            result.success(success)
        }
    }

    // Update a view - EXACT iOS signature and JSON handling
    private fun handleUpdateView(args: Map<String, Any>, result: Result) {
        val viewId = args["viewId"] as? String
        val props = args["props"] as? Map<String, Any>

        if (viewId == null || props == null) {
            result.error("UPDATE_ERROR", "Invalid view update parameters", null)
            return
        }

        // CRITICAL FIX: Convert props to JSON like iOS
        val propsJson = try {
            JSONObject(props).toString()
        } catch (e: Exception) {
            result.error("JSON_ERROR", "Failed to serialize props", null)
            return
        }

        // Execute on main thread like iOS
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.updateView(viewId, propsJson)
            result.success(success)
        }
    }

    // Delete a view - EXACT iOS pattern
    private fun handleDeleteView(args: Map<String, Any>, result: Result) {
        val viewId = args["viewId"] as? String

        if (viewId == null) {
            result.error("DELETE_ERROR", "Invalid view ID", null)
            return
        }

        // Execute on main thread like iOS
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.deleteView(viewId)
            result.success(success)
        }
    }

    // CRITICAL FIX: Add missing attachView method like iOS
    private fun handleAttachView(args: Map<String, Any>, result: Result) {
        val childId = args["childId"] as? String
        val parentId = args["parentId"] as? String
        val index = args["index"] as? Int

        if (childId == null || parentId == null || index == null) {
            result.error("ATTACH_ERROR", "Invalid view attachment parameters", null)
            return
        }

        // Execute on main thread like iOS
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.attachView(childId, parentId, index)
            result.success(success)
        }
    }

    // CRITICAL FIX: Add missing detachView method like iOS
    private fun handleDetachView(args: Map<String, Any>, result: Result) {
        val viewId = args["viewId"] as? String

        if (viewId == null) {
            result.error("DETACH_ERROR", "Invalid view ID", null)
            return
        }

        // Execute on main thread like iOS
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.detachView(viewId)
            result.success(success)
        }
    }

    // CRITICAL FIX: Add missing setChildren method like iOS
    private fun handleSetChildren(args: Map<String, Any>, result: Result) {
        val viewId = args["viewId"] as? String
        val childrenIds = args["childrenIds"] as? List<String>

        if (viewId == null || childrenIds == null) {
            result.error("CHILDREN_ERROR", "Invalid children parameters", null)
            return
        }

        // Convert children to JSON like iOS
        val childrenJson = try {
            JSONArray(childrenIds).toString()
        } catch (e: Exception) {
            result.error("JSON_ERROR", "Failed to serialize children", null)
            return
        }

        // Execute on main thread like iOS
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.setChildren(viewId, childrenJson)
            result.success(success)
        }
    }

    // CRITICAL FIX: Add missing commitBatchUpdate method like iOS
    private fun handleCommitBatchUpdate(args: Map<String, Any>, result: Result) {
        val updates = args["updates"] as? List<Map<String, Any>>

        if (updates == null) {
            result.error("BATCH_ERROR", "Invalid batch update parameters", null)
            return
        }

        // Execute on main thread like iOS
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            var allSucceeded = true

            for (update in updates) {
                val operation = update["operation"] as? String ?: continue

                when (operation) {
                    "createView" -> {
                        val viewId = update["viewId"] as? String ?: continue
                        val viewType = update["viewType"] as? String ?: continue
                        val props = update["props"] as? Map<String, Any> ?: emptyMap()

                        val propsJson = try {
                            JSONObject(props).toString()
                        } catch (e: Exception) {
                            allSucceeded = false
                            continue
                        }

                        val success = DCMauiBridgeImpl.shared.createView(viewId, viewType, propsJson)
                        if (!success) {
                            allSucceeded = false
                        }
                    }

                    "updateView" -> {
                        val viewId = update["viewId"] as? String ?: continue
                        val props = update["props"] as? Map<String, Any> ?: emptyMap()

                        val propsJson = try {
                            JSONObject(props).toString()
                        } catch (e: Exception) {
                            allSucceeded = false
                            continue
                        }

                        val success = DCMauiBridgeImpl.shared.updateView(viewId, propsJson)
                        if (!success) {
                            allSucceeded = false
                        }
                    }
                }
            }

            result.success(allSucceeded)
        }
    }

    // CRITICAL FIX: Add hot restart detection exactly like iOS
    private fun handleHotRestartMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getSessionToken" -> {
                result.success(sessionToken)
            }

            "createSessionToken" -> {
                // Create a new session token with timestamp like iOS
                val token = "dcf_session_${System.currentTimeMillis()}"
                sessionToken = token
                result.success(token)
            }

            "cleanupViews" -> {
                cleanupNativeViews()
                result.success(null)
            }

            "clearSessionToken" -> {
                sessionToken = null
                result.success(null)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    // CRITICAL FIX: Add cleanup method exactly like iOS
    private fun cleanupNativeViews() {
        Log.d(TAG, "Cleaning up native views for hot restart")

        // Clean up DCMauiBridgeImpl views (preserves root)
        DCMauiBridgeImpl.shared.cleanupForHotRestart()

        // Clear the view registry (preserves root) - would need to add this method
        // ViewRegistry.shared.clearAll()

        // Reset Yoga shadow tree (preserves root)
        // YogaShadowTree.shared.clearAll()

        // Reset layout manager (preserves root)
        // DCFLayoutManager.shared.clearAll()
    }

    // CRITICAL FIX: Add helper to get view by ID like iOS
    fun getViewById(viewId: String): android.view.View? {
        // First try our local views dictionary
        views[viewId]?.let { return it }

        // Then try DCMauiBridgeImpl's views  
        DCMauiBridgeImpl.shared.getView(viewId)?.let { return it }

        return null
    }

    fun cleanup() {
        Log.d(TAG, "Cleaning up bridge method channel")
        methodChannel?.setMethodCallHandler(null)
        hotRestartChannel?.setMethodCallHandler(null)
        methodChannel = null
        hotRestartChannel = null
    }
}

