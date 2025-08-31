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
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.*

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

        // Create Flutter view but keep it hidden
        flutterView = FlutterView(activity).apply {
            visibility = View.GONE
        }
        flutterView?.attachToFlutterEngine(flutterEngine)

        // Initialize method channels
        initializeMethodChannels(flutterEngine.dartExecutor.binaryMessenger)

        // Create native root view
        setupNativeRootView(activity)

        // Initialize DCF systems
        setupDCF(activity)

        // Setup size change detection
        setupSizeChangeDetection(activity)

        Log.d(TAG, "DCFlight divergence complete")
    }

    private fun getOrCreateFlutterEngine(
        activity: Activity,
        pluginBinding: FlutterPlugin.FlutterPluginBinding?
    ): FlutterEngine? {
        // Try to get from plugin binding first
        pluginBinding?.let {
            Log.d(TAG, "Using Flutter engine from plugin binding")
            return it.flutterEngine
        }

        // Try to get from cache
        var engine = FlutterEngineCache.getInstance().get(ENGINE_ID)
        if (engine != null) {
            Log.d(TAG, "Using cached Flutter engine")
            return engine
        }

        // Try to get from FlutterActivity
        if (activity is FlutterActivity) {
            engine = activity.flutterEngine
            if (engine != null) {
                Log.d(TAG, "Using Flutter engine from FlutterActivity")
                return engine
            }
        }

        // Create new engine as last resort
        Log.d(TAG, "Creating new Flutter engine")
        engine = FlutterEngine(activity).apply {
            dartExecutor.executeDartEntrypoint(
                io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint.createDefault()
            )
        }

        // Cache the new engine
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)

        return engine
    }

    private fun initializeMethodChannels(binaryMessenger: BinaryMessenger) {
        Log.d(TAG, "Initializing method channels")

        DCMauiBridgeMethodChannel.shared.initialize(binaryMessenger)
        DCMauiEventMethodHandler.shared.initialize(binaryMessenger)
        DCMauiLayoutMethodHandler.shared.initialize(binaryMessenger)

        Log.d(TAG, "Method channels initialized")
    }

    private fun setupNativeRootView(activity: Activity) {
        Log.d(TAG, "Setting up native root view")

        // Create root container
        rootView = FrameLayout(activity).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.WHITE)
            id = View.generateViewId()
        }

        // Replace activity content with our root view
        activity.setContentView(rootView)

        Log.d(TAG, "Native root view setup complete")
    }

    private fun setupDCF(context: Context) {
        Log.d(TAG, "Setting up DCF systems")

        // Register root view with bridge
        rootView?.let { view ->
            DCMauiBridgeImpl.shared.registerView(view, "root")
        }

        // Initialize core systems
        YogaShadowTree.shared.initialize()
        DCFLayoutManager.shared.initialize()
        DCFScreenUtilities.shared.initialize(null)

        // Register framework components
        runInternalModules()

        // Update initial window size
        mainScope.launch {
            delay(100) // Small delay to ensure everything is ready
            updateInitialWindowSize()
        }

        Log.d(TAG, "DCF systems setup complete")
    }

    private fun runInternalModules() {
        Log.d(TAG, "Registering framework components")
        FrameworkComponentsReg.registerComponents()
    }

    private fun setupSizeChangeDetection(activity: Activity) {
        Log.d(TAG, "Setting up size change detection")

        rootView?.addOnLayoutChangeListener { view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom ->
            val width = right - left
            val height = bottom - top
            val oldWidth = oldRight - oldLeft
            val oldHeight = oldBottom - oldTop

            if (width != oldWidth || height != oldHeight) {
                Log.d(TAG, "Layout size changed: ${width}x${height} (was ${oldWidth}x${oldHeight})")
                onSizeChanged(width, height)
            }
        }

        // Monitor configuration changes
        activity.window.decorView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            rootView?.let { view ->
                val width = view.width
                val height = view.height
                if (width > 0 && height > 0) {
                    updateScreenDimensions(width, height)
                }
            }
        }

        Log.d(TAG, "Size change detection setup complete")
    }

    private fun onSizeChanged(width: Int, height: Int) {
        Log.d(TAG, "Handling size change: ${width}x${height}")

        // Update screen dimensions
        DCFScreenUtilities.shared.updateScreenDimensions(width.toFloat(), height.toFloat())

        // Recalculate layout
        YogaShadowTree.shared.calculateAndApplyLayout(width.toFloat(), height.toFloat())
    }

    private fun updateInitialWindowSize() {
        rootView?.let { view ->
            val width = view.width
            val height = view.height

            if (width > 0 && height > 0) {
                Log.d(TAG, "Initial window size: ${width}x${height}")
                onSizeChanged(width, height)
            } else {
                Log.w(TAG, "Root view not ready, scheduling retry")
                mainScope.launch {
                    delay(100)
                    updateInitialWindowSize()
                }
            }
        }
    }

    private fun updateScreenDimensions(width: Int, height: Int) {
        if (width > 0 && height > 0) {
            DCFScreenUtilities.shared.updateScreenDimensions(width.toFloat(), height.toFloat())
            YogaShadowTree.shared.calculateAndApplyLayout(width.toFloat(), height.toFloat())
        }
    }

    fun cleanup() {
        Log.d(TAG, "Cleaning up DCDivergerUtil")

        mainScope.cancel()

        flutterView?.detachFromFlutterEngine()
        flutterView = null

        rootView?.removeAllViews()
        rootView = null

        Log.d(TAG, "Cleanup complete")
    }
}
