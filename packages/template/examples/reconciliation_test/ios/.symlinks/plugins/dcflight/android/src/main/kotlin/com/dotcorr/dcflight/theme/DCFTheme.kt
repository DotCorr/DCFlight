/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.theme

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.util.TypedValue
import com.dotcorr.dcflight.utils.AdaptiveColorHelper

/**
 * Unified theme system for DCFlight Android
 * Provides single API for all theme operations (replaces scattered theme code)
 */
object DCFTheme {
    
    /**
     * Check if current theme is dark mode
     */
    fun isDarkTheme(context: Context): Boolean {
        return AdaptiveColorHelper.isDarkTheme(context)
    }
    
    /**
     * Get system text color (adapts to light/dark mode)
     */
    fun getTextColor(context: Context): Int {
        return AdaptiveColorHelper.getSystemTextColor(context)
    }
    
    /**
     * Get system background color (adapts to light/dark mode)
     */
    fun getBackgroundColor(context: Context): Int {
        return AdaptiveColorHelper.getSystemBackgroundColor(context)
    }
    
    /**
     * Get system surface color (adapts to light/dark mode)
     */
    fun getSurfaceColor(context: Context): Int {
        return try {
            val typedValue = TypedValue()
            if (context.theme.resolveAttribute(android.R.attr.colorBackground, typedValue, true)) {
                typedValue.data
            } else {
                if (isDarkTheme(context)) {
                    Color.parseColor("#121212") // Material dark surface
                } else {
                    Color.WHITE
                }
            }
        } catch (e: Exception) {
            if (isDarkTheme(context)) {
                Color.parseColor("#121212")
            } else {
                Color.WHITE
            }
        }
    }
    
    /**
     * Get system accent color
     */
    fun getAccentColor(context: Context): Int {
        return AdaptiveColorHelper.getSystemAccentColor(context)
    }
    
    /**
     * Get secondary text color (adapts to light/dark mode)
     */
    fun getSecondaryTextColor(context: Context): Int {
        return try {
            val typedValue = TypedValue()
            if (context.theme.resolveAttribute(android.R.attr.textColorSecondary, typedValue, true)) {
                typedValue.data
            } else {
                if (isDarkTheme(context)) {
                    Color.parseColor("#B3FFFFFF") // 70% opacity white
                } else {
                    Color.parseColor("#8A000000") // 54% opacity black
                }
            }
        } catch (e: Exception) {
            if (isDarkTheme(context)) {
                Color.parseColor("#B3FFFFFF")
            } else {
                Color.parseColor("#8A000000")
            }
        }
    }
    
    /**
     * Get all theme colors as a map (for Dart bridge)
     */
    fun getAllColors(context: Context): Map<String, Int> {
        return mapOf(
            "isDark" to if (isDarkTheme(context)) 1 else 0,
            "textColor" to getTextColor(context),
            "backgroundColor" to getBackgroundColor(context),
            "surfaceColor" to getSurfaceColor(context),
            "accentColor" to getAccentColor(context),
            "secondaryTextColor" to getSecondaryTextColor(context)
        )
    }
}

