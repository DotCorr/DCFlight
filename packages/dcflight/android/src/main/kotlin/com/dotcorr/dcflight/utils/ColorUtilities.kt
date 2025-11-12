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

object ColorUtilities {
    private const val TAG = "ColorUtilities"

    @JvmStatic
    fun getSystemColor(context: Context, colorType: SystemColorType): Int {
        val isDark = isDarkTheme(context)
        
        return when (colorType) {
            SystemColorType.BACKGROUND -> if (isDark) Color.BLACK else Color.WHITE
            SystemColorType.SURFACE -> if (isDark) Color.parseColor("#1C1C1E") else Color.parseColor("#F2F2F7")
            SystemColorType.PRIMARY_TEXT -> if (isDark) Color.WHITE else Color.BLACK
            SystemColorType.SECONDARY_TEXT -> Color.parseColor("#8E8E93")
            SystemColorType.ACCENT -> if (isDark) Color.parseColor("#0A84FF") else Color.parseColor("#007AFF")
            SystemColorType.PRIMARY -> if (isDark) Color.parseColor("#0A84FF") else Color.parseColor("#007AFF")
        }
    }

    @JvmStatic
    fun isDarkTheme(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val uiMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            uiMode == Configuration.UI_MODE_NIGHT_YES
        } else {
            false
        }
    }

    enum class SystemColorType {
        BACKGROUND,
        SURFACE,
        PRIMARY_TEXT,
        SECONDARY_TEXT,
        ACCENT,
        PRIMARY
    }

    @JvmStatic
    fun color(fromHexString: String?): Int? {
        if (fromHexString == null) return null
        var hexString = fromHexString.trim()
        
        if (hexString.startsWith("dcf:", ignoreCase = true)) {
            val dcfColor = hexString.substring(4).trim()
            
            if (dcfColor.equals("black", ignoreCase = true)) {
                return Color.BLACK
            }
            
            if (dcfColor.equals("transparent", ignoreCase = true) || dcfColor.equals("clear", ignoreCase = true)) {
                return Color.TRANSPARENT
            }
            
            if (dcfColor.startsWith("#")) {
                hexString = dcfColor
            } else {
                return getDCFNamedColor(dcfColor.lowercase())
            }
        }
        
        if (hexString.equals("transparent", ignoreCase = true) || hexString.equals("clear", ignoreCase = true)) {
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
                    if (hexString.equals("transparent", ignoreCase = true)) {
                        Color.TRANSPARENT
                    } else {
                        Color.rgb(red, green, blue)
                    }
                }
                else -> {
                    Log.w(TAG, "Invalid hex color format: $hexString")
                    Color.MAGENTA
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse color: $hexString", e)
            Color.MAGENTA
        }
    }

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
    
    private fun getDCFNamedColor(colorName: String): Int? {
        return when (colorName) {
            "black" -> Color.BLACK
            "white" -> Color.WHITE
            "transparent", "clear" -> Color.TRANSPARENT
            
            "gray50", "grey50" -> Color.parseColor("#FAFAFA")
            "gray100", "grey100" -> Color.parseColor("#F5F5F5")
            "gray200", "grey200" -> Color.parseColor("#EEEEEE")
            "gray300", "grey300" -> Color.parseColor("#E0E0E0")
            "gray400", "grey400" -> Color.parseColor("#BDBDBD")
            "gray500", "grey500" -> Color.parseColor("#9E9E9E")
            "gray600", "grey600" -> Color.parseColor("#757575")
            "gray700", "grey700" -> Color.parseColor("#616161")
            "gray800", "grey800" -> Color.parseColor("#424242")
            "gray900", "grey900" -> Color.parseColor("#212121")
            "lightgray", "lightgrey" -> Color.parseColor("#D3D3D3")
            "darkgray", "darkgrey" -> Color.parseColor("#A9A9A9")
            
            "blue" -> Color.parseColor("#007AFF")
            "blue50" -> Color.parseColor("#E3F2FD")
            "blue100" -> Color.parseColor("#BBDEFB")
            "blue200" -> Color.parseColor("#90CAF9")
            "blue300" -> Color.parseColor("#64B5F6")
            "blue400" -> Color.parseColor("#42A5F5")
            "blue500" -> Color.parseColor("#2196F3")
            "blue600" -> Color.parseColor("#1E88E5")
            "blue700" -> Color.parseColor("#1976D2")
            "blue800" -> Color.parseColor("#1565C0")
            "blue900" -> Color.parseColor("#0D47A1")
            "lightblue" -> Color.parseColor("#5AC8FA")
            "darkblue" -> Color.parseColor("#0051D5")
            "blueaccent" -> Color.parseColor("#448AFF")
            "indigo" -> Color.parseColor("#3F51B5")
            "indigoaccent" -> Color.parseColor("#536DFE")
            
            "red" -> Color.parseColor("#FF3B30")
            "red50" -> Color.parseColor("#EFEBE9")
            "red100" -> Color.parseColor("#FFCDD2")
            "red200" -> Color.parseColor("#EF9A9A")
            "red300" -> Color.parseColor("#E57373")
            "red400" -> Color.parseColor("#EF5350")
            "red500" -> Color.parseColor("#F44336")
            "red600" -> Color.parseColor("#E53935")
            "red700" -> Color.parseColor("#D32F2F")
            "red800" -> Color.parseColor("#C62828")
            "red900" -> Color.parseColor("#B71C1C")
            "lightred" -> Color.parseColor("#FF6961")
            "darkred" -> Color.parseColor("#CC0000")
            "redaccent" -> Color.parseColor("#FF5252")
            "pink" -> Color.parseColor("#E91E63")
            "pinkaccent" -> Color.parseColor("#FF4081")
            
            "green" -> Color.parseColor("#34C759")
            "green50" -> Color.parseColor("#E8F5E9")
            "green100" -> Color.parseColor("#C8E6C9")
            "green200" -> Color.parseColor("#A5D6A7")
            "green300" -> Color.parseColor("#81C784")
            "green400" -> Color.parseColor("#66BB6A")
            "green500" -> Color.parseColor("#4CAF50")
            "green600" -> Color.parseColor("#43A047")
            "green700" -> Color.parseColor("#388E3C")
            "green800" -> Color.parseColor("#2E7D32")
            "green900" -> Color.parseColor("#1B5E20")
            "lightgreen" -> Color.parseColor("#90EE90")
            "darkgreen" -> Color.parseColor("#228B22")
            "greenaccent" -> Color.parseColor("#69F0AE")
            "teal" -> Color.parseColor("#009688")
            "tealaccent" -> Color.parseColor("#64FFDA")
            
            "yellow" -> Color.parseColor("#FFCC00")
            "yellow50" -> Color.parseColor("#FFFDE7")
            "yellow100" -> Color.parseColor("#FFF9C4")
            "yellow200" -> Color.parseColor("#FFF59D")
            "yellow300" -> Color.parseColor("#FFF176")
            "yellow400" -> Color.parseColor("#FFEE58")
            "yellow500" -> Color.parseColor("#FFEB3B")
            "yellow600" -> Color.parseColor("#FDD835")
            "yellow700" -> Color.parseColor("#FBC02D")
            "yellow800" -> Color.parseColor("#F9A825")
            "yellow900" -> Color.parseColor("#F57F17")
            "lightyellow" -> Color.parseColor("#FFFF00")
            "darkyellow" -> Color.parseColor("#CC9900")
            "orange" -> Color.parseColor("#FF9500")
            "orange50" -> Color.parseColor("#FFF3E0")
            "orange100" -> Color.parseColor("#FFE0B2")
            "orange200" -> Color.parseColor("#FFCC80")
            "orange300" -> Color.parseColor("#FFB74D")
            "orange400" -> Color.parseColor("#FFA726")
            "orange500" -> Color.parseColor("#FF9800")
            "orange600" -> Color.parseColor("#FB8C00")
            "orange700" -> Color.parseColor("#F57C00")
            "orange800" -> Color.parseColor("#EF6C00")
            "orange900" -> Color.parseColor("#E65100")
            "lightorange" -> Color.parseColor("#FFA500")
            "darkorange" -> Color.parseColor("#FF8C00")
            "orangeaccent" -> Color.parseColor("#FFAB40")
            "deeporange" -> Color.parseColor("#FF5722")
            "deeporangeaccent" -> Color.parseColor("#FF6E40")
            "amber" -> Color.parseColor("#FFC107")
            "amberaccent" -> Color.parseColor("#FFD740")
            
            "purple" -> Color.parseColor("#AF52DE")
            "purple50" -> Color.parseColor("#F3E5F5")
            "purple100" -> Color.parseColor("#E1BEE7")
            "purple200" -> Color.parseColor("#CE93D8")
            "purple300" -> Color.parseColor("#BA68C8")
            "purple400" -> Color.parseColor("#AB47BC")
            "purple500" -> Color.parseColor("#9C27B0")
            "purple600" -> Color.parseColor("#8E24AA")
            "purple700" -> Color.parseColor("#7B1FA2")
            "purple800" -> Color.parseColor("#6A1B9A")
            "purple900" -> Color.parseColor("#4A148C")
            "lightpurple" -> Color.parseColor("#DA70D6")
            "darkpurple" -> Color.parseColor("#8B008B")
            "purpleaccent" -> Color.parseColor("#E040FB")
            "deeppurple" -> Color.parseColor("#673AB7")
            "deeppurpleaccent" -> Color.parseColor("#7C4DFF")
            "violet" -> Color.parseColor("#9C27B0")
            
            "cyan" -> Color.parseColor("#00BCD4")
            "cyan50" -> Color.parseColor("#E0F7FA")
            "cyan100" -> Color.parseColor("#B2EBF2")
            "cyan200" -> Color.parseColor("#80DEEA")
            "cyan300" -> Color.parseColor("#4DD0E1")
            "cyan400" -> Color.parseColor("#26C6DA")
            "cyan500" -> Color.parseColor("#00BCD4")
            "cyan600" -> Color.parseColor("#00ACC1")
            "cyan700" -> Color.parseColor("#0097A7")
            "cyan800" -> Color.parseColor("#00838F")
            "cyan900" -> Color.parseColor("#006064")
            "cyanaccent" -> Color.parseColor("#18FFFF")
            "turquoise" -> Color.parseColor("#40E0D0")
            "aqua" -> Color.parseColor("#00FFFF")
            
            "brown" -> Color.parseColor("#795548")
            "brown50" -> Color.parseColor("#EFEBE9")
            "brown100" -> Color.parseColor("#D7CCC8")
            "brown200" -> Color.parseColor("#BCAAA4")
            "brown300" -> Color.parseColor("#A1887F")
            "brown400" -> Color.parseColor("#8D6E63")
            "brown500" -> Color.parseColor("#795548")
            "brown600" -> Color.parseColor("#6D4C41")
            "brown700" -> Color.parseColor("#5D4037")
            "brown800" -> Color.parseColor("#4E342E")
            "brown900" -> Color.parseColor("#3E2723")
            "tan" -> Color.parseColor("#D2B48C")
            "beige" -> Color.parseColor("#F5F5DC")
            
            "systemblue" -> Color.parseColor("#007AFF")
            "systemgreen" -> Color.parseColor("#34C759")
            "systemindigo" -> Color.parseColor("#5856D6")
            "systemorange" -> Color.parseColor("#FF9500")
            "systempink" -> Color.parseColor("#FF2D55")
            "systempurple" -> Color.parseColor("#AF52DE")
            "systemred" -> Color.parseColor("#FF3B30")
            "systemteal" -> Color.parseColor("#5AC8FA")
            "systemyellow" -> Color.parseColor("#FFCC00")
            
            "materialblue" -> Color.parseColor("#2196F3")
            "materialred" -> Color.parseColor("#F44336")
            "materialgreen" -> Color.parseColor("#4CAF50")
            "materialyellow" -> Color.parseColor("#FFEB3B")
            "materialorange" -> Color.parseColor("#FF9800")
            "materialpurple" -> Color.parseColor("#9C27B0")
            "materialpink" -> Color.parseColor("#E91E63")
            "materialteal" -> Color.parseColor("#009688")
            "materialindigo" -> Color.parseColor("#3F51B5")
            
            "success" -> Color.parseColor("#34C759")
            "error" -> Color.parseColor("#FF3B30")
            "warning" -> Color.parseColor("#FF9500")
            "info" -> Color.parseColor("#007AFF")
            
            "facebook" -> Color.parseColor("#1877F2")
            "twitter" -> Color.parseColor("#1DA1F2")
            "instagram" -> Color.parseColor("#E4405F")
            "linkedin" -> Color.parseColor("#0077B5")
            "youtube" -> Color.parseColor("#FF0000")
            "github" -> Color.parseColor("#181717")
            "google" -> Color.parseColor("#4285F4")
            
            else -> null
        }
    }

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

    private fun parseFlutterColorObject(colorString: String): Int? {
        val pattern = Pattern.compile(
            "alpha:\\s*([\\d.]+).*?red:\\s*([\\d.]+).*?green:\\s*([\\d.]+).*?blue:\\s*([\\d.]+)"
        )
        val matcher = pattern.matcher(colorString)
        if (!matcher.find()) {
            return Color.MAGENTA
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
            Color.MAGENTA
        }
    }

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

    @JvmStatic
    fun argb32(from: Int): Long {
        val a = (Color.alpha(from) and 0xFF).toLong()
        val r = (Color.red(from) and 0xFF).toLong()
        val g = (Color.green(from) and 0xFF).toLong()
        val b = (Color.blue(from) and 0xFF).toLong()
        return (a shl 24) or (r shl 16) or (g shl 8) or b
    }

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

    @JvmStatic
    fun parseColor(colorString: String, fallback: Int = Color.TRANSPARENT): Int {
        return color(colorString) ?: fallback
    }

    @JvmStatic
    fun getColor(
        explicitColor: String?,
        semanticColor: String?,
        props: Map<String, Any?>
    ): Int? {
        if (explicitColor != null) {
            props[explicitColor]?.let { explicitColorStr ->
                val colorInt = color(explicitColorStr.toString())
                if (colorInt != null) {
                    return colorInt
                }
            }
        }
        if (semanticColor != null) {
            props[semanticColor]?.let { semanticColorStr ->
                val colorInt = color(semanticColorStr.toString())
                if (colorInt != null) {
                    return colorInt
                }
            }
        }
        return null
    }
}