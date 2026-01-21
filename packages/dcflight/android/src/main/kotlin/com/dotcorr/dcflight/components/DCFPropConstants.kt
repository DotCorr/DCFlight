/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

/**
 * Centralized constants for DCFlight prop names.
 * 
 * This ensures consistency across the framework and prevents hardcoding prop names
 * in individual components. Module developers should reference these constants
 * when implementing custom components.
 */
object DCFPropConstants {
    /**
     * Semantic color prop names used throughout the framework.
     * These props are automatically resolved from the theme system.
     */
    val SEMANTIC_COLOR_PROPS = listOf(
        "primaryColor",
        "secondaryColor",
        "tertiaryColor",
        "accentColor"
    )
    
    /**
     * Common state prop names that components may use.
     * These are props that represent component state (not just styling).
     */
    val COMMON_STATE_PROPS = listOf(
        "enabled",
        "disabled",
        "selected",
        "checked",
        "value",
        "selectedIndex"
    )
    
    /**
     * Complete list of layout-related prop names.
     * These props affect component size, position, and layout behavior.
     * 
     * This list matches the layout props extracted by DCFlightNative
     * to ensure consistency between component-level and bridge-level checks.
     */
    val LAYOUT_PROPS = listOf(
        // Size
        "width", "height", "minWidth", "maxWidth", "minHeight", "maxHeight",
        // Margin
        "margin", "marginTop", "marginRight", "marginBottom", "marginLeft",
        "marginHorizontal", "marginVertical",
        // Padding
        "padding", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
        "paddingHorizontal", "paddingVertical",
        // Position
        "left", "top", "right", "bottom", "position",
        // Transform
        "translateX", "translateY", "rotateInDegrees",
        "scale", "scaleX", "scaleY",
        // Flexbox
        "flexDirection", "justifyContent", "alignItems", "alignSelf", "alignContent",
        "flexWrap", "flex", "flexGrow", "flexShrink", "flexBasis",
        // Display
        "display", "overflow", "direction", "borderWidth",
        // Other
        "aspectRatio", "gap", "rowGap", "columnGap"
    )
}

