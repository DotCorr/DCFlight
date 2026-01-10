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
import androidx.lifecycle.LifecycleOwner
import com.dotcorr.dcflight.components.DCFFrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

import com.dotcorr.dcflight.bridge.DCMauiBridgeImpl

import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.DCFLayoutManager

import com.dotcorr.dcflight.components.FrameworkComponentsReg

import com.dotcorr.dcflight.utils.DCFScreenUtilities

object DCDivergerUtil {
    private const val TAG = "DCDivergerUtil"
    private const val ENGINE_ID = "io.dcflight.engine"

    private var rootView: ViewGroup? = null
    private var flutterView: FlutterView? = null
    private var flutterEngine: FlutterEngine? = null
    private var mainScope = MainScope()

    @JvmStatic
    fun divergeToFlight(activity: Activity, pluginBinding: FlutterPlugin.FlutterPluginBinding?) {
        Log.d(TAG, "Starting divergeToFlight")

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
            Log.d(TAG, "✅ DCDivergerUtil: Registered all plugins with custom FlutterEngine")
        } catch (e: Exception) {
        }

        // 🚀 PERFORMANCE: Only create FlutterView if ENABLE_FLUTTER_VIEW flag is set
        // This saves ~300MB memory and 30% CPU when Flutter widgets aren't used
        val sharedPrefs = activity.getSharedPreferences("dcflight_prefs", Context.MODE_PRIVATE)
        val enableFlutterView = sharedPrefs.getBoolean("ENABLE_FLUTTER_VIEW", false)
        
        if (enableFlutterView) {
            flutterView = FlutterView(activity).apply {
                visibility = View.GONE
            }
            flutterView?.attachToFlutterEngine(flutterEngine!!)
            Log.d(TAG, "✅ DCDivergerUtil: FlutterView created (ENABLE_FLUTTER_VIEW=true)")
        } else {
            Log.d(TAG, "⚡ DCDivergerUtil: FlutterView DISABLED (ENABLE_FLUTTER_VIEW=false) - Saving memory & CPU")
        }

        // Set up method channel for Flutter widget rendering (only if FlutterView is enabled)
        if (enableFlutterView) {
            val flutterWidgetChannel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "dcflight/flutter_widget")
            flutterWidgetChannel.setMethodCallHandler { call, result ->
                if (call.method == "enableFlutterViewRendering") {
                    enableFlutterViewRendering()
                    result.success(true)
                } else if (call.method == "updateFlutterViewFrame") {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        val x = (args["x"] as? Number)?.toDouble() ?: 0.0
                        val y = (args["y"] as? Number)?.toDouble() ?: 0.0
                        val width = (args["width"] as? Number)?.toDouble() ?: 0.0
                        val height = (args["height"] as? Number)?.toDouble() ?: 0.0
                        
                        updateFlutterViewFrame(x, y, width, height)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Invalid frame parameters", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        }

        setupNativeContainer(activity)

        initializeDCFlightSystems(activity, flutterEngine!!.dartExecutor.binaryMessenger)

        registerComponents()
        
        // REMOVED: Pre-add FlutterView
        // We now add it only when enableFlutterViewRendering is called to prevent "SurfaceView has no frame" logs
        // when it's attached but not used.
        /*
        flutterView?.let { view ->
            rootView?.let { root ->
                if (view.parent == null) {
                    root.addView(view)
                    // Initially set to zero size - will be updated when widgets are rendered
                    view.layoutParams = FrameLayout.LayoutParams(0, 0)
                    view.visibility = View.GONE // Hidden until enableFlutterViewRendering is called
                    view.setBackgroundColor(android.graphics.Color.TRANSPARENT)
                    view.isClickable = true
                    view.isFocusable = true
                    view.isFocusableInTouchMode = true
                    Log.d(TAG, "✅ DCDivergerUtil: FlutterView pre-added to rootView (hidden, will be enabled when widgets render)")
                }
            }
        }
        */

        Log.d(TAG, "DCFlight diverger initialized successfully")
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
                    Log.d(TAG, "Native container already exists and attached, preserving UI state")
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
                        Log.d(TAG, "✅ ViewTreeLifecycleOwner attached to root view via reflection")
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
                        Log.d(TAG, "✅ ViewTreeSavedStateRegistryOwner attached to root view via reflection")
                    } catch (e: Exception) {
                    }
                } else {
                }
            }

            if (activity is FlutterActivity) {
                val contentView = activity.findViewById<ViewGroup>(android.R.id.content)
                
                contentView?.removeAllViews()
                
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
            DCMauiBridgeImpl.shared.setContext(activity)

            Log.d(TAG, "Ensuring DCFlight systems are initialized")

            DCFScreenUtilities.initialize(binaryMessenger, activity)

            rootView?.let { root ->
                root.visibility = View.VISIBLE
                root.alpha = 1.0f
                com.dotcorr.dcflight.layout.ViewRegistry.shared.registerView(root, 0, "View")
                DCFLayoutManager.shared.registerView(root, 0)
                
                // 🔥 CRITICAL: Set root view in DCFScreenUtilities for safe area calculations
                DCFScreenUtilities.setRootView(root)
            }

            Log.d(TAG, "DCFlight systems initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize DCFlight systems", e)
        }
    }

    private fun registerComponents() {
        try {
            FrameworkComponentsReg.registerComponents()
            Log.d(TAG, "Framework components registered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register components", e)
        }
    }

    @JvmStatic
    fun enableFlutterViewRendering() {
        try {
            val view = flutterView ?: return
            val root = rootView ?: return

            Log.d(TAG, "🎨 enableFlutterViewRendering: Starting...")
            
            // view.visibility = View.VISIBLE // REMOVED: Handled by updateFlutterViewFrame
            view.alpha = 1.0f
            view.setBackgroundColor(android.graphics.Color.TRANSPARENT)

            // Enable interaction for Flutter widgets
            // Flutter's hit-testing will handle touches - interactive widgets consume touches,
            // non-interactive areas allow touches to pass through to DCF components
            view.isClickable = true
            view.isFocusable = true
            view.isFocusableInTouchMode = true

            if (view.parent == null) {
                root.addView(view)
                // Initially set to zero size - will be updated when widgets are rendered
                // Use FrameLayout.LayoutParams for proper positioning
                view.layoutParams = FrameLayout.LayoutParams(0, 0)
                Log.d(TAG, "✅ FlutterView added to view hierarchy ON TOP for Flutter widget rendering (interactive, Flutter handles hit-testing)")
            } else {
                (view.parent as? ViewGroup)?.removeView(view)
                root.addView(view)
                // Use FrameLayout.LayoutParams for proper positioning
                view.layoutParams = FrameLayout.LayoutParams(0, 0)
                view.bringToFront()
                Log.d(TAG, "✅ FlutterView moved to front and brought to top")
            }
            
            // CRITICAL FIX: Keep FlutterView hidden until updateFlutterViewFrame provides valid dimensions
            // This prevents "SurfaceView has no frame" logs when the view is attached but has 0x0 size
            view.visibility = View.GONE
            view.bringToFront()
            Log.d(TAG, "✅ FlutterView attached and brought to front (hidden until frame update)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to enable FlutterView rendering", e)
        }
    }
    
    @JvmStatic
    fun updateFlutterViewFrame(x: Double, y: Double, width: Double, height: Double) {
        try {
            val view = flutterView ?: return
            val root = rootView ?: return
            
            Log.d(TAG, "🎨 updateFlutterViewFrame: ($x, $y, $width, $height)")
            
            // Update FlutterView frame to match union of all widget frames
            // Use FrameLayout.LayoutParams for proper positioning with margins
            val params = if (view.layoutParams is FrameLayout.LayoutParams) {
                view.layoutParams as FrameLayout.LayoutParams
            } else {
                FrameLayout.LayoutParams(width.toInt(), height.toInt())
            }
            
            params.width = width.toInt()
            params.height = height.toInt()
            params.leftMargin = x.toInt()
            params.topMargin = y.toInt()
            params.rightMargin = 0
            params.bottomMargin = 0
            
            // Reset translation (we use margins for positioning now)
            view.translationX = 0f
            view.translationY = 0f
            
            view.layoutParams = params
            view.layoutParams = params
            
            // CRITICAL FIX: Hide FlutterView if dimensions are 0x0 to prevent "SurfaceView has no frame" logs
            if (width <= 0 || height <= 0) {
                if (view.visibility != View.GONE) {
                    view.visibility = View.GONE
                    Log.d(TAG, "🙈 FlutterView hidden because dimensions are ${width}x${height}")
                }
            } else {
                if (view.visibility != View.VISIBLE) {
                    view.visibility = View.VISIBLE
                    Log.d(TAG, "👁️ FlutterView shown because dimensions are ${width}x${height}")
                }
            }
            
            view.requestLayout() // Request layout to apply new frame
            
            Log.d(TAG, "✅ FlutterView frame updated to: ($x, $y, $width, $height)")
            Log.d(TAG, "   FlutterView visibility: ${view.visibility}, alpha: ${view.alpha}")
            Log.d(TAG, "   FlutterView parent: ${view.parent != null}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to update FlutterView frame", e)
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
            flutterView = null
            flutterEngine = null
            Log.d(TAG, "Cleanup complete")
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }
}

