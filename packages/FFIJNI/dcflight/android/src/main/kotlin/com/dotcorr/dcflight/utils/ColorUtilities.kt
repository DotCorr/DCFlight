/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.utils

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.util.Log
import android.util.TypedValue
import java.util.regex.Pattern
import kotlin.math.abs

/**
 * Utilities for color conversion
 * Following iOS ColorUtilities implementation with Android adaptivity support
 */
object ColorUtilities {

    private const val TAG = "ColorUtilities"

    /**
     * Get adaptive system color based on current theme (light/dark mode)
     * Matches iOS behavior for system colors
     */
    @JvmStatic
    fun getSystemColor(context: Context, colorType: SystemColorType): Int {
        return try {
            val typedValue = TypedValue()
            val attrId = when (colorType) {
                SystemColorType.BACKGROUND -> android.R.attr.colorBackground
                SystemColorType.SURFACE -> android.R.attr.colorBackground
                SystemColorType.PRIMARY_TEXT -> android.R.attr.textColorPrimary
                SystemColorType.SECONDARY_TEXT -> android.R.attr.textColorSecondary
                SystemColorType.ACCENT -> android.R.attr.colorAccent
                SystemColorType.PRIMARY -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    android.R.attr.colorPrimary
                } else {
                    android.R.attr.colorAccent
                }
            }
            
            if (context.theme.resolveAttribute(attrId, typedValue, true)) {
                typedValue.data
            } else {
                val isDarkTheme = isDarkTheme(context)
                when (colorType) {
                    SystemColorType.BACKGROUND -> if (isDarkTheme) Color.BLACK else Color.WHITE
                    SystemColorType.SURFACE -> if (isDarkTheme) Color.parseColor("#121212") else Color.WHITE
                    SystemColorType.PRIMARY_TEXT -> if (isDarkTheme) Color.WHITE else Color.BLACK
                    SystemColorType.SECONDARY_TEXT -> if (isDarkTheme) Color.parseColor("#B3FFFFFF") else Color.parseColor("#8A000000")
                    SystemColorType.ACCENT -> Color.parseColor("#2196F3")
                    SystemColorType.PRIMARY -> Color.parseColor("#2196F3")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to resolve system color: $colorType", e)
            when (colorType) {
                SystemColorType.BACKGROUND -> Color.WHITE
                SystemColorType.SURFACE -> Color.WHITE
                SystemColorType.PRIMARY_TEXT -> Color.BLACK
                SystemColorType.SECONDARY_TEXT -> Color.GRAY
                SystemColorType.ACCENT -> Color.parseColor("#2196F3")
                SystemColorType.PRIMARY -> Color.parseColor("#2196F3")
            }
        }
    }

    /**
     * Check if current theme is dark mode
     */
    @JvmStatic
    fun isDarkTheme(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val uiMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            uiMode == Configuration.UI_MODE_NIGHT_YES
        } else {
            false
        }
    }

    /**
     * System color types that match iOS system colors
     */
    enum class SystemColorType {
        BACKGROUND,      // UIColor.systemBackground
        SURFACE,         // UIColor.secondarySystemBackground  
        PRIMARY_TEXT,    // UIColor.label
        SECONDARY_TEXT,  // UIColor.secondaryLabel
        ACCENT,          // UIColor.systemBlue
        PRIMARY          // UIColor.systemBlue/colorPrimary
    }

    /**
     * Convert a hex string to a color Int
     * Format: "#RRGGBB" or "#RRGGBBAA" or "#AARRGGBB" (Android/Flutter format)
     */
    @JvmStatic
    fun color(fromHexString: String?): Int? {
        if (fromHexString == null) return null

        val hexString = fromHexString.trim()

        if (hexString.equals("transparent", ignoreCase = true)) {
            return Color.TRANSPARENT
        }

        if (hexString.contains("Color(") && hexString.contains("alpha:")) {
            return parseFlutterColorObject(hexString)
        }

        var cleanHexString = hexString.trimStart('#')

        try {
            val intValue = cleanHexString.toLongOrNull()
            if (intValue != null && intValue >= 0) {
                if (intValue == 0L) {
                    return Color.TRANSPARENT
                }

                cleanHexString = String.format("%08x", intValue)
            }
        } catch (e: Exception) {
        }

        getNamedColor(cleanHexString.lowercase())?.let {
            return it
        }

        if (cleanHexString.length == 3) {
            val r = cleanHexString[0].toString()
            val g = cleanHexString[1].toString()
            val b = cleanHexString[2].toString()
            cleanHexString = r + r + g + g + b + b
        }

        return try {
            when (cleanHexString.length) {
                8 -> {
                    val alpha = cleanHexString.substring(0, 2).toInt(16)
                    val red = cleanHexString.substring(2, 4).toInt(16)
                    val green = cleanHexString.substring(4, 6).toInt(16)
                    val blue = cleanHexString.substring(6, 8).toInt(16)

                    if (alpha == 0) {
                        Color.TRANSPARENT
                    } else {
                        Color.argb(alpha, red, green, blue)
                    }
                }

                6 -> {
                    val red = cleanHexString.substring(0, 2).toInt(16)
                    val green = cleanHexString.substring(2, 4).toInt(16)
                    val blue = cleanHexString.substring(4, 6).toInt(16)

                    if (red == 0 && green == 0 && blue == 0 &&
                        (hexString.contains("transparent") || hexString.contains("00000"))
                    ) {
                        Color.TRANSPARENT
                    } else {
                        Color.rgb(red, green, blue)
                    }
                }

                else -> {
                    Log.w(TAG, "Invalid hex color format: $hexString")
                    Color.MAGENTA // Return a bright color to make issues obvious
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse color: $hexString", e)
            Color.MAGENTA // Return a bright color to make issues obvious
        }
    }

    /**
     * Centralized named color handling
     */
    private fun getNamedColor(colorName: String): Int? {
        return when (colorName) {
            "red" -> Color.RED
            "green" -> Color.GREEN
            "blue" -> Color.BLUE
            "black" -> Color.BLACK
            "white" -> Color.WHITE
            "yellow" -> Color.YELLOW
            "purple" -> Color.parseColor("#800080")
            "orange" -> Color.parseColor("#FFA500")
            "cyan" -> Color.CYAN
            "clear", "transparent" -> Color.TRANSPARENT
            "gray", "grey" -> Color.GRAY
            "lightgray", "lightgrey" -> Color.LTGRAY
            "darkgray", "darkgrey" -> Color.DKGRAY
            "brown" -> Color.parseColor("#A52A2A")
            "magenta" -> Color.MAGENTA
            else -> null
        }
    }

    /**
     * Check if a color string represents transparent
     */
    @JvmStatic
    fun isTransparent(colorString: String): Boolean {
        val lowerString = colorString.lowercase().trim()
        return lowerString == "transparent" ||
                lowerString == "clear" ||
                lowerString == "0x00000000" ||
                lowerString == "rgba(0,0,0,0)" ||
                lowerString == "#00000000" ||
                lowerString == "0"
    }

    /**
     * Parse Flutter Color object format: "Color(alpha: 1.0000, red: 0.0000, green: 0.0000, blue: 0.0000, colorSpace: ColorSpace.sRGB)"
     */
    private fun parseFlutterColorObject(colorString: String): Int? {
        Log.d(TAG, "Parsing Flutter color object: $colorString")

        val pattern = Pattern.compile(
            "alpha:\\s*([\\d.]+).*?red:\\s*([\\d.]+).*?green:\\s*([\\d.]+).*?blue:\\s*([\\d.]+)"
        )
        val matcher = pattern.matcher(colorString)

        if (!matcher.find()) {
            Log.w(TAG, "Failed to parse Flutter color format: $colorString")
            return Color.MAGENTA // Return obvious color for debugging
        }

        return try {
            val alpha = matcher.group(1)?.toDoubleOrNull() ?: 1.0
            val red = matcher.group(2)?.toDoubleOrNull() ?: 0.0
            val green = matcher.group(3)?.toDoubleOrNull() ?: 0.0
            val blue = matcher.group(4)?.toDoubleOrNull() ?: 0.0

            Color.argb(
                (alpha * 255).toInt(),
                (red * 255).toInt(),
                (green * 255).toInt(),
                (blue * 255).toInt()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing Flutter color values", e)
            Color.MAGENTA
        }
    }

    /**
     * Convert a color Int back to a hex string for debugging purposes
     * Returns format: "#RRGGBBAA" or "#RRGGBB"
     */
    @JvmStatic
    fun hexString(from: Int): String {
        val a = Color.alpha(from)
        val r = Color.red(from)
        val g = Color.green(from)
        val b = Color.blue(from)

        return if (a == 255) {
            String.format("#%02X%02X%02X", r, g, b)
        } else {
            String.format("#%02X%02X%02X%02X", r, g, b, a)
        }
    }

    /**
     * Convert color to ARGB32 format (matching Flutter)
     */
    @JvmStatic
    fun argb32(from: Int): Long {
        val a = (Color.alpha(from) and 0xFF).toLong()
        val r = (Color.red(from) and 0xFF).toLong()
        val g = (Color.green(from) and 0xFF).toLong()
        val b = (Color.blue(from) and 0xFF).toLong()

        return (a shl 24) or (r shl 16) or (g shl 8) or b
    }

    /**
     * Helper method for color comparison
     */
    @JvmStatic
    fun colorsAreEqual(color1: Int?, color2: Int?): Boolean {
        if (color1 == null && color2 == null) return true
        if (color1 == null || color2 == null) return false

        val a1 = Color.alpha(color1)
        val r1 = Color.red(color1)
        val g1 = Color.green(color1)
        val b1 = Color.blue(color1)

        val a2 = Color.alpha(color2)
        val r2 = Color.red(color2)
        val g2 = Color.green(color2)
        val b2 = Color.blue(color2)

        val epsilon = 1

        return abs(a1 - a2) < epsilon &&
                abs(r1 - r2) < epsilon &&
                abs(g1 - g2) < epsilon &&
                abs(b1 - b2) < epsilon
    }

    /**
     * Debug method to print color information
     */
    @JvmStatic
    fun debugPrint(color: Int?, name: String = "Color") {
        if (color == null) {
            Log.d(TAG, "$name: null")
            return
        }

        val a = Color.alpha(color)
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)

        Log.d(
            TAG,
            "$name: A=$a, R=$r, G=$g, B=$b | Hex: ${hexString(color)} | ARGB32: ${argb32(color)}"
        )
    }

    /**
     * Parse color with fallback
     */
    @JvmStatic
    fun parseColor(colorString: String, fallback: Int = Color.TRANSPARENT): Int {
        return color(colorString) ?: fallback
    }
}

