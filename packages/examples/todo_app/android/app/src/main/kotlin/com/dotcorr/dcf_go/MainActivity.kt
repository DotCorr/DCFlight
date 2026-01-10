/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.todo_app

import android.os.Bundle
import com.dotcorr.dcflight.DCFFlutterActivity

/**
 * MainActivity for DCF Go template app
 * Extends DCFFlutterActivity to handle framework initialization
 */
class MainActivity : DCFFlutterActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        // Discard any persisted Activity state to avoid inconsistencies
        // Pass null to super.onCreate() instead of savedInstanceState
        super.onCreate(null)
    }
}
