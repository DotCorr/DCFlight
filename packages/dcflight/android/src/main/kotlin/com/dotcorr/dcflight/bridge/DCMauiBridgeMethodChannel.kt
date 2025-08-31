/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.bridge

import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap

class DCMauiBridgeMethodChannel private constructor() : MethodCallHandler {
    private var channel: MethodChannel? = null
    private val mainScope = MainScope()
    private val sessionToken = System.currentTimeMillis().toString()
    private var isInitialized = false

    companion object {
        private const val TAG = "DCMauiBridge"
        private const val CHANNEL_NAME = "dcflight/bridge"

        @JvmStatic
        val shared = DCMauiBridgeMethodChannel()

        // Command queue for batching
        private val commandQueue = mutableListOf<Map<String, Any?>>()
        private var queueJob: Job? = null
    }

    fun initialize(messenger: BinaryMessenger) {
        if (isInitialized) {
            Log.w(TAG, "Already initialized, checking for hot restart")
            detectHotRestart(messenger)
            return
        }

        Log.d(TAG, "Initializing bridge method channel")

        channel = MethodChannel(messenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)

        isInitialized = true

        // Send initial session token
        sendSessionToken()

        Log.d(TAG, "Bridge method channel initialized")
    }

    private fun detectHotRestart(messenger: BinaryMessenger) {
        // Re-initialize channel for hot restart
        channel?.setMethodCallHandler(null)
        channel = MethodChannel(messenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)

        // Check session token to detect hot restart
        channel?.invokeMethod("checkSessionToken", sessionToken)
    }

    private fun sendSessionToken() {
        channel?.invokeMethod("setSessionToken", sessionToken)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "Received method call: ${call.method}")

        when (call.method) {
            "createView" -> handleCreateView(call, result)
            "updateView" -> handleUpdateView(call, result)
            "removeView" -> handleRemoveView(call, result)
            "batchUpdate" -> handleBatchUpdate(call, result)
            "measureText" -> handleMeasureText(call, result)
            "getScreenDimensions" -> handleGetScreenDimensions(result)
            "hotRestartDetected" -> handleHotRestart(result)
            "ping" -> result.success("pong")
            else -> {
                Log.w(TAG, "Unknown method: ${call.method}")
                result.notImplemented()
            }
        }
    }

    private fun handleCreateView(call: MethodCall, result: Result) {
        val viewId = call.argument<String>("viewId")
        val viewType = call.argument<String>("viewType")
        val props = call.argument<Map<String, Any?>>("props")

        if (viewId == null || viewType == null) {
            result.error("INVALID_ARGS", "viewId and viewType are required", null)
            return
        }

        Log.d(TAG, "Creating view: $viewId of type: $viewType")

        mainScope.launch {
            try {
                val created = DCMauiBridgeImpl.shared.createView(viewId, viewType, props ?: emptyMap())
                withContext(Dispatchers.Main) {
                    result.success(created)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error creating view", e)
                withContext(Dispatchers.Main) {
                    result.error("CREATE_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleUpdateView(call: MethodCall, result: Result) {
        val viewId = call.argument<String>("viewId")
        val props = call.argument<Map<String, Any?>>("props")

        if (viewId == null) {
            result.error("INVALID_ARGS", "viewId is required", null)
            return
        }

        Log.d(TAG, "Updating view: $viewId")

        // Queue the update for batching
        queueCommand(mapOf(
            "action" to "update",
            "viewId" to viewId,
            "props" to props
        ))

        result.success(true)
    }

    private fun handleRemoveView(call: MethodCall, result: Result) {
        val viewId = call.argument<String>("viewId")

        if (viewId == null) {
            result.error("INVALID_ARGS", "viewId is required", null)
            return
        }

        Log.d(TAG, "Removing view: $viewId")

        mainScope.launch {
            try {
                val removed = DCMauiBridgeImpl.shared.removeView(viewId)
                withContext(Dispatchers.Main) {
                    result.success(removed)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error removing view", e)
                withContext(Dispatchers.Main) {
                    result.error("REMOVE_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleBatchUpdate(call: MethodCall, result: Result) {
        val commands = call.argument<List<Map<String, Any?>>>("commands")

        if (commands == null) {
            result.error("INVALID_ARGS", "commands are required", null)
            return
        }

        Log.d(TAG, "Processing batch update with ${commands.size} commands")

        mainScope.launch {
            try {
                processBatchCommands(commands)
                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing batch", e)
                withContext(Dispatchers.Main) {
                    result.error("BATCH_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleMeasureText(call: MethodCall, result: Result) {
        val text = call.argument<String>("text") ?: ""
        val fontSize = call.argument<Double>("fontSize") ?: 14.0
        val fontWeight = call.argument<String>("fontWeight") ?: "normal"
        val maxWidth = call.argument<Double>("maxWidth")

        Log.d(TAG, "Measuring text: '$text'")

        mainScope.launch {
            try {
                val measurements = DCMauiBridgeImpl.shared.measureText(
                    text,
                    fontSize.toFloat(),
                    fontWeight,
                    maxWidth?.toFloat()
                )
                withContext(Dispatchers.Main) {
                    result.success(measurements)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error measuring text", e)
                withContext(Dispatchers.Main) {
                    result.error("MEASURE_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleGetScreenDimensions(result: Result) {
        val dimensions = DCFScreenUtilities.shared.getScreenDimensions()
        result.success(dimensions)
    }

    private fun handleHotRestart(result: Result) {
        Log.d(TAG, "Hot restart detected, cleaning up native views")

        mainScope.launch {
            try {
                // Clean up all native views
                DCMauiBridgeImpl.shared.cleanup()

                // Reinitialize systems
                YogaShadowTree.shared.cleanup()
                YogaShadowTree.shared.initialize()

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error handling hot restart", e)
                withContext(Dispatchers.Main) {
                    result.error("HOTRESTART_ERROR", e.message, null)
                }
            }
        }
    }

    private fun queueCommand(command: Map<String, Any?>) {
        synchronized(commandQueue) {
            commandQueue.add(command)
        }

        // Cancel existing job and start new one with delay for batching
        queueJob?.cancel()
        queueJob = mainScope.launch {
            delay(16) // ~60fps
            flushCommandQueue()
        }
    }

    private suspend fun flushCommandQueue() {
        val commands = synchronized(commandQueue) {
            val copy = commandQueue.toList()
            commandQueue.clear()
            copy
        }

        if (commands.isNotEmpty()) {
            Log.d(TAG, "Flushing ${commands.size} queued commands")
            processBatchCommands(commands)
        }
    }

    private suspend fun processBatchCommands(commands: List<Map<String, Any?>>) {
        withContext(Dispatchers.Main) {
            commands.forEach { command ->
                when (command["action"]) {
                    "update" -> {
                        val viewId = command["viewId"] as? String
                        val props = command["props"] as? Map<String, Any?>
                        if (viewId != null) {
                            DCMauiBridgeImpl.shared.updateView(viewId, props ?: emptyMap())
                        }
                    }
                    "create" -> {
                        val viewId = command["viewId"] as? String
                        val viewType = command["viewType"] as? String
                        val props = command["props"] as? Map<String, Any?>
                        if (viewId != null && viewType != null) {
                            DCMauiBridgeImpl.shared.createView(viewId, viewType, props ?: emptyMap())
                        }
                    }
                    "remove" -> {
                        val viewId = command["viewId"] as? String
                        if (viewId != null) {
                            DCMauiBridgeImpl.shared.removeView(viewId)
                        }
                    }
                }
            }
        }
    }

    fun cleanup() {
        Log.d(TAG, "Cleaning up bridge method channel")

        queueJob?.cancel()
        mainScope.cancel()
        channel?.setMethodCallHandler(null)
        channel = null
        commandQueue.clear()
        isInitialized = false

        Log.d(TAG, "Bridge cleanup complete")
    }
}
