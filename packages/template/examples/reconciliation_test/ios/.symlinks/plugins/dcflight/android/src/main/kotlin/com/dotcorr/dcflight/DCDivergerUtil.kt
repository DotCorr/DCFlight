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
            pluginBinding?.flutterEngine ?: FlutterEngineCache.getInstance().get(ENGINE_ID)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get Flutter engine", e)
            null
        }
    }

    private fun setupNativeContainer(activity: Activity) {
        try {
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
                
                // Attach lifecycle owner for Compose support
                if (activity is LifecycleOwner) {
                    try {
                        // Use reflection to set ViewTreeLifecycleOwner if available
                        val viewTreeLifecycleOwnerClass = Class.forName("androidx.lifecycle.ViewTreeLifecycleOwner")
                        val setMethod = viewTreeLifecycleOwnerClass.getMethod("set", View::class.java, LifecycleOwner::class.java)
                        setMethod.invoke(null, this, activity)
                        Log.d(TAG, "✅ ViewTreeLifecycleOwner attached to root view via reflection")
                    } catch (e: Exception) {
                        Log.w(TAG, "ViewTreeLifecycleOwner not available, Compose may not work properly", e)
                    }
                } else {
                    Log.w(TAG, "Activity is not a LifecycleOwner, Compose may not work properly")
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
                        Log.w(TAG, "ViewTreeSavedStateRegistryOwner not available, Compose may not work properly", e)
                    }
                } else {
                    Log.w(TAG, "Activity is not a SavedStateRegistryOwner, Compose may not work properly")
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

