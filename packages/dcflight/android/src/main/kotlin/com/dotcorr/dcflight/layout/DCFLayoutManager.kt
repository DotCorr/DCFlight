/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 *             // Use the synchronized calculateAndApplyLayout method
            // This will automatically defer if reconciliation is in progress
            val success = YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)

            // Update flag on main thread
            mainHandler.post {
                needsLayoutCalculation.set(false)
                if (success) {
                } else {
                    // Reschedule if deferred due to reconciliation
                    needsLayoutCalculation.set(true)
                    scheduleLayoutCalculation()
                }
            }the root directory of this source tree.
 */

package com.dotcorr.dcflight.layout

import android.content.res.Resources
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFFrameLayout
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.max

/**
 * EXACT iOS DCFLayoutManager port for Android
 * Matches iOS DCFLayoutManager.swift behavior 1:1
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
    
    // SLIDER PERFORMANCE FIX: Track rapid update mode for adaptive debouncing
    private val isRapidUpdateMode = AtomicBoolean(false)
    private val rapidUpdateTimer = AtomicLong(0L)

    // Dedicated executor for layout operations
    private val layoutExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "DCFLayoutThread").apply {
            priority = Thread.MAX_PRIORITY - 1
        }
    }

    // Main thread handler for UI updates
    private val mainHandler = Handler(Looper.getMainLooper())

    // ENHANCEMENT: Web defaults configuration for cross-platform compatibility
    private var useWebDefaults = false

    init {
        layoutCalculationTimer = Executors.newSingleThreadScheduledExecutor { r ->
            Thread(r, "DCFLayoutCalculation").apply {
                priority = Thread.MAX_PRIORITY - 2
            }
        }
    }

    // MARK: - Web Defaults Configuration

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

    // MARK: - Automatic Layout Calculation

    /**
     * iOS-style layout calculation scheduling with adaptive debouncing for performance
     */
    private fun scheduleLayoutCalculation() {
        // Cancel existing scheduled calculation (matches iOS)
        mainHandler.removeCallbacks(layoutCalculationRunnable)
        
        // SLIDER PERFORMANCE FIX: Use shorter debounce during rapid updates
        // This prevents the choppy performance during slider drag
        val debounceDelay = if (isRapidUpdateMode.get()) 16L else 100L // 16ms = 60fps, 100ms = normal
        
        // Schedule new calculation with adaptive delay
        mainHandler.postDelayed(layoutCalculationRunnable, debounceDelay)
    }
    
    private val layoutCalculationRunnable = Runnable {
        performAutomaticLayoutCalculation()
    }

    /**
     * CRASH FIX: Perform automatic layout calculation with reconciliation coordination
     */
    private fun performAutomaticLayoutCalculation() {
        if (!needsLayoutCalculation.get()) return

        // Use layout executor for calculation
        layoutExecutor.execute {
            // Get screen dimensions
            val displayMetrics = Resources.getSystem().displayMetrics
            val screenWidth = displayMetrics.widthPixels.toFloat()
            val screenHeight = displayMetrics.heightPixels.toFloat()

            // CRASH FIX: Use the synchronized calculateAndApplyLayout method
            // This will automatically defer if reconciliation is in progress
            val success = YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)

            // Update flag on main thread
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

    // MARK: - iOS-Style Rendering Control
    private val pendingViewAttachments = mutableMapOf<String, PendingAttachment>()
    private var isInDelayedRenderingMode = false
    
    data class PendingAttachment(
        val view: View,
        val parentId: String,
        val index: Int
    )
    
    /**
     * Enable iOS-style delayed rendering to prevent flash
     */
    fun enableDelayedRendering() {
        isInDelayedRenderingMode = true
        pendingViewAttachments.clear()
    }
    
    /**
     * Disable delayed rendering and commit all pending attachments
     */
    fun commitDelayedRendering() {
        if (!isInDelayedRenderingMode) return
        
        // Commit all pending attachments in order
        pendingViewAttachments.values.forEach { attachment ->
            val parentView = getView(attachment.parentId)
            if (parentView is ViewGroup) {
                try {
                    if (attachment.view.parent == null) {
                        parentView.addView(attachment.view, attachment.index)
                    }
                } catch (e: Exception) {
                    // Ignore attachment errors during commit
                }
            }
        }
        
        pendingViewAttachments.clear()
        isInDelayedRenderingMode = false
    }

    // MARK: - View Registry Management

    /**
     * Register a view with an ID
     */
    fun registerView(view: View, viewId: String) {
        viewRegistry[viewId] = view
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

    // MARK: - Absolute Layout Management

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

    // MARK: - Cleanup

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

    // MARK: - Layout Management

    /**
     * Apply calculated layout to a view with optional animation - MATCH iOS exactly
     */
    fun applyLayout(viewId: String, left: Float, top: Float, width: Float, height: Float, animationDuration: Long = 0): Boolean {
        val view = getView(viewId) ?: return false

        // Create valid frame with minimum dimensions to ensure visibility
        val frame = Rect(
            left.toInt(),
            top.toInt(),
            (left + max(1f, width)).toInt(),
            (top + max(1f, height)).toInt()
        )

        // Apply on main thread
        if (Looper.myLooper() == Looper.getMainLooper()) {
            if (animationDuration > 0) {
                // TODO: Add animation support if needed
                applyLayoutDirectly(view, frame)
            } else {
                applyLayoutDirectly(view, frame)
            }
        } else {
            // Schedule on main thread
            mainHandler.post {
                if (animationDuration > 0) {
                    // TODO: Add animation support if needed
                    applyLayoutDirectly(view, frame)
                } else {
                    applyLayoutDirectly(view, frame)
                }
            }
        }

        return true
    }

    /**
     * FLASH SCREEN FIX: Apply layout without making view visible
     * Used for batch layout application to prevent flash
     */
    fun applyLayoutWithoutVisibility(viewId: String, left: Float, top: Float, width: Float, height: Float): Boolean {
        val view = getView(viewId) ?: return false

        // Create valid frame with minimum dimensions to ensure visibility
        val frame = Rect(
            left.toInt(),
            top.toInt(),
            (left + max(1f, width)).toInt(),
            (top + max(1f, height)).toInt()
        )

        // Apply layout without making visible
        applyLayoutDirectlyWithoutVisibility(view, frame)
        return true
    }

    // Direct layout application helper - MATCH iOS applyLayoutDirectly exactly
    private fun applyLayoutDirectly(view: View, frame: Rect) {
        // 🔥 HOT RESTART COMPREHENSIVE SAFETY: Multiple validation layers

        // Level 1: Check if view is in invalid state
        if (view.parent == null && view.rootView == null) {
            return
        }

        // Level 2: Validate frame values are reasonable
        if (!frame.width().toFloat().isFinite() || !frame.height().toFloat().isFinite() ||
            !frame.left.toFloat().isFinite() || !frame.top.toFloat().isFinite() ||
            frame.width().toFloat().isNaN() || frame.height().toFloat().isNaN() ||
            frame.left.toFloat().isNaN() || frame.top.toFloat().isNaN()) {
            return
        }

        // Level 3: Check for reasonable bounds
        if (frame.width() > 10000 || frame.height() > 10000 ||
            frame.width() < 0 || frame.height() < 0) {
            return
        }

        // Ensure minimum dimensions
        val safeFrame = Rect(
            frame.left,
            frame.top,
            frame.left + max(1, frame.width()),
            frame.top + max(1, frame.height())
        )

        // Level 4: Final safety - set layout on main thread
        mainHandler.post {
            try {
                if (view.parent != null || view.rootView != null) {
                    // CRITICAL: Mark this view as manually positioned in its parent DCFFrameLayout
                    val parent = view.parent
                    if (parent is DCFFrameLayout) {
                        parent.setChildManuallyPositioned(view, true)
                    }

                    // Set layout - this is the line that was crashing
                    view.layout(safeFrame.left, safeFrame.top, safeFrame.right, safeFrame.bottom)

                    // REACT-LIKE RENDERING: Do NOT manipulate visibility here
                    // Views are visible by default. Visibility management violates React's
                    // render/commit separation and causes timing issues.
                    // Let the natural view lifecycle handle visibility.

                    // Force layout
                    view.requestLayout()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error applying layout to view", e)
            }
        }
    }

    // FLASH SCREEN FIX: Apply layout without making view visible
    private fun applyLayoutDirectlyWithoutVisibility(view: View, frame: Rect) {
        // 🔥 HOT RESTART COMPREHENSIVE SAFETY: Multiple validation layers

        // Level 1: Check if view is in invalid state
        if (view.parent == null && view.rootView == null) {
            return
        }

        // Level 2: Validate frame values are reasonable
        if (!frame.width().toFloat().isFinite() || !frame.height().toFloat().isFinite() ||
            !frame.left.toFloat().isFinite() || !frame.top.toFloat().isFinite() ||
            frame.width().toFloat().isNaN() || frame.height().toFloat().isNaN() ||
            frame.left.toFloat().isNaN() || frame.top.toFloat().isNaN()) {
            return
        }

        // Level 3: Check for reasonable bounds
        if (frame.width() > 10000 || frame.height() > 10000 ||
            frame.width() < 0 || frame.height() < 0) {
            return
        }

        // Ensure minimum dimensions
        val safeFrame = Rect(
            frame.left,
            frame.top,
            frame.left + max(1, frame.width()),
            frame.top + max(1, frame.height())
        )

        // Level 4: Final safety - set layout on main thread
        mainHandler.post {
            try {
                if (view.parent != null || view.rootView != null) {
                    // CRITICAL: Mark this view as manually positioned in its parent DCFFrameLayout
                    val parent = view.parent
                    if (parent is DCFFrameLayout) {
                        parent.setChildManuallyPositioned(view, true)
                    }

                    // Set layout - this is the line that was crashing
                    view.layout(safeFrame.left, safeFrame.top, safeFrame.right, safeFrame.bottom)

                    // FLASH SCREEN FIX: Do NOT make view visible here
                    // Visibility will be set later in batch after all layouts are applied

                    // Force layout
                    view.requestLayout()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error applying layout to view", e)
            }
        }
    }

    /**
     * Queue layout update to happen off the main thread
     */
    fun queueLayoutUpdate(viewId: String, left: Float, top: Float, width: Float, height: Float): Boolean {
        if (!viewRegistry.containsKey(viewId)) {
            return false
        }

        // Store layout in pending queue
        val frame = Rect(left.toInt(), top.toInt(), (left + max(1f, width)).toInt(), (top + max(1f, height)).toInt())

        // Use layout executor to modify shared data
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
     * Apply pending layouts - MATCH iOS exactly
     */
    private fun applyPendingLayouts(animationDuration: Long = 0) {
        // Must be called on main thread
        check(Looper.myLooper() == Looper.getMainLooper()) { "applyPendingLayouts must be called on the main thread" }

        // Reset flag first
        isLayoutUpdateScheduled.set(false)

        // Make local copy to prevent concurrency issues
        val layoutsToApply = mutableMapOf<String, Rect>()

        // Use layoutExecutor to safely get pending layouts
        layoutExecutor.execute {
            layoutsToApply.putAll(pendingLayouts)
            pendingLayouts.clear()

            // Apply all pending layouts on main thread
            mainHandler.post {
                if (animationDuration > 0) {
                    // TODO: Add animation support if needed
                    for ((viewId, frame) in layoutsToApply) {
                        getView(viewId)?.let { view ->
                            applyLayoutDirectly(view, frame)
                        }
                    }
                } else {
                    for ((viewId, frame) in layoutsToApply) {
                        getView(viewId)?.let { view ->
                            applyLayoutDirectly(view, frame)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Component Registration

    /**
     * Register view with layout system - MATCH iOS exactly
     */
    fun registerView(view: View, nodeId: String, componentType: String, componentInstance: DCFComponent) {
        // First, register the view for direct access
        registerView(view, nodeId)

        // Associate the view with its Yoga node
        // Let the component know it's registered - this allows each component
        // to handle its own specialized registration logic
        componentInstance.viewRegisteredWithShadowTree(view, nodeId)

        // If this is a root view, trigger initial layout calculation
        if (nodeId == "root") {
            triggerLayoutCalculation()
        }
    }

    /**
     * Add a child node to a parent in the layout tree with safe coordination
     */
    fun addChildNode(parentId: String, childId: String, index: Int) {
        // Call the synchronized YogaShadowTree addition
        YogaShadowTree.shared.addChildNode(parentId, childId, index)

        // Trigger layout calculation when tree structure changes
        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Remove a node from the layout tree with safe coordination
     */
    fun removeNode(nodeId: String) {
        // Call the synchronized YogaShadowTree removal
        YogaShadowTree.shared.removeNode(nodeId)

        // Trigger layout calculation when tree structure changes
        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Update a node's layout properties
     */
    fun updateNodeWithLayoutProps(nodeId: String, componentType: String, props: Map<String, Any>) {
        YogaShadowTree.shared.updateNodeLayoutProps(nodeId, props)

        // Trigger automatic layout calculation when layout props change
        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Manually trigger layout calculation (useful for initial layout or when needed)
     */
    fun triggerLayoutCalculation() {
        needsLayoutCalculation.set(true)
        
        // SLIDER PERFORMANCE FIX: Detect rapid updates
        val currentTime = System.currentTimeMillis()
        val lastUpdateTime = rapidUpdateTimer.getAndSet(currentTime)
        
        // If updates are happening within 50ms, consider it rapid
        val isRapid = (currentTime - lastUpdateTime) < 50L
        isRapidUpdateMode.set(isRapid)
        
        scheduleLayoutCalculation()
    }

    /**
     * Force immediate layout calculation (synchronous) with reconciliation awareness
     */
    fun calculateLayoutNow() {
        layoutExecutor.execute {
            val displayMetrics = Resources.getSystem().displayMetrics
            val screenWidth = displayMetrics.widthPixels.toFloat()
            val screenHeight = displayMetrics.heightPixels.toFloat()

            // Use the synchronized calculateAndApplyLayout method
            val success = YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)

            mainHandler.post {
                // Layout calculation completed
            }
        }
    }

    fun invalidateAllLayouts() {
        // Clear all pending layouts
        pendingLayouts.clear()
        
        // Mark all views as needing layout recalculation
        needsLayoutCalculation.set(true)
        
        // Trigger immediate layout calculation with current screen dimensions
        triggerLayoutCalculation()
    }

    /**
     * HOT RESTART FIX: Ensure all views start invisible during hot restart
     * This prevents flash during hot restart by making all views invisible initially
     */
    fun prepareForHotRestart() {
        // REACT-LIKE RENDERING: NO visibility manipulation
        // Views remain visible naturally during hot restart
        // Cleanup happens at the VDOM level, not here
        Log.d(TAG, "Hot restart preparation (no visibility manipulation)")
    }
    
    /**
     * DEPRECATED: This function is no longer needed
     * REACT-LIKE RENDERING: Views are visible by default, no need to force visibility
     */
    @Deprecated("Views are visible by default - no need to force visibility")
    fun makeAllViewsVisible() {
        // REMOVED: This anti-pattern caused timing issues and hidden views
        // Views should be visible naturally without manual manipulation
        Log.d(TAG, "makeAllViewsVisible called but no longer needed (views visible by default)")
    }
    
    /**
     * SLIDER PERFORMANCE FIX: Optimize layout application during rapid updates
     * This prevents the flash issue during slider drag by batching layout updates
     */
    fun optimizeForRapidUpdates() {
        if (isRapidUpdateMode.get()) {
            // During rapid updates, defer visibility changes to prevent flash
            mainHandler.postDelayed({
                makeAllViewsVisible()
                isRapidUpdateMode.set(false)
            }, 50) // Small delay to batch visibility changes
        }
    }
    
    /**
     * SLIDER PERFORMANCE FIX: Prevent flash during slider updates
     * This is called specifically when slider values change rapidly
     */
    fun handleSliderUpdate() {
        // Mark as rapid update to use faster debouncing
        isRapidUpdateMode.set(true)
        rapidUpdateTimer.set(System.currentTimeMillis())
        
        // Trigger layout calculation with rapid update optimization
        triggerLayoutCalculation()
    }
}

