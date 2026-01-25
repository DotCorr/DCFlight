/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcflight.utils

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.util.TypedValue

/**
 * Helper for adaptive color management to match iOS system color behavior
 */
object AdaptiveColorHelper {

    /**
     * Get system background color that adapts to light/dark mode
     */
    fun getSystemBackgroundColor(context: Context): Int {
        return try {
            val typedValue = TypedValue()
            if (context.theme.resolveAttribute(android.R.attr.colorBackground, typedValue, true)) {
                typedValue.data
            } else {
                fallbackBackgroundColor(context)
            }
        } catch (e: Exception) {
            fallbackBackgroundColor(context)
        }
    }

    /**
     * Get system text color that adapts to light/dark mode
     */
    fun getSystemTextColor(context: Context): Int {
        return try {
            val typedValue = TypedValue()
            if (context.theme.resolveAttribute(android.R.attr.textColorPrimary, typedValue, true)) {
                typedValue.data
            } else {
                fallbackTextColor(context)
            }
        } catch (e: Exception) {
            fallbackTextColor(context)
        }
    }

    /**
     * Get system accent color (for buttons, etc.)
     */
    fun getSystemAccentColor(context: Context): Int {
        return try {
            val typedValue = TypedValue()
            val attrId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                android.R.attr.colorAccent
            } else {
                android.R.attr.colorAccent
            }
            if (context.theme.resolveAttribute(attrId, typedValue, true)) {
                typedValue.data
            } else {
                Color.parseColor("#2196F3") // Material Blue
            }
        } catch (e: Exception) {
            Color.parseColor("#2196F3")
        }
    }

    /**
     * Check if current theme is dark mode
     */
    fun isDarkTheme(context: Context): Boolean {
        return (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
    }

    /**
     * Fallback background color based on theme detection
     */
    private fun fallbackBackgroundColor(context: Context): Int {
        return if (isDarkTheme(context)) {
            Color.parseColor("#121212") // Material dark background
        } else {
            Color.WHITE
        }
    }

    /**
     * Fallback text color based on theme detection
     */
    private fun fallbackTextColor(context: Context): Int {
        return if (isDarkTheme(context)) {
            Color.WHITE
        } else {
            Color.BLACK
        }
    }
}

