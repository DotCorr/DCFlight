/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFFrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.*

import com.dotcorr.dcflight.bridge.DCMauiBridgeImpl
import com.dotcorr.dcflight.bridge.DCMauiBridgeMethodChannel
import com.dotcorr.dcflight.bridge.DCMauiEventMethodHandler
import com.dotcorr.dcflight.bridge.DCMauiLayoutMethodHandler

import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.DCFLayoutManager

import com.dotcorr.dcflight.components.FrameworkComponentsReg
import com.dotcorr.dcflight.components.DCFComponentRegistry

import com.dotcorr.dcflight.utils.DCFScreenUtilities

object DCDivergerUtil {
    private const val TAG = "DCDivergerUtil"
    private const val ENGINE_ID = "io.dcflight.engine"

    private var rootView: ViewGroup? = null
    private var flutterView: FlutterView? = null
    private var mainScope = MainScope()

    @JvmStatic
    fun divergeToFlight(activity: Activity, pluginBinding: FlutterPlugin.FlutterPluginBinding?) {
        Log.d(TAG, "Starting divergeToFlight")

        val flutterEngine = getOrCreateFlutterEngine(activity, pluginBinding)

        if (flutterEngine == null) {
            Log.e(TAG, "Failed to get or create Flutter engine")
            return
        }

        flutterView = FlutterView(activity).apply {
            visibility = View.GONE
        }
        flutterView?.attachToFlutterEngine(flutterEngine)

        // Method channels are already initialized in plugin registration
        // Don't reinitialize them here as it overwrites the Flutter handlers
        // initializeMethodChannels(flutterEngine.dartExecutor.binaryMessenger)

        setupNativeContainer(activity)

        initializeDCFlightSystems(activity, flutterEngine.dartExecutor.binaryMessenger)

        registerComponents()

        Log.d(TAG, "DCFlight diverger initialized successfully")
    }

    private fun getOrCreateFlutterEngine(
        activity: Activity,
        pluginBinding: FlutterPlugin.FlutterPluginBinding?
    ): FlutterEngine? {
        return try {
            // 🚀 CRITICAL FIX: Use the EXISTING engine from plugin binding like iOS!
            // Don't create a new engine - use the one that already has our plugins registered!
            pluginBinding?.flutterEngine ?: FlutterEngineCache.getInstance().get(ENGINE_ID)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get Flutter engine", e)
            null
        }
    }    private fun initializeMethodChannels(binaryMessenger: BinaryMessenger) {
        try {
            io.flutter.plugin.common.MethodChannel(
                binaryMessenger,
                "com.dcmaui.bridge"
            ).setMethodCallHandler(DCMauiBridgeMethodChannel())

            io.flutter.plugin.common.MethodChannel(
                binaryMessenger,
                "com.dcmaui.events"
            ).setMethodCallHandler(DCMauiEventMethodHandler.getInstance())

            io.flutter.plugin.common.MethodChannel(
                binaryMessenger,
                "com.dcmaui.layout"
            ).setMethodCallHandler(DCMauiLayoutMethodHandler())

            Log.d(TAG, "Method channels initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize method channels", e)
        }
    }

    private fun setupNativeContainer(activity: Activity) {
        try {
            // 🚀 CRITICAL FIX: Prevent UI destruction on background/foreground transitions
            // If rootView already exists, just return - don't recreate like iOS
            if (rootView != null) {
                Log.d(TAG, "Native container already exists, preserving UI state")
                return
            }

            rootView = DCFFrameLayout(activity).apply {
                setBackgroundColor(Color.WHITE)
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            }

            if (activity is FlutterActivity) {
                // Replace Flutter content with native content (like iOS does)
                val contentView = activity.findViewById<ViewGroup>(android.R.id.content)
                
                // Remove all Flutter views
                contentView?.removeAllViews()
                
                // Add our native root view as the only content
                contentView?.addView(rootView)
                
                Log.d(TAG, "Replaced Flutter content with native DCF content")
            }

            Log.d(TAG, "Native container setup complete")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup native container", e)
        }
    }

    private fun initializeDCFlightSystems(activity: Activity, binaryMessenger: BinaryMessenger) {
        try {
            val context = activity.applicationContext

            DCMauiBridgeImpl.shared.setContext(context)

            // Initialize systems - but preserve existing state like iOS does!
            // Don't clear views when returning from background
            Log.d(TAG, "Ensuring DCFlight systems are initialized")
            // DCFLayoutManager and YogaShadowTree are already initialized as singletons

            DCFScreenUtilities.initialize(binaryMessenger, context)

            rootView?.let { root ->
                com.dotcorr.dcflight.layout.ViewRegistry.shared.registerView(root, "root", "View")
                DCFLayoutManager.shared.registerView(root, "root")
            }

            Log.d(TAG, "DCFlight systems initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize DCFlight systems", e)
        }
    }

    private fun registerComponents() {
        try {
            FrameworkComponentsReg.registerComponents()
            Log.d(TAG, "Components registered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register components", e)
        }
    }

    fun cleanup() {
        try {
            mainScope.cancel()
            rootView = null
            flutterView = null
            Log.d(TAG, "Cleanup complete")
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }
}

