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

        // Register primitive components
        registerComponents()

        isFrameworkInitialized = true
        println("✅ $TAG: Framework initialized successfully")
    }

    /**
     * Register all primitive components
     * Apps can override this to register custom components
     */
    protected open fun registerComponents() {
        // Register primitive components from dcf_primitives package
        try {
            // Use reflection to call PrimitivesComponentsReg if available
            val primitivesRegClass = Class.forName("com.dotcorr.dcf_primitives.PrimitivesComponentsReg")
            val registerMethod = primitivesRegClass.getDeclaredMethod("registerComponents")
            registerMethod.invoke(null)

            // Also verify registration
            val verifyMethod = primitivesRegClass.getDeclaredMethod("verifyRegistration")
            verifyMethod.invoke(null)

            println("✅ $TAG: Primitive components registered")
        } catch (e: Exception) {
            println("⚠️ $TAG: Could not register primitive components: ${e.message}")
            // Primitives package might not be included, which is okay for base framework
        }
    }

    /**
     * Called when the framework needs to hot reload
     */
    protected open fun onHotReload() {
        println("🔄 $TAG: Hot reload triggered")
        // Re-register components
        registerComponents()
    }

    override fun onDestroy() {
        super.onDestroy()
        println("🧹 $TAG: Activity destroyed")
    }
}
