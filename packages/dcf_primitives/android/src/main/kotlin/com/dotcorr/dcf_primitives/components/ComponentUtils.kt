/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import com.dotcorr.dcflight.components.dpToPx
import com.dotcorr.dcflight.utils.ColorUtilities

/**
 * Utility functions for dcf_primitives components
 */

// Re-export dpToPx from framework
fun dpToPx(dp: Float, context: Context): Int {
    return com.dotcorr.dcflight.components.dpToPx(dp, context)
}

// Re-export parseColor from ColorUtilities
fun parseColor(colorString: String): Int {
    return ColorUtilities.parseColor(colorString)
}
