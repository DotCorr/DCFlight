/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * DCFFlutterActivity - Base activity for DCFlight apps
 * Matches iOS DCFAppDelegate pattern for framework initialization
 */
open class DCFFlutterActivity : FlutterActivity() {

    companion object {
        private const val TAG = "DCFlight"
        private var isFrameworkInitialized = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize DCFlight framework
        initializeFramework()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Framework will register plugins here when implemented
        println("$TAG: Flutter engine configured")
    }

    /**
     * Initialize the DCFlight framework
     * This is called once during app startup
     */
    private fun initializeFramework() {
        if (isFrameworkInitialized) {
            return
        }

        println("🚀 $TAG: Initializing framework...")

        // Register framework components only
        registerFrameworkComponents()

        isFrameworkInitialized = true
        println("✅ $TAG: Framework initialized successfully")
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
}
