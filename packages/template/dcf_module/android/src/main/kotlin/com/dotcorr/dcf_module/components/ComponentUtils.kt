/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_module.components

import android.content.Context
import com.dotcorr.dcflight.components.dpToPx
import com.dotcorr.dcflight.utils.ColorUtilities

/**
 * Utility functions for dcf_module components
 */

fun dpToPx(dp: Float, context: Context): Int {
    return com.dotcorr.dcflight.components.dpToPx(dp, context)
}

fun parseColor(colorString: String): Int {
    return ColorUtilities.parseColor(colorString)
}

