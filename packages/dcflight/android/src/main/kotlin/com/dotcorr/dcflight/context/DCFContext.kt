/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.context

import android.content.Context
import com.dotcorr.dcflight.theme.DCFTheme

/**
 * Context interface for DCFlight components
 * Provides access to Android context, theme, and app-level state
 * Similar to React Native's ReactContext hierarchy
 */
interface DCFContext {
    val context: Context
    val isDarkMode: Boolean
    val textColor: Int
    val backgroundColor: Int
    val surfaceColor: Int
    val accentColor: Int
}

/**
 * Application-level context (root context)
 * Provides access to Android application context and theme
 */
class DCFApplicationContext(
    override val context: Context
) : DCFContext {
    override val isDarkMode: Boolean
        get() = DCFTheme.isDarkTheme(context)
    
    override val textColor: Int
        get() = DCFTheme.getTextColor(context)
    
    override val backgroundColor: Int
        get() = DCFTheme.getBackgroundColor(context)
    
    override val surfaceColor: Int
        get() = DCFTheme.getSurfaceColor(context)
    
    override val accentColor: Int
        get() = DCFTheme.getAccentColor(context)
}

/**
 * Themed context for specific surfaces/views
 * Can override theme values for specific contexts
 */
class DCFThemedContext(
    private val parent: DCFContext,
    override val isDarkMode: Boolean = parent.isDarkMode,
    override val textColor: Int = parent.textColor,
    override val backgroundColor: Int = parent.backgroundColor,
    override val surfaceColor: Int = parent.surfaceColor,
    override val accentColor: Int = parent.accentColor
) : DCFContext {
    override val context: Context
        get() = parent.context
}

