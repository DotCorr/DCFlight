/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This sourc    /**
     * Diverge to native DCFlight UI - matches iOS DCFAppDelegate.divergeToFlight()
     * Called safely after Flutter engine and native libraries are ready
     */
    private fun divergeToFlightSafely() {
        if (isFrameworkDiverged) {
            return // Already diverged
        }
        
        Log.d(TAG, "Diverging to native DCFlight UI...")
        
        try {
            val flutterEngine = flutterEngine
            if (flutterEngine == null) {
                Log.e(TAG, "Flutter engine not available for divergence")
                return
            }
            
            // Find the plugin binding (this should be available after plugin initialization)
            val pluginBinding = DcflightPlugin.getPluginBinding()
            
            if (pluginBinding == null) {
                Log.e(TAG, "Plugin binding not available for divergence")
                return
            }
            
            // Call the diverger utility to set up native UI
            DCDivergerUtil.divergeToFlight(this, pluginBinding)
            
            isFrameworkDiverged = true
            Log.d(TAG, "Successfully diverged to native UI")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to diverge to native UI", e)
        }
    }
    
    /**
     * Diverge to native DCFlight UI - matches iOS DCFAppDelegate.divergeToFlight()
     */
    private fun divergeToFlight(flutterEngine: FlutterEngine) {
        Log.d(TAG, "Diverging to native DCFlight UI...")
        
        // Find the plugin binding (this should be available after plugin initialization)
        val pluginBinding = DcflightPlugin.getPluginBinding()
        
        // Call the diverger utility to set up native UI
        DCDivergerUtil.divergeToFlight(this, pluginBinding)
        
        Log.d(TAG, "Successfully diverged to native UI")
    }nsed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight

import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import com.facebook.soloader.SoLoader
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.dotcorr.dcflight.layout.YogaShadowTree
import com.dotcorr.dcflight.layout.DCFLayoutManager
import com.dotcorr.dcflight.utils.DCFScreenUtilities

/**
 * DCFFlutterActivity - Base activity for DCFlight apps
 * Matches iOS DCFAppDelegate pattern for framework initialization
 */
open class DCFFlutterActivity : FlutterActivity() {

    companion object {
        private const val TAG = "DCFlight"
        private var isFrameworkInitialized = false
        private var isFrameworkDiverged = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize SoLoader for Yoga native library
        if (!SoLoader.isInitialized()) {
            SoLoader.init(this, false)
            Log.d(TAG, "✅ SoLoader initialized")
        }

        // iOS-CONSISTENT: Don't do aggressive cleanup like iOS
        // iOS doesn't clear native state on app lifecycle changes - Android shouldn't either

        // Initialize DCFlight framework
        initializeFramework()
    }
    
    override fun onStart() {
        super.onStart()
        
        // Only diverge once during app lifecycle, not every time activity starts
        // This prevents clearing native UI when returning from background
        if (!isFrameworkDiverged) {
            Log.d(TAG, "First start - diverging to native UI")
            divergeToFlightSafely()
        } else {
            Log.d(TAG, "Activity restarted - preserving existing native UI")
        }
    }
    
    /**
     * Safely diverge to native UI after Flutter engine is ready
     * This prevents the SoLoader.init() crash
     */
    private fun divergeToFlightSafely() {
        try {
            Log.d(TAG, "Attempting safe divergence to native DCFlight UI...")
            
            // Get the Flutter engine from the activity
            val engine = flutterEngine
            if (engine != null) {
                divergeToFlight(engine)
            } else {
                Log.e(TAG, "Flutter engine not available for divergence")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to diverge to native UI safely", e)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Framework will register plugins here when implemented
        Log.d(TAG, "Flutter engine configured")
        
        // Don't call divergeToFlight here - too early in lifecycle
        // Will be called after engine is fully ready
    }

    /**
     * Initialize the DCFlight framework
     * This is called once during app startup
     */
    private fun initializeFramework() {
        if (isFrameworkInitialized) {
            return
        }

        Log.d(TAG, "🚀 Initializing framework...")

        // Register framework components only
        registerFrameworkComponents()

        isFrameworkInitialized = true
        Log.d(TAG, "✅ Framework initialized successfully")
    }
    
    /**
     * Diverge to native DCFlight UI - matches iOS DCFAppDelegate.divergeToFlight()
     */
    private fun divergeToFlight(flutterEngine: FlutterEngine) {
        Log.d(TAG, "Diverging to native DCFlight UI...")
        
        // Find the plugin binding (this should be available after plugin initialization)
        val pluginBinding = DcflightPlugin.getPluginBinding()
        
        // Call the diverger utility to set up native UI
        DCDivergerUtil.divergeToFlight(this, pluginBinding)
        
        Log.d(TAG, "Successfully diverged to native UI")
    }

    /**
     * Register framework-level components
     * This only registers components that are part of the framework itself
     * Primitives and other plugins register themselves
     */
    protected open fun registerFrameworkComponents() {
        // Register any framework-level components
        // Currently empty - primitives are registered by their own plugin
        println("$TAG: Registering framework components")
    }

    /**
     * Called when the framework needs to hot reload
     */
    protected open fun onHotReload() {
        println("🔄 $TAG: Hot reload triggered")
    }

    override fun onDestroy() {
        super.onDestroy()
        println("🧹 $TAG: Activity destroyed")
    }

    /**
     * Handle configuration changes like device rotation
     * 🚀 CRITICAL FIX: This was missing - causing layout not to update on rotation!
     */
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        
        Log.d(TAG, "🔄 Configuration changed - handling rotation/layout update")
        
        try {
            // Update screen utilities with new display metrics
            DCFScreenUtilities.refreshScreenDimensions()
            
            // Invalidate all layouts to force recalculation with new screen dimensions
            DCFLayoutManager.shared.invalidateAllLayouts()
            
            // Recalculate all layouts with new dimensions
            YogaShadowTree.shared.calculateLayoutForAllRoots()
            
            Log.d(TAG, "✅ Layout updated for configuration change")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to handle configuration change", e)
        }
    }
}

