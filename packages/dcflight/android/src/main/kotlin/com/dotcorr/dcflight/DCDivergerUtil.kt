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

// Import bridge handlers
import com.dotcorr.dcflight.bridge.DCMauiBridgeImpl
import com.dotcorr.dcflight.bridge.DCMauiBridgeMethodChannel
import com.dotcorr.dcflight.bridge.DCMauiEventMethodHandler
import com.dotcorr.dcflight.bridge.DCMauiLayoutMethodHandler

// Import layout managers
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.DCFLayoutManager

// Import components
import com.dotcorr.dcflight.components.FrameworkComponentsReg
import com.dotcorr.dcflight.components.DCFComponentRegistry

// Import utilities
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

        // Create Flutter view but keep it hidden
        flutterView = FlutterView(activity).apply {
            visibility = View.GONE
        }
        flutterView?.attachToFlutterEngine(flutterEngine)

        // Initialize method channels
        initializeMethodChannels(flutterEngine.dartExecutor.binaryMessenger)

        // Setup native container
        setupNativeContainer(activity)

        // Initialize DCFlight systems
        initializeDCFlightSystems(activity)

        // Register components
        registerComponents()

        Log.d(TAG, "DCFlight diverger initialized successfully")
    }

    private fun getOrCreateFlutterEngine(
        activity: Activity,
        pluginBinding: FlutterPlugin.FlutterPluginBinding?
    ): FlutterEngine? {
        // Try to get existing engine from plugin binding
        pluginBinding?.let {
            return it.flutterEngine
        }

        // Try to get cached engine
        var engine = FlutterEngineCache.getInstance().get(ENGINE_ID)
        if (engine != null) {
            Log.d(TAG, "Using cached Flutter engine")
            return engine
        }

        // Create new engine
        Log.d(TAG, "Creating new Flutter engine")
        engine = FlutterEngine(activity)
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

    private fun setupNativeContainer(activity: Activity) {
        Log.d(TAG, "Setting up native container")

        rootView = FrameLayout(activity).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.TRANSPARENT)
            visibility = View.GONE // Initially hidden
        }

        // Add the native container to the activity
        val contentView = activity.window.decorView.findViewById<ViewGroup>(android.R.id.content)
        contentView?.addView(rootView)

        Log.d(TAG, "Native container setup complete")
    }

    private fun initializeDCFlightSystems(activity: Activity) {
        Log.d(TAG, "Initializing DCFlight systems")

        // Initialize bridge implementation
        DCMauiBridgeImpl.shared.initialize(activity)

        Log.d(TAG, "Setting up DCF systems")

        // Register root view with bridge
        rootView?.let { view ->
            DCMauiBridgeImpl.shared.registerView(view, "root")
        }

        // Initialize core systems
        YogaShadowTree.shared.initialize()
        DCFLayoutManager.shared.initialize()
        DCFScreenUtilities.shared.initialize(null, activity)

        // Set up layout change listener
        rootView?.addOnLayoutChangeListener { v, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom ->
            val width = right - left
            val height = bottom - top
            if (width != oldRight - oldLeft || height != oldBottom - oldTop) {
                handleSizeChange(width, height)
            }
        }

        Log.d(TAG, "DCFlight systems initialized")
    }

    private fun registerComponents() {
        Log.d(TAG, "Registering framework components")
        FrameworkComponentsReg.registerComponents()
        Log.d(TAG, "Framework components registered")
    }

    @JvmStatic
    fun showNativeView() {
        Log.d(TAG, "Showing native DCFlight view")
        rootView?.visibility = View.VISIBLE
        flutterView?.visibility = View.GONE
    }

    @JvmStatic
    fun showFlutterView() {
        Log.d(TAG, "Showing Flutter view")
        flutterView?.visibility = View.VISIBLE
        rootView?.visibility = View.GONE
    }

    @JvmStatic
    fun toggleView() {
        if (rootView?.visibility == View.VISIBLE) {
            showFlutterView()
        } else {
            showNativeView()
        }
    }

    private fun handleSizeChange(width: Int, height: Int) {
        Log.d(TAG, "Handling size change: ${width}x${height}")

        // Update screen dimensions
        DCFScreenUtilities.shared.updateScreenDimensions(width.toFloat(), height.toFloat())

        // Recalculate layout
        YogaShadowTree.shared.calculateAndApplyLayout(width.toFloat(), height.toFloat())
    }

    @JvmStatic
    fun createNativeComponent(
        componentType: String,
        properties: Map<String, Any>
    ): View? {
        Log.d(TAG, "Creating native component: $componentType")

        return try {
            val context = rootView?.context ?: return null
            DCFComponentRegistry.shared.createComponent(componentType, properties, context)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create component: $componentType", e)
            null
        }
    }

    @JvmStatic
    fun updateDimensions(width: Float, height: Float) {
        Log.d(TAG, "Updating dimensions: ${width}x${height}")

        rootView?.layoutParams?.apply {
            this.width = width.toInt()
            this.height = height.toInt()
        }
        rootView?.requestLayout()

        // Update layout system
        if (width > 0 && height > 0) {
            DCFScreenUtilities.shared.updateScreenDimensions(width, height)
            YogaShadowTree.shared.calculateAndApplyLayout(width, height)
        }
    }

    @JvmStatic
    fun cleanup() {
        Log.d(TAG, "Cleaning up DCDiverger")

        mainScope.cancel()

        // Remove native container from activity
        rootView?.let { root ->
            (root.parent as? ViewGroup)?.removeView(root)
        }

        // Detach Flutter view
        flutterView?.detachFromFlutterEngine()

        // Clean up references
        flutterView = null
        rootView = null

        // Clean up systems
        DCMauiBridgeImpl.shared.cleanup()
        YogaShadowTree.shared.cleanup()
        DCFLayoutManager.shared.cleanup()
        DCFScreenUtilities.shared.cleanup()

        // Clean up channels
        DCMauiBridgeMethodChannel.shared.cleanup()
        DCMauiEventMethodHandler.shared.cleanup()
        DCMauiLayoutMethodHandler.shared.cleanup()

        Log.d(TAG, "DCDiverger cleanup complete")
    }

    @JvmStatic
    fun isInitialized(): Boolean = rootView != null

    @JvmStatic
    fun getRootContainer(): ViewGroup? = rootView

    @JvmStatic
    fun getFlutterView(): FlutterView? = flutterView
}
