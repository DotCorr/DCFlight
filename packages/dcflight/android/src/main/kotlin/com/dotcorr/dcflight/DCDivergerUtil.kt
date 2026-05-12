/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcflight

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.lifecycle.LifecycleOwner
import com.dotcorr.dcflight.components.DCFFrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.*

import com.dotcorr.dcflight.bridge.DCFlightNative

import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.DCFLayoutManager

import com.dotcorr.dcflight.components.FrameworkComponentsReg

import com.dotcorr.dcflight.utils.DCFScreenUtilities

object DCDivergerUtil {
    private const val TAG = "DCDivergerUtil"
    private const val ENGINE_ID = "io.dcflight.engine"
    private fun dlog(message: String) {
        if (Log.isLoggable(TAG, Log.DEBUG)) {
            Log.d(TAG, message)
        }
    }

    private var rootView: ViewGroup? = null
    private var flutterEngine: FlutterEngine? = null
    private var mainScope = MainScope()

    @JvmStatic
    fun divergeToFlight(activity: Activity, pluginBinding: FlutterPlugin.FlutterPluginBinding?) {
        dlog("Starting divergeToFlight")

        val engine = getOrCreateFlutterEngine(activity, pluginBinding)

        if (engine == null) {
            Log.e(TAG, "Failed to get or create Flutter engine")
            return
        }

        flutterEngine = engine

        // CRITICAL: Register all plugins with our custom engine
        // This ensures WebView and other platform channel plugins can establish channels
        // This is essential for WebView and other plugins that use platform channels
        try {
            val registrantClass = Class.forName("io.flutter.plugins.GeneratedPluginRegistrant")
            val registerMethod = registrantClass.getMethod("registerWith", FlutterEngine::class.java)
            registerMethod.invoke(null, flutterEngine)
            dlog("Registered all plugins with custom FlutterEngine")
        } catch (e: Exception) {
        }

        setupNativeContainer(activity)

        initializeDCFlightSystems(activity, flutterEngine!!.dartExecutor.binaryMessenger)

        registerComponents()
        
        dlog("DCFlight diverger initialized successfully")
    }

    private fun getOrCreateFlutterEngine(
        activity: Activity,
        pluginBinding: FlutterPlugin.FlutterPluginBinding?
    ): FlutterEngine? {
        return try {
            pluginBinding?.flutterEngine ?: FlutterEngineCache.getInstance().get(ENGINE_ID)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get Flutter engine", e)
            null
        }
    }

    private fun setupNativeContainer(activity: Activity) {
        try {
            // 🔥 CRITICAL: Check if root view exists AND is properly attached
            // If it exists but isn't attached, we need to recreate it
            if (rootView != null) {
                val isAttached = rootView!!.isAttachedToWindow
                val hasParent = rootView!!.parent != null
                if (isAttached && hasParent) {
                    dlog("Native container already exists and attached, preserving UI state")
                    return
                } else {
                    // Clean up the old root view
                    rootView = null
                }
            }

            rootView = DCFFrameLayout(activity).apply {
                setBackgroundColor(Color.WHITE)
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
                
                // CRITICAL: Disable automatic system window insets (matches iOS behavior)
                // We want the root view to fill the entire window starting from (0,0)
                // Individual components will add safe area padding manually via ScreenUtilities
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT_WATCH) {
                    setFitsSystemWindows(false)
                }
                
                // Attach lifecycle owner for Compose support
                if (activity is LifecycleOwner) {
                    try {
                        // Use reflection to set ViewTreeLifecycleOwner if available
                        val viewTreeLifecycleOwnerClass = Class.forName("androidx.lifecycle.ViewTreeLifecycleOwner")
                        val setMethod = viewTreeLifecycleOwnerClass.getMethod("set", View::class.java, LifecycleOwner::class.java)
                        setMethod.invoke(null, this, activity)
                        dlog("ViewTreeLifecycleOwner attached to root view via reflection")
                    } catch (e: Exception) {
                    }
                } else {
                }
                
                // Also attach SavedStateRegistryOwner for Compose support
                if (activity is androidx.savedstate.SavedStateRegistryOwner) {
                    try {
                        // Use reflection to set ViewTreeSavedStateRegistryOwner if available
                        val viewTreeSavedStateRegistryOwnerClass = Class.forName("androidx.savedstate.ViewTreeSavedStateRegistryOwner")
                        val setMethod = viewTreeSavedStateRegistryOwnerClass.getMethod("set", View::class.java, androidx.savedstate.SavedStateRegistryOwner::class.java)
                        setMethod.invoke(null, this, activity)
                        dlog("ViewTreeSavedStateRegistryOwner attached to root view via reflection")
                    } catch (e: Exception) {
                    }
                } else {
                }
            }

            if (activity is FlutterActivity) {
                val contentView = activity.findViewById<ViewGroup>(android.R.id.content)
                
                contentView?.removeAllViews()
                
                contentView?.addView(rootView)
                
                dlog("Replaced Flutter content with native DCF content")
            }

            dlog("Native container setup complete")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup native container", e)
        }
    }

    private fun initializeDCFlightSystems(activity: Activity, binaryMessenger: BinaryMessenger) {
        try {
            DCFlightNative.shared.setContext(activity)

            dlog("Ensuring DCFlight systems are initialized")

            DCFScreenUtilities.initialize(binaryMessenger, activity)

            rootView?.let { root ->
                root.visibility = View.VISIBLE
                root.alpha = 1.0f
                com.dotcorr.dcflight.layout.ViewRegistry.shared.registerView(root, 0, "View")
                DCFLayoutManager.shared.registerView(root, 0)
                
                // 🔥 CRITICAL: Set root view in DCFScreenUtilities for safe area calculations
                DCFScreenUtilities.setRootView(root)
                
                // 🔥 CRITICAL FIX: Calculate layout on initial app launch (not just on rotation)
                // This fixes the Android blank render issue where UI won't show until device rotation
                // The root cause: calculateLayoutForAllRoots() was only called in onConfigurationChanged()
                // Now we also call it on initial launch after root view is attached and measured
                root.post {
                    val displayMetrics = activity.resources.displayMetrics
                    root.measure(
                        View.MeasureSpec.makeMeasureSpec(displayMetrics.widthPixels, View.MeasureSpec.EXACTLY),
                        View.MeasureSpec.makeMeasureSpec(displayMetrics.heightPixels, View.MeasureSpec.EXACTLY)
                    )
                    dlog("Root view measured on launch: ${root.measuredWidth}x${root.measuredHeight}")
                    
                    YogaShadowTree.shared.calculateLayoutForAllRoots()
                    dlog("Initial layout calculated on app launch")
                }
            }

            dlog("DCFlight systems initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize DCFlight systems", e)
        }
    }

    private fun registerComponents() {
        try {
            FrameworkComponentsReg.registerComponents()
            dlog("Framework components registered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register components", e)
        }
    }

    @JvmStatic
    fun getFlutterEngine(): FlutterEngine? {
        return flutterEngine
    }

    fun cleanup() {
        try {
            mainScope.cancel()
            rootView = null
            flutterEngine = null
            dlog("Cleanup complete")
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }
}

