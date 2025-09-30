/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.util.Log

/**
 * Registration class for DCFlight framework components
 * This is a placeholder for future framework-level components
 * Currently does not register anything - primitives are registered through dcf_primitives module
 */
object FrameworkComponentsReg {
    private const val TAG = "FrameworkComponentsReg"

    /**
     * Register framework-level components
     * This is a placeholder for future framework components
     * Primitive components are registered through dcf_primitives module
     */
    @JvmStatic
    fun registerComponents() {
        // Register the framework level components here
        // Currently empty - primitives register themselves through Flutter plugin system
    }
}
