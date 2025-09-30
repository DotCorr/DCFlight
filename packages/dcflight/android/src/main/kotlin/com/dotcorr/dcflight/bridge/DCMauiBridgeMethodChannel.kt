/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcflight.layout.ViewRegistry
import org.json.JSONObject

/**
 * Main method channel handler for DCFlight bridge
 */
class DCMauiBridgeMethodChannel : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "DCMauiBridgeMethodChannel"

        @JvmField
        val shared = DCMauiBridgeMethodChannel()

        fun initialize(binaryMessenger: io.flutter.plugin.common.BinaryMessenger) {
            val channel = MethodChannel(binaryMessenger, "com.dcmaui.bridge")
            channel.setMethodCallHandler(shared)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any>

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

    private fun handleTunnel(args: Map<String, Any>, result: Result) {
        val componentType = args["componentType"] as? String
        val method = args["method"] as? String
        val params = args["params"] as? Map<String, Any>

        if (componentType == null || method == null || params == null) {
            result.error("TUNNEL_ERROR", "Invalid tunnel parameters", null)
            return
        }

        Log.d(TAG, "Tunneling $method to $componentType")

        Handler(Looper.getMainLooper()).post {
            val componentClass = DCFComponentRegistry.shared.getComponent(componentType)
            if (componentClass == null) {
                result.error("COMPONENT_NOT_FOUND", "Component $componentType not registered", null)
                return@post
            }

            val response = DCMauiBridgeImpl.shared.handleTunnelMethod(componentType, method, params)
            if (response != null) {
                result.success(response)
            } else {
                result.error("METHOD_NOT_FOUND", "Method $method not found on $componentType", null)
            }
        }
    }

    private fun handleInitialize(result: Result) {
        Handler(Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.initialize()
            result.success(success)
        }
    }

    private fun handleCreateView(args: Map<String, Any>, result: Result) {
        val viewId = args["viewId"] as? String
        val viewType = args["viewType"] as? String
        val props = args["props"] as? Map<String, Any>

        if (viewId == null || viewType == null || props == null) {
            result.error("CREATE_ERROR", "Invalid view creation parameters", null)
            return
        }

        val propsJson = try {
            JSONObject(props).toString()
        } catch (e: Exception) {
            result.error("JSON_ERROR", "Failed to serialize props", null)
            return
        }

        Handler(Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.createView(viewId, viewType, propsJson)
            result.success(success)
        }
    }

    private fun handleUpdateView(args: Map<String, Any>, result: Result) {
        Log.d(TAG, "🔥 METHOD_CHANNEL: handleUpdateView called with args: $args")
        val viewId = args["viewId"] as? String
        val props = args["props"] as? Map<String, Any>

        if (viewId == null || props == null) {
            Log.e(TAG, "UPDATE_ERROR: Invalid view update parameters - viewId: $viewId, props: $props")
            result.error("UPDATE_ERROR", "Invalid view update parameters", null)
            return
        }

        Log.d(TAG, "🔥 METHOD_CHANNEL: updateView - viewId: $viewId, props: $props")

        val propsJson = try {
            JSONObject(props).toString()
        } catch (e: Exception) {
            Log.e(TAG, "JSON_ERROR: Failed to serialize props", e)
            result.error("JSON_ERROR", "Failed to serialize props", null)
            return
        }

        Log.d(TAG, "🔥 METHOD_CHANNEL: propsJson: $propsJson")

        Handler(Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.updateView(viewId, propsJson)
            Log.d(TAG, "🔥 METHOD_CHANNEL: updateView result: $success")
            result.success(success)
        }
    }

    private fun handleDeleteView(args: Map<String, Any>, result: Result) {
        val viewId = args["viewId"] as? String

        if (viewId == null) {
            result.error("DELETE_ERROR", "Invalid view ID", null)
            return
        }

        Handler(Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.deleteView(viewId)
            result.success(success)
        }
    }

    private fun handleAttachView(args: Map<String, Any>, result: Result) {
        val childId = args["childId"] as? String
        val parentId = args["parentId"] as? String
        val index = args["index"] as? Int

        if (childId == null || parentId == null || index == null) {
            result.error("ATTACH_ERROR", "Invalid view attachment parameters", null)
            return
        }

        Handler(Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.attachView(childId, parentId, index)
            result.success(success)
        }
    }

    private fun handleDetachView(args: Map<String, Any>, result: Result) {
        val viewId = args["viewId"] as? String

        if (viewId == null) {
            result.error("DETACH_ERROR", "Invalid view ID", null)
            return
        }

        Handler(Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.detachView(viewId)
            result.success(success)
        }
    }

    private fun handleSetChildren(args: Map<String, Any>, result: Result) {
        val viewId = args["viewId"] as? String
        val childrenIds = args["childrenIds"] as? List<String>

        if (viewId == null || childrenIds == null) {
            result.error("SET_CHILDREN_ERROR", "Invalid set children parameters", null)
            return
        }

        Handler(Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.setChildren(viewId, childrenIds)
            result.success(success)
        }
    }

    private fun handleCommitBatchUpdate(args: Map<String, Any>, result: Result) {
        val operations = args["operations"] as? List<Map<String, Any>>

        if (operations == null) {
            result.error("BATCH_ERROR", "Invalid batch operations", null)
            return
        }

        Handler(Looper.getMainLooper()).post {
            val success = DCMauiBridgeImpl.shared.commitBatchUpdate(operations)
            result.success(success)
        }
    }

    private fun getView(viewId: String, callback: (View?) -> Unit) {
        val view = ViewRegistry.shared.getView(viewId)
        callback(view)
    }
}