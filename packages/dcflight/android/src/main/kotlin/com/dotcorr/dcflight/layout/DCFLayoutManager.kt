/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
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


class DCFLayoutManager private constructor() {

    companion object {
        private const val TAG = "DCFLayoutManager"

        @JvmField
        val shared = DCFLayoutManager()
    }

    private val absoluteLayoutViews = mutableSetOf<View>()

    internal val viewRegistry = ConcurrentHashMap<String, View>()

    private val pendingLayouts = ConcurrentHashMap<String, Rect>()
    private val isLayoutUpdateScheduled = AtomicBoolean(false)

    private val needsLayoutCalculation = AtomicBoolean(false)
    private var layoutCalculationTimer: ScheduledExecutorService? = null
    
    private val isRapidUpdateMode = AtomicBoolean(false)
    private val rapidUpdateTimer = AtomicLong(0L)

    private val layoutExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "DCFLayoutThread").apply {
            priority = Thread.MAX_PRIORITY - 1
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private var useWebDefaults = false

    init {
        layoutCalculationTimer = Executors.newSingleThreadScheduledExecutor { r ->
            Thread(r, "DCFLayoutCalculation").apply {
                priority = Thread.MAX_PRIORITY - 2
            }
        }
    }


    /**
     * Configure web defaults for cross-platform compatibility
     * When enabled, aligns with CSS defaults: flex-direction: row, align-content: stretch, flex-shrink: 1
     */
    fun setUseWebDefaults(enabled: Boolean) {
        useWebDefaults = enabled

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
     * iOS-style layout calculation scheduling with adaptive debouncing for performance
     */
    private fun scheduleLayoutCalculation() {
        mainHandler.removeCallbacks(layoutCalculationRunnable)
        
        val debounceDelay = if (isRapidUpdateMode.get()) 16L else 100L // 16ms = 60fps, 100ms = normal
        
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

        layoutExecutor.execute {
            val displayMetrics = Resources.getSystem().displayMetrics
            val screenWidth = displayMetrics.widthPixels.toFloat()
            val screenHeight = displayMetrics.heightPixels.toFloat()

            val success = YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)

            mainHandler.post {
                needsLayoutCalculation.set(false)
                if (success) {
                    Log.d(TAG, "Layout calculation successful")
                } else {
                    Log.w(TAG, "Layout calculation deferred, rescheduling")
                    needsLayoutCalculation.set(true)
                    scheduleLayoutCalculation()
                }
            }
        }
    }

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
        
        pendingViewAttachments.values.forEach { attachment ->
            val parentView = getView(attachment.parentId)
            if (parentView is ViewGroup) {
                try {
                    if (attachment.view.parent == null) {
                        parentView.addView(attachment.view, attachment.index)
                    }
                } catch (e: Exception) {
                }
            }
        }
        
        pendingViewAttachments.clear()
        isInDelayedRenderingMode = false
    }


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
     * Apply calculated layout to a view with optional animation - MATCH iOS exactly
     */
    fun applyLayout(viewId: String, left: Float, top: Float, width: Float, height: Float, animationDuration: Long = 0): Boolean {
        val view = getView(viewId) ?: return false

        val frame = Rect(
            left.toInt(),
            top.toInt(),
            (left + max(1f, width)).toInt(),
            (top + max(1f, height)).toInt()
        )

        if (Looper.myLooper() == Looper.getMainLooper()) {
            if (animationDuration > 0) {
                applyLayoutDirectly(view, frame)
            } else {
                applyLayoutDirectly(view, frame)
            }
        } else {
            mainHandler.post {
                if (animationDuration > 0) {
                    applyLayoutDirectly(view, frame)
                } else {
                    applyLayoutDirectly(view, frame)
                }
            }
        }

        return true
    }

    /**
     * Apply layout without making view visible
     * Used for batch layout application to prevent flash
     */
    fun applyLayoutWithoutVisibility(viewId: String, left: Float, top: Float, width: Float, height: Float): Boolean {
        val view = getView(viewId) ?: return false

        val frame = Rect(
            left.toInt(),
            top.toInt(),
            (left + max(1f, width)).toInt(),
            (top + max(1f, height)).toInt()
        )

        applyLayoutDirectlyWithoutVisibility(view, frame)
        return true
    }

    private fun applyLayoutDirectly(view: View, frame: Rect) {

        if (view.parent == null && view.rootView == null) {
            return
        }

        if (!frame.width().toFloat().isFinite() || !frame.height().toFloat().isFinite() ||
            !frame.left.toFloat().isFinite() || !frame.top.toFloat().isFinite() ||
            frame.width().toFloat().isNaN() || frame.height().toFloat().isNaN() ||
            frame.left.toFloat().isNaN() || frame.top.toFloat().isNaN()) {
            return
        }

        if (frame.width() > 10000 || frame.height() > 10000 ||
            frame.width() < 0 || frame.height() < 0) {
            return
        }

        val safeFrame = Rect(
            frame.left,
            frame.top,
            frame.left + max(1, frame.width()),
            frame.top + max(1, frame.height())
        )

        if (Looper.myLooper() == Looper.getMainLooper()) {
            try {
                if (view.parent != null || view.rootView != null) {
                    val parent = view.parent
                    if (parent is DCFFrameLayout) {
                        parent.setChildManuallyPositioned(view, true)
                    }

                    val isScreen = view.tag == "DCFScreen" || view::class.simpleName?.contains("Screen") == true || view::class.simpleName?.contains("DCFEscapeVisibility") == true
                    if (!isScreen) {
                        view.visibility = View.VISIBLE
                        view.alpha = 1.0f
                    }

                    val width = safeFrame.width()
                    val height = safeFrame.height()
                    view.measure(
                        View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                        View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
                    )
                    
                    view.layout(safeFrame.left, safeFrame.top, safeFrame.right, safeFrame.bottom)

                    view.invalidate()
                    
                    (view.parent as? View)?.invalidate()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error applying layout to view", e)
            }
        } else {
            mainHandler.post {
                try {
                    if (view.parent != null || view.rootView != null) {
                        val parent = view.parent
                        if (parent is DCFFrameLayout) {
                            parent.setChildManuallyPositioned(view, true)
                        }
                        
                        val isScreen = view.tag == "DCFScreen" || view::class.simpleName?.contains("Screen") == true
                        if (!isScreen) {
                            view.visibility = View.VISIBLE
                            view.alpha = 1.0f
                        }
                        
                        val width = safeFrame.width()
                        val height = safeFrame.height()
                        view.measure(
                            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
                        )
                        
                        view.layout(safeFrame.left, safeFrame.top, safeFrame.right, safeFrame.bottom)
                        
                        view.invalidate()
                        (view.parent as? View)?.invalidate()
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Error applying layout to view", e)
                }
            }
        }
    }

    private fun applyLayoutDirectlyWithoutVisibility(view: View, frame: Rect) {

        if (view.parent == null && view.rootView == null) {
            return
        }

        if (!frame.width().toFloat().isFinite() || !frame.height().toFloat().isFinite() ||
            !frame.left.toFloat().isFinite() || !frame.top.toFloat().isFinite() ||
            frame.width().toFloat().isNaN() || frame.height().toFloat().isNaN() ||
            frame.left.toFloat().isNaN() || frame.top.toFloat().isNaN()) {
            return
        }

        if (frame.width() > 10000 || frame.height() > 10000 ||
            frame.width() < 0 || frame.height() < 0) {
            return
        }

        val safeFrame = Rect(
            frame.left,
            frame.top,
            frame.left + max(1, frame.width()),
            frame.top + max(1, frame.height())
        )

        mainHandler.post {
            try {
                if (view.parent != null || view.rootView != null) {
                    val parent = view.parent
                    if (parent is DCFFrameLayout) {
                        parent.setChildManuallyPositioned(view, true)
                    }

                    view.layout(safeFrame.left, safeFrame.top, safeFrame.right, safeFrame.bottom)


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

        val frame = Rect(left.toInt(), top.toInt(), (left + max(1f, width)).toInt(), (top + max(1f, height)).toInt())

        layoutExecutor.execute {
            pendingLayouts[viewId] = frame

            if (!isLayoutUpdateScheduled.getAndSet(true)) {
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
        check(Looper.myLooper() == Looper.getMainLooper()) { "applyPendingLayouts must be called on the main thread" }

        isLayoutUpdateScheduled.set(false)

        val layoutsToApply = mutableMapOf<String, Rect>()

        layoutExecutor.execute {
            layoutsToApply.putAll(pendingLayouts)
            pendingLayouts.clear()

            mainHandler.post {
                if (animationDuration > 0) {
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


    /**
     * Register view with layout system - MATCH iOS exactly
     */
    fun registerView(view: View, nodeId: String, componentType: String, componentInstance: DCFComponent) {
        registerView(view, nodeId)

        componentInstance.viewRegisteredWithShadowTree(view, nodeId)

        if (nodeId == "root") {
            triggerLayoutCalculation()
        }
    }

    /**
     * Add a child node to a parent in the layout tree with safe coordination
     */
    fun addChildNode(parentId: String, childId: String, index: Int) {
        YogaShadowTree.shared.addChildNode(parentId, childId, index)

        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Remove a node from the layout tree with safe coordination
     */
    fun removeNode(nodeId: String) {
        YogaShadowTree.shared.removeNode(nodeId)

        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Update a node's layout properties
     */
    fun updateNodeWithLayoutProps(nodeId: String, componentType: String, props: Map<String, Any>) {
        YogaShadowTree.shared.updateNodeLayoutProps(nodeId, props)

        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Manually trigger layout calculation (useful for initial layout or when needed)
     */
    fun triggerLayoutCalculation() {
        needsLayoutCalculation.set(true)
        
        val currentTime = System.currentTimeMillis()
        val lastUpdateTime = rapidUpdateTimer.getAndSet(currentTime)
        
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

            val success = YogaShadowTree.shared.calculateAndApplyLayout(screenWidth, screenHeight)

            mainHandler.post {
            }
        }
    }

    fun invalidateAllLayouts() {
        pendingLayouts.clear()
        
        needsLayoutCalculation.set(true)
        
        triggerLayoutCalculation()
    }

    /**
     * HOT RESTART FIX: Ensure all views start invisible during hot restart
     * This prevents flash during hot restart by making all views invisible initially
     */
    fun prepareForHotRestart() {
        // 🔥 CRITICAL: Cancel all pending layout calculations FIRST
        // This prevents stale layout calculations from firing after cleanup
        cancelAllPendingLayoutWork()
        
        for ((_, view) in viewRegistry) {
            view.visibility = View.INVISIBLE
            view.alpha = 0f
        }
        Log.d(TAG, "Prepared ${viewRegistry.size} views for hot restart")
    }
    
    /**
     * FLASH SCREEN FIX: Make all views visible after batch operations
     * This ensures text and other components are visible after batch creation
     */
    fun makeAllViewsVisible() {
        for ((_, view) in viewRegistry) {
            view.visibility = View.VISIBLE
            view.alpha = 1.0f
        }
        Log.d(TAG, "Made ${viewRegistry.size} views visible after batch operations")
    }
    
    /**
     * SLIDER PERFORMANCE FIX: Optimize layout application during rapid updates
     * This prevents the flash issue during slider drag by batching layout updates
     */
    fun optimizeForRapidUpdates() {
        if (isRapidUpdateMode.get()) {
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
        isRapidUpdateMode.set(true)
        rapidUpdateTimer.set(System.currentTimeMillis())
        
        triggerLayoutCalculation()
    }
    
    /**
     * ROTATION FIX: Handle device rotation by forcing text remeasurement
     * This ensures text remains visible after rotation
     */
    fun handleDeviceRotation() {
        Log.d(TAG, "🔄 Handling device rotation - clean invalidation like iOS")
        
        for ((viewId, view) in viewRegistry) {
            view.requestLayout()
            view.invalidate()
            
            if (view is ViewGroup) {
                for (i in 0 until view.childCount) {
                    val child = view.getChildAt(i)
                    child.requestLayout()
                    child.invalidate()
                }
            }
        }
        
        triggerLayoutCalculation()
        
        Log.d(TAG, "🔄 Device rotation handling completed for ${viewRegistry.size} views")
    }
    
    /**
     * Cancel all pending layout calculations (for hot restart)
     * This prevents stale layout calculations from firing after cleanup
     */
    fun cancelAllPendingLayoutWork() {
        Log.d(TAG, "🧹 DCFLayoutManager: Cancelling all pending layout work")
        
        // Cancel Handler callbacks
        mainHandler.removeCallbacks(layoutCalculationRunnable)
        
        // Cancel ScheduledExecutorService tasks
        layoutCalculationTimer?.shutdownNow()
        layoutCalculationTimer = null
        
        // Reset flags
        needsLayoutCalculation.set(false)
        isLayoutUpdateScheduled.set(false)
        
        // Clear pending layouts
        pendingLayouts.clear()
        
        Log.d(TAG, "✅ DCFLayoutManager: All pending layout work cancelled")
    }
    
    /**
     * Prepare for hot restart - cancels all pending work
     * Called before cleanup to prevent stale operations
     */
    fun prepareForHotRestart() {
        cancelAllPendingLayoutWork()
    }
    
}

