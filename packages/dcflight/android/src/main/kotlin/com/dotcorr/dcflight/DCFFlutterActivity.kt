/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
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
     */
    private fun divergeToFlightSafely() {
        try {
            Log.d(TAG, "Attempting safe divergence to native DCFlight UI...")
            
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

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🧹 Activity destroyed")
    }
}

