/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.layout

import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.R
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Manages layout for DCFlight components
 * Handles automatic layout calculations natively when layout props change
 * Following iOS DCFLayoutManager pattern
 */
class DCFLayoutManager private constructor() {

    companion object {
        private const val TAG = "DCFLayoutManager"

        @JvmField
        val shared = DCFLayoutManager()
    }

    // Set of views using absolute layout (controlled by Dart)
    private val absoluteLayoutViews = mutableSetOf<View>()

    // Map view IDs to actual Views for direct access
    internal val viewRegistry = ConcurrentHashMap<String, View>()

    // For optimizing layout updates
    private val pendingLayouts = ConcurrentHashMap<String, Rect>()
    private val isLayoutUpdateScheduled = AtomicBoolean(false)

    // Track when layout calculation is needed
    private val needsLayoutCalculation = AtomicBoolean(false)
    private var layoutCalculationTimer: ScheduledExecutorService? = null

    // Dedicated executor for layout operations
    private val layoutExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "DCFLayoutThread").apply {
            priority = Thread.MAX_PRIORITY - 1
        }
    }

    // Main thread handler for UI updates
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Initialize the DCFLayoutManager
     */
    fun initialize() {
        Log.d(TAG, "Initializing DCFLayoutManager")
        // Clear any existing state
        absoluteLayoutViews.clear()
        viewRegistry.clear()
        pendingLayouts.clear()
        isLayoutUpdateScheduled.set(false)
        needsLayoutCalculation.set(false)

        // Initialize layout calculation timer
        layoutCalculationTimer?.shutdown()
        layoutCalculationTimer = Executors.newSingleThreadScheduledExecutor { r ->
            Thread(r, "DCFLayoutCalculation").apply {
                priority = Thread.MAX_PRIORITY - 2
            }
        }

        Log.d(TAG, "DCFLayoutManager initialized")
    }

    // Web defaults configuration for cross-platform compatibility
    private var useWebDefaults = false

    /**
     * Cleanup all resources
     */
    fun cleanup() {
        Log.d(TAG, "Cleaning up DCFLayoutManager")

        // Clear all collections
        absoluteLayoutViews.clear()
        viewRegistry.clear()
        pendingLayouts.clear()

        // Reset flags
        isLayoutUpdateScheduled.set(false)
        needsLayoutCalculation.set(false)

        // Shutdown executors
        layoutCalculationTimer?.shutdown()
        layoutCalculationTimer = null

        layoutExecutor.shutdown()

        Log.d(TAG, "DCFLayoutManager cleanup complete")
    }

    init {
        layoutCalculationTimer = Executors.newSingleThreadScheduledExecutor()
    }

    /**
     * Configure web defaults for cross-platform compatibility
     * When enabled, aligns with CSS defaults: flex-direction: row, align-content: stretch, flex-shrink: 1
     */
    fun setUseWebDefaults(enabled: Boolean) {
        useWebDefaults = enabled

        // Apply web defaults to the root node if it exists
        if (enabled) {
            YogaShadowTree.shared.applyWebDefaults()
        }

        Log.d(TAG, "UseWebDefaults set to $enabled")
    }

    /**
     * Get current web defaults configuration
     */
    fun getUseWebDefaults(): Boolean = useWebDefaults

    /**
     * Register a view with an ID
     */
    fun registerView(view: View, viewId: String) {
        viewRegistry[viewId] = view
        view.setTag(R.id.dcf_view_id, viewId)
    }

    /**
     * Unregister a view
     */
    fun unregisterView(viewId: String) {
        val view = viewRegistry.remove(viewId)
        view?.let {
            absoluteLayoutViews.remove(it)
        }
    }

    /**
     * Get view by ID
     */
    fun getView(viewId: String): View? = viewRegistry[viewId]

    /**
     * Mark a view as using absolute layout (controlled by Dart side)
     */
    fun setViewUsingAbsoluteLayout(view: View) {
        absoluteLayoutViews.add(view)
    }

    /**
     * Check if a view uses absolute layout
     */
    fun isUsingAbsoluteLayout(view: View): Boolean = absoluteLayoutViews.contains(view)

    /**
     * Clean up resources for a view
     */
    fun cleanUp(viewId: String) {
        val view = viewRegistry[viewId]
        view?.let {
            absoluteLayoutViews.remove(it)
        }
        viewRegistry.remove(viewId)
    }

    /**
     * Apply styles to a view
     */
    fun applyStyles(view: View, props: Map<String, Any?>) {
        view.applyStyles(props)
    }

    /**
     * Queue layout update to happen off the main thread
     */
    fun queueLayoutUpdate(viewId: String, left: Float, top: Float, width: Float, height: Float): Boolean {
        val view = viewRegistry[viewId] ?: return false

        // Store layout in pending queue
        val frame = Rect(
            left.toInt(),
            top.toInt(),
            (left + maxOf(1f, width)).toInt(),
            (top + maxOf(1f, height)).toInt()
        )

        layoutExecutor.execute {
            pendingLayouts[viewId] = frame

            if (!isLayoutUpdateScheduled.getAndSet(true)) {
                // Schedule layout application on main thread
                mainHandler.post {
                    applyPendingLayouts()
                }
            }
        }

        return true
    }

    /**
     * Apply calculated layout to a view with optional animation
     */
    fun applyLayout(
        viewId: String,
        left: Float,
        top: Float,
        width: Float,
        height: Float,
        animationDuration: Long = 0
    ): Boolean {
        val view = getView(viewId) ?: return false

        // Create valid frame with minimum dimensions to ensure visibility
        val finalWidth = maxOf(1f, width).toInt()
        val finalHeight = maxOf(1f, height).toInt()
        val finalLeft = left.toInt()
        val finalTop = top.toInt()

        // Apply on main thread
        if (Looper.myLooper() == Looper.getMainLooper()) {
            if (animationDuration > 0) {
                view.animate()
                    .x(finalLeft.toFloat())
                    .y(finalTop.toFloat())
                    .setDuration(animationDuration)
                    .withEndAction {
                        applyLayoutDirectly(view, finalLeft, finalTop, finalWidth, finalHeight)
                    }
                    .start()
            } else {
                applyLayoutDirectly(view, finalLeft, finalTop, finalWidth, finalHeight)
            }
        } else {
            mainHandler.post {
                if (animationDuration > 0) {
                    view.animate()
                        .x(finalLeft.toFloat())
                        .y(finalTop.toFloat())
                        .setDuration(animationDuration)
                        .withEndAction {
                            applyLayoutDirectly(view, finalLeft, finalTop, finalWidth, finalHeight)
                        }
                        .start()
                } else {
                    applyLayoutDirectly(view, finalLeft, finalTop, finalWidth, finalHeight)
                }
            }
        }

        return true
    }

    /**
     * Direct layout application helper
     */
    private fun applyLayoutDirectly(view: View, left: Int, top: Int, width: Int, height: Int) {
        // Multiple validation layers for safety
        if (view.parent == null && view.context == null) {
            return
        }

        // Validate frame values are reasonable
        if (!width.isFinite() || !height.isFinite() || width > 10000 || height > 10000) {
            return
        }

        // Ensure minimum dimensions
        val safeWidth = maxOf(1, width)
        val safeHeight = maxOf(1, height)

        // Apply layout based on parent type
        val parent = view.parent as? ViewGroup
        if (parent != null) {
            val params = view.layoutParams ?: ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )

            // Set size
            params.width = safeWidth
            params.height = safeHeight

            // Set position using margins if supported
            if (params is ViewGroup.MarginLayoutParams) {
                params.leftMargin = left
                params.topMargin = top
                params.rightMargin = 0
                params.bottomMargin = 0
            }

            view.layoutParams = params
        } else {
            // Fallback: Use absolute positioning
            view.x = left.toFloat()
            view.y = top.toFloat()
            view.layoutParams?.let {
                it.width = safeWidth
                it.height = safeHeight
            }
        }

        // Force layout
        view.requestLayout()
    }

    /**
     * Apply a dictionary of calculated layout frames
     */
    fun applyLayoutResults(results: Map<String, Rect>, animationDuration: Long = 0) {
        // Must be called on main thread
        check(Looper.myLooper() == Looper.getMainLooper()) {
            "applyLayoutResults must be called on the main thread"
        }

        for ((viewId, frame) in results) {
            getView(viewId)?.let { view ->
                val width = frame.width()
                val height = frame.height()
                if (animationDuration > 0) {
                    view.animate()
                        .x(frame.left.toFloat())
                        .y(frame.top.toFloat())
                        .setDuration(animationDuration)
                        .withEndAction {
                            applyLayoutDirectly(view, frame.left, frame.top, width, height)
                        }
                        .start()
                } else {
                    applyLayoutDirectly(view, frame.left, frame.top, width, height)
                }
            }
        }
    }

    /**
     * Batch process layout updates
     */
    private fun applyPendingLayouts(animationDuration: Long = 0) {
        // Must be called on main thread
        check(Looper.myLooper() == Looper.getMainLooper()) {
            "applyPendingLayouts must be called on the main thread"
        }

        // Reset flag first
        isLayoutUpdateScheduled.set(false)

        // Make local copy to prevent concurrency issues
        val layoutsToApply = mutableMapOf<String, Rect>()

        // Get pending layouts safely
        layoutExecutor.execute {
            layoutsToApply.putAll(pendingLayouts)
            pendingLayouts.clear()

            mainHandler.post {
                // Apply all pending layouts
                for ((viewId, frame) in layoutsToApply) {
                    getView(viewId)?.let { view ->
                        val width = frame.width()
                        val height = frame.height()
                        if (animationDuration > 0) {
                            view.animate()
                                .x(frame.left.toFloat())
                                .y(frame.top.toFloat())
                                .setDuration(animationDuration)
                                .withEndAction {
                                    applyLayoutDirectly(view, frame.left, frame.top, width, height)
                                }
                                .start()
                        } else {
                            applyLayoutDirectly(view, frame.left, frame.top, width, height)
                        }
                    }
                }
            }
        }
    }

    /**
     * Register view with layout system
     */
    fun registerView(view: View, nodeId: String, componentType: String, componentInstance: DCFComponent) {
        // First, register the view for direct access
        registerView(view, nodeId)

        // Let the component know it's registered
        componentInstance.viewRegisteredWithShadowTree(view, nodeId)

        // If this is a root view, trigger initial layout calculation
        if (nodeId == "root") {
            triggerLayoutCalculation()
        }
    }

    /**
     * Add a child node to a parent in the layout tree
     */
    fun addChildNode(parentId: String, childId: String, index: Int) {
        Log.d(TAG, "Adding child node: $childId to parent: $parentId at index: $index")

        // Call the YogaShadowTree addition
        YogaShadowTree.shared.addChildNode(parentId, childId, index)

        // Trigger layout calculation when tree structure changes
        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Remove a node from the layout tree
     */
    fun removeNode(nodeId: String) {
        Log.d(TAG, "Removing node: $nodeId")

        // Call the YogaShadowTree removal
        YogaShadowTree.shared.removeNode(nodeId)

        // Trigger layout calculation when tree structure changes
        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Update a node's layout properties
     */
    fun updateNodeWithLayoutProps(nodeId: String, componentType: String, props: Map<String, Any?>) {
        YogaShadowTree.shared.updateNodeLayoutProps(nodeId, props)

        // Trigger automatic layout calculation when layout props change
        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Manually trigger layout calculation
     */
    fun triggerLayoutCalculation() {
        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Schedule automatic layout calculation with reconciliation awareness
     */
    private fun scheduleLayoutCalculation() {
        // Cancel existing timer
        layoutCalculationTimer?.shutdownNow()
        layoutCalculationTimer = Executors.newSingleThreadScheduledExecutor()

        // Schedule new calculation with debouncing (100ms delay)
        layoutCalculationTimer?.schedule({
            performAutomaticLayoutCalculation()
        }, 100, TimeUnit.MILLISECONDS)
    }

    /**
     * Perform automatic layout calculation
     */
    private fun performAutomaticLayoutCalculation() {
        if (!needsLayoutCalculation.get()) return

        layoutExecutor.execute {
            // Get screen dimensions
            val context = viewRegistry.values.firstOrNull()?.context ?: return@execute
            val displayMetrics = context.resources.displayMetrics
            val screenWidth = displayMetrics.widthPixels.toFloat()
            val screenHeight = displayMetrics.heightPixels.toFloat()

            // Calculate and apply layout
            val success = YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)

            mainHandler.post {
                needsLayoutCalculation.set(false)
                if (success) {
                    Log.d(TAG, "Layout calculation successful")
                } else {
                    Log.w(TAG, "Layout calculation deferred, rescheduling")
                    // Reschedule if deferred due to reconciliation
                    needsLayoutCalculation.set(true)
                    scheduleLayoutCalculation()
                }
            }
        }
    }

    /**
     * Force immediate layout calculation (synchronous)
     */
    fun calculateLayoutNow() {
        layoutExecutor.execute {
            val context = viewRegistry.values.firstOrNull()?.context ?: return@execute
            val displayMetrics = context.resources.displayMetrics
            val screenWidth = displayMetrics.widthPixels.toFloat()
            val screenHeight = displayMetrics.heightPixels.toFloat()

            val success = YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)

            mainHandler.post {
                Log.d(
                    TAG,
                    if (success) "Immediate layout calculation successful" else "Immediate layout calculation deferred"
                )
            }
        }
    }

    /**
     * Clear all registered views
     */
    fun clearAll() {
        val allViewIds = viewRegistry.keys.toList()
        for (viewId in allViewIds) {
            if (viewId != "root") {
                cleanUp(viewId)
            }
        }
    }

    /**
     * Shutdown the layout manager
     */
    fun shutdown() {
        layoutCalculationTimer?.shutdown()
        layoutExecutor.shutdown()
    }
}

/**
 * Extension function to apply styles to a view
 */
private fun View.applyStyles(props: Map<String, Any?>) {
    // This would be implemented in a separate ViewStylesExtension file
    // For now, it's a placeholder
    Log.d("ViewStyles", "Applying styles to view: $props")
}

private fun Int.isFinite(): Boolean = this != Int.MAX_VALUE && this != Int.MIN_VALUE
