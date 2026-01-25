/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcflight

import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.ViewGroup
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import com.facebook.soloader.SoLoader
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.DCFLayoutManager
import com.dotcorr.dcflight.layout.ViewRegistry
import com.dotcorr.dcflight.utils.DCFScreenUtilities

/**
 * DCFFlutterActivity - Base activity for DCFlight apps
 * framework initialization
 */
open class DCFFlutterActivity : FlutterActivity(), LifecycleOwner, SavedStateRegistryOwner {

    companion object {
        private const val TAG = "DCFlight"
        private var isFrameworkInitialized = false
        private var isFrameworkDiverged = false
    }

    // Lifecycle support for Compose
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateRegistryController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle
        get() = lifecycleRegistry

    override val savedStateRegistry: SavedStateRegistry
        get() = savedStateRegistryController.savedStateRegistry

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize lifecycle and saved state for Compose support
        savedStateRegistryController.performRestore(savedInstanceState)
        lifecycleRegistry.currentState = Lifecycle.State.CREATED

        if (!SoLoader.isInitialized()) {
            SoLoader.init(this, false)
            Log.d(TAG, "✅ SoLoader initialized")
        }

        initializeFramework()
    }
    
    override fun onStart() {
        super.onStart()
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
        
        if (!isFrameworkDiverged) {
            // First launch - always diverge
            Log.d(TAG, "First start - diverging to native UI")
            divergeToFlightSafely()
        } else {
            // App resumed - check if views still exist
            val rootViewExists = try {
                val rootView = com.dotcorr.dcflight.layout.ViewRegistry.shared.getView(0)
                rootView != null && rootView.isAttachedToWindow
            } catch (e: Exception) {
                false
            }
            
            if (!rootViewExists) {
                Log.w(TAG, "⚠️ Root view missing despite divergence flag - re-diverging")
                isFrameworkDiverged = false // Reset flag to allow re-divergence
                divergeToFlightSafely()
            } else {
                Log.d(TAG, "Activity restarted - preserving existing native UI")
                // Ensure root view is visible and properly attached
                ensureRootViewVisible()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
        
        // 🔥 CRITICAL: Ensure root view is visible and properly attached on resume
        // This fixes cases where views exist but aren't visible or attached
        ensureRootViewVisible()
    }
    
    /**
     * Ensure root view is visible and properly attached
     * This is called on resume to fix timing issues
     */
    private fun ensureRootViewVisible() {
        try {
            val rootView = com.dotcorr.dcflight.layout.ViewRegistry.shared.getView(0)
            if (rootView != null) {
                if (!rootView.isAttachedToWindow) {
                    Log.w(TAG, "⚠️ Root view not attached on resume - re-attaching")
                    val contentView = findViewById<ViewGroup>(android.R.id.content)
                    if (rootView.parent == null && contentView != null) {
                        contentView.addView(rootView)
                    }
                }
                if (rootView.visibility != View.VISIBLE) {
                    Log.w(TAG, "⚠️ Root view not visible on resume - making visible")
                    rootView.visibility = View.VISIBLE
                    rootView.alpha = 1.0f
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to ensure root view visible", e)
        }
    }

    override fun onPause() {
        super.onPause()
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
    }

    override fun onStop() {
        super.onStop()
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
    }
    
    /**
     * Safely diverge to native UI after Flutter engine is ready
     * 🔥 CRITICAL: This method handles timing issues by waiting for engine readiness
     */
    private fun divergeToFlightSafely() {
        try {
            Log.d(TAG, "Attempting safe divergence to native DCFlight UI...")
            
            val engine = flutterEngine
            if (engine != null) {
                Log.d(TAG, "✅ Flutter engine available - diverging immediately")
                divergeToFlight(engine)
            } else {
                Log.w(TAG, "⏳ Flutter engine not available yet - retrying...")
                // Retry after a short delay (max 5 attempts = 1 second max wait)
                var attempts = 0
                val maxAttempts = 5
                val handler = android.os.Handler(android.os.Looper.getMainLooper())
                val retryCheck = object : Runnable {
                    override fun run() {
                        val retryEngine = flutterEngine
                        if (retryEngine != null) {
                            Log.d(TAG, "✅ Flutter engine available after retry - diverging")
                            divergeToFlight(retryEngine)
                        } else if (attempts < maxAttempts) {
                            attempts++
                            handler.postDelayed(this, 200)
                        } else {
                            Log.e(TAG, "❌ Flutter engine not available after ${maxAttempts * 200}ms - cannot diverge")
                        }
                    }
                }
                handler.postDelayed(retryCheck, 200)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to diverge to native UI safely", e)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "Flutter engine configured")
    }

    /**
     * Initialize the DCFlight framework
     */
    private fun initializeFramework() {
        if (isFrameworkInitialized) {
            return
        }

        Log.d(TAG, "🚀 Initializing framework...")
        registerFrameworkComponents()
        isFrameworkInitialized = true
        Log.d(TAG, "✅ Framework initialized successfully")
    }
    
    /**
     * Diverge to native DCFlight UI
     */
    private fun divergeToFlight(flutterEngine: FlutterEngine) {
        Log.d(TAG, "Diverging to native DCFlight UI...")
        
        val pluginBinding = DcflightPlugin.getPluginBinding()
        DCDivergerUtil.divergeToFlight(this, pluginBinding)
        
        isFrameworkDiverged = true
        Log.d(TAG, "Successfully diverged to native UI")
    }

    /**
     * Register framework-level components
     */
    protected open fun registerFrameworkComponents() {
        Log.d(TAG, "Registering framework components")
    }

    /**
     * Handle configuration changes like device rotation
     * 🚀 CRITICAL FIX: This handles device rotation layout updates!
     */
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        
        Log.d(TAG, "🔄 Configuration changed - handling rotation/layout update")
        
        try {
            DCFScreenUtilities.refreshScreenDimensions()
            
            DCFLayoutManager.shared.handleDeviceRotation()
            
            val rootView: View? = ViewRegistry.shared.getView(0)
            if (rootView != null) {
                val displayMetrics = resources.displayMetrics
                rootView.measure(
                    View.MeasureSpec.makeMeasureSpec(displayMetrics.widthPixels, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(displayMetrics.heightPixels, View.MeasureSpec.EXACTLY)
                )
                Log.d(TAG, "🔄 Root view measured after rotation: ${rootView.measuredWidth}x${rootView.measuredHeight}")
            }
            
            rootView?.post {
                YogaShadowTree.shared.calculateLayoutForAllRoots()
                Log.d(TAG, "🔄 Forced intrinsic size recalculation after rotation")
            }
            
            if (rootView != null) {
                fun invalidateAll(v: View) {
                    v.invalidate()
                    if (v is ViewGroup) {
                        for (i in 0 until v.childCount) {
                            invalidateAll(v.getChildAt(i))
                        }
                    }
                }
                invalidateAll(rootView)
                Log.d(TAG, "🔄 Forced recursive invalidation after rotation")
                
            }
            
            Log.d(TAG, "✅ Layout updated for configuration change")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to handle configuration change", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        
        // 🔥 CRITICAL: Reset divergence flag if activity is finishing (back button pressed)
        // This ensures we re-divergence when app is reopened
        if (isFinishing) {
            Log.d(TAG, "🧹 Activity finishing - resetting divergence flag")
            isFrameworkDiverged = false
        } else {
            Log.d(TAG, "🧹 Activity destroyed (configuration change) - preserving state")
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        savedStateRegistryController.performSave(outState)
    }
}

