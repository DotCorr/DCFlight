/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.utils

import android.content.Context
import android.content.res.Configuration
import android.graphics.Point
import android.os.Build
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/**
 * Utility class for managing screen dimensions and display metrics
 * Provides conversion utilities and screen information for DCFlight framework
 */
object DCFScreenUtilities {
    private const val TAG = "DCFScreenUtilities"
    private const val CHANNEL_NAME = "com.dotcorr.dcflight/screen"

    private var context: Context? = null
    private var methodChannel: MethodChannel? = null
    private var displayMetrics: DisplayMetrics = DisplayMetrics()
    private var screenWidth: Float = 0f
    private var screenHeight: Float = 0f
    private var density: Float = 1f
    private var scaledDensity: Float = 1f
    private var densityDpi: Int = DisplayMetrics.DENSITY_DEFAULT

    /**
     * Singleton instance
     */
    @JvmStatic
    val shared: DCFScreenUtilities = this

    /**
     * Initialize the screen utilities with optional binary messenger
     */
    fun initialize(binaryMessenger: BinaryMessenger?, appContext: Context? = null) {
        Log.d(TAG, "Initializing DCFScreenUtilities")

        appContext?.let {
            this.context = it.applicationContext
            updateDisplayMetrics()
        }

        binaryMessenger?.let {
            methodChannel = MethodChannel(it, CHANNEL_NAME)
            setupMethodChannel()
        }

        Log.d(TAG, "DCFScreenUtilities initialized")
    }

    /**
     * Update display metrics from the current context
     */
    private fun updateDisplayMetrics() {
        context?.let { ctx ->
            val windowManager = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val windowMetrics = windowManager.currentWindowMetrics
                val bounds = windowMetrics.bounds
                screenWidth = bounds.width().toFloat()
                screenHeight = bounds.height().toFloat()
            } else {
                @Suppress("DEPRECATION")
                val display = windowManager.defaultDisplay
                val size = Point()
                @Suppress("DEPRECATION")
                display.getSize(size)
                screenWidth = size.x.toFloat()
                screenHeight = size.y.toFloat()
            }

            val metrics = ctx.resources.displayMetrics
            displayMetrics = metrics
            density = metrics.density
            scaledDensity = metrics.scaledDensity
            densityDpi = metrics.densityDpi

            Log.d(TAG, "Display metrics updated: ${screenWidth}x${screenHeight}, density: $density")
        }
    }

    /**
     * Setup method channel handlers
     */
    private fun setupMethodChannel() {
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getScreenDimensions" -> {
                    result.success(getScreenDimensions())
                }

                "getDisplayMetrics" -> {
                    result.success(getDisplayMetrics())
                }

                "convertDpToPx" -> {
                    val dp = call.argument<Double>("dp")?.toFloat()
                    if (dp != null) {
                        result.success(convertDpToPx(dp))
                    } else {
                        result.error("INVALID_ARGUMENT", "dp value required", null)
                    }
                }

                "convertPxToDp" -> {
                    val px = call.argument<Double>("px")?.toFloat()
                    if (px != null) {
                        result.success(convertPxToDp(px))
                    } else {
                        result.error("INVALID_ARGUMENT", "px value required", null)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Update screen dimensions
     */
    fun updateScreenDimensions(width: Float, height: Float) {
        Log.d(TAG, "Updating screen dimensions: ${width}x${height}")
        screenWidth = width
        screenHeight = height

        // Notify Flutter of dimension change
        notifyDimensionChange()
    }

    /**
     * Get current screen dimensions
     */
    fun getScreenDimensions(): Map<String, Any> {
        return mapOf(
            "width" to screenWidth,
            "height" to screenHeight,
            "widthDp" to convertPxToDp(screenWidth),
            "heightDp" to convertPxToDp(screenHeight)
        )
    }

    /**
     * Get display metrics
     */
    fun getDisplayMetrics(): Map<String, Any> {
        return mapOf(
            "density" to density,
            "scaledDensity" to scaledDensity,
            "densityDpi" to densityDpi,
            "xdpi" to displayMetrics.xdpi,
            "ydpi" to displayMetrics.ydpi
        )
    }

    /**
     * Convert dp to pixels
     */
    fun convertDpToPx(dp: Float): Float {
        return dp * density
    }

    /**
     * Convert dp to pixels (integer)
     */
    fun convertDpToPxInt(dp: Float): Int {
        return (dp * density).roundToInt()
    }

    /**
     * Convert pixels to dp
     */
    fun convertPxToDp(px: Float): Float {
        return if (density != 0f) px / density else px
    }

    /**
     * Convert pixels to dp (integer)
     */
    fun convertPxToDpInt(px: Float): Int {
        return if (density != 0f) (px / density).roundToInt() else px.roundToInt()
    }

    /**
     * Convert sp to pixels for text
     */
    fun convertSpToPx(sp: Float): Float {
        return sp * scaledDensity
    }

    /**
     * Convert pixels to sp for text
     */
    fun convertPxToSp(px: Float): Float {
        return if (scaledDensity != 0f) px / scaledDensity else px
    }

    /**
     * Get screen width in pixels
     */
    fun getScreenWidth(): Float = screenWidth

    /**
     * Get screen height in pixels
     */
    fun getScreenHeight(): Float = screenHeight

    /**
     * Get screen width in dp
     */
    fun getScreenWidthDp(): Float = convertPxToDp(screenWidth)

    /**
     * Get screen height in dp
     */
    fun getScreenHeightDp(): Float = convertPxToDp(screenHeight)

    /**
     * Get screen density
     */
    fun getDensity(): Float = density

    /**
     * Get scaled density for text
     */
    fun getScaledDensity(): Float = scaledDensity

    /**
     * Get density DPI
     */
    fun getDensityDpi(): Int = densityDpi

    /**
     * Check if device is in landscape orientation
     */
    fun isLandscape(): Boolean {
        return screenWidth > screenHeight
    }

    /**
     * Check if device is in portrait orientation
     */
    fun isPortrait(): Boolean {
        return screenHeight >= screenWidth
    }

    /**
     * Get current orientation
     */
    fun getOrientation(): String {
        return if (isLandscape()) "landscape" else "portrait"
    }

    /**
     * Get screen aspect ratio
     */
    fun getAspectRatio(): Float {
        return if (screenHeight != 0f) screenWidth / screenHeight else 1f
    }

    /**
     * Check if device is a tablet based on screen size
     */
    fun isTablet(): Boolean {
        val smallestWidthDp = minOf(getScreenWidthDp(), getScreenHeightDp())
        return smallestWidthDp >= 600f
    }

    /**
     * Get device type based on screen size
     */
    fun getDeviceType(): String {
        val smallestWidthDp = minOf(getScreenWidthDp(), getScreenHeightDp())
        return when {
            smallestWidthDp >= 720f -> "xlarge_tablet"
            smallestWidthDp >= 600f -> "tablet"
            smallestWidthDp >= 480f -> "large_phone"
            smallestWidthDp >= 360f -> "normal_phone"
            else -> "small_phone"
        }
    }

    /**
     * Calculate responsive size based on screen width
     */
    fun getResponsiveSize(baseSize: Float, scaleFactor: Float = 1.0f): Float {
        val referenceWidth = 375f // iPhone 11 Pro width as reference
        val scale = getScreenWidthDp() / referenceWidth
        return baseSize * scale * scaleFactor
    }

    /**
     * Get safe area insets (simplified version)
     */
    fun getSafeAreaInsets(): Map<String, Float> {
        // This is a simplified implementation
        // In a real app, you'd need to account for notches, navigation bars, etc.
        return mapOf(
            "top" to 0f,
            "bottom" to 0f,
            "left" to 0f,
            "right" to 0f
        )
    }

    /**
     * Handle configuration changes
     */
    fun onConfigurationChanged(newConfig: Configuration) {
        Log.d(TAG, "Configuration changed")
        updateDisplayMetrics()
        notifyDimensionChange()
        
        // MATCH iOS: Trigger layout recalculation on orientation change
        DCFLayoutManager.shared.calculateLayoutNow()
    }

    /**
     * Notify Flutter about dimension changes
     */
    private fun notifyDimensionChange() {
        methodChannel?.invokeMethod(
            "onDimensionChange",
            getScreenDimensions()
        )
    }

    /**
     * Cleanup resources
     */
    fun cleanup() {
        Log.d(TAG, "Cleaning up DCFScreenUtilities")
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        context = null
    }

    /**
     * Get a percentage of screen width
     */
    fun getScreenWidthPercent(percent: Float): Float {
        return screenWidth * (percent / 100f)
    }

    /**
     * Get a percentage of screen height
     */
    fun getScreenHeightPercent(percent: Float): Float {
        return screenHeight * (percent / 100f)
    }

    /**
     * Convert between different density buckets
     */
    fun getDensityBucket(): String {
        return when (densityDpi) {
            DisplayMetrics.DENSITY_LOW -> "ldpi"
            DisplayMetrics.DENSITY_MEDIUM -> "mdpi"
            DisplayMetrics.DENSITY_HIGH -> "hdpi"
            DisplayMetrics.DENSITY_XHIGH -> "xhdpi"
            DisplayMetrics.DENSITY_XXHIGH -> "xxhdpi"
            DisplayMetrics.DENSITY_XXXHIGH -> "xxxhdpi"
            else -> "unknown"
        }
    }

    /**
     * Get scale factor for current density
     */
    fun getDensityScaleFactor(): Float {
        return when (densityDpi) {
            DisplayMetrics.DENSITY_LOW -> 0.75f
            DisplayMetrics.DENSITY_MEDIUM -> 1.0f
            DisplayMetrics.DENSITY_HIGH -> 1.5f
            DisplayMetrics.DENSITY_XHIGH -> 2.0f
            DisplayMetrics.DENSITY_XXHIGH -> 3.0f
            DisplayMetrics.DENSITY_XXXHIGH -> 4.0f
            else -> density
        }
    }
}
