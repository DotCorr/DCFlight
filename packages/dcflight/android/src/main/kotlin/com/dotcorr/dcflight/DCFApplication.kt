/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight

import android.app.Application
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

open class DCFApplication : Application() {

    companion object {
        private const val TAG = "DCFApplication"
        private const val ENGINE_ID = "io.dcflight.engine"

        @JvmStatic
        var flutterEngine: FlutterEngine? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "DCFApplication onCreate")

        // Create and configure Flutter engine
        initializeFlutterEngine()
    }

    private fun initializeFlutterEngine() {
        Log.d(TAG, "Initializing Flutter engine")

        // Create Flutter engine
        flutterEngine = FlutterEngine(this).apply {
            // Start executing Dart code
            dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
        }

        // Cache the engine for reuse
        FlutterEngineCache
            .getInstance()
            .put(ENGINE_ID, flutterEngine!!)

        Log.d(TAG, "Flutter engine initialized and cached with ID: $ENGINE_ID")
    }

    override fun onTerminate() {
        super.onTerminate()
        Log.d(TAG, "DCFApplication onTerminate")

        // Clean up Flutter engine
        flutterEngine?.destroy()
        flutterEngine = null

        // Clear the cache
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
    }
}
