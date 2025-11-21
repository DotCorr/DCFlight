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
import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcflight.components.DCFFrameLayout
import com.dotcorr.dcflight.components.DCFNodeLayout
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.DCFComposeWrapper
import com.dotcorr.dcflight.layout.ViewRegistry
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
        private const val DEFAULT_LAYOUT_ANIMATION_DURATION = 300L // milliseconds

        @JvmField
        val shared = DCFLayoutManager()
    }

    private val absoluteLayoutViews = mutableSetOf<View>()

    internal val viewRegistry = ConcurrentHashMap<Int, View>()

    private val pendingLayouts = ConcurrentHashMap<Int, Rect>()
    private val isLayoutUpdateScheduled = AtomicBoolean(false)
    
    // Layout animation configuration
    var layoutAnimationEnabled = false
    var layoutAnimationDuration = DEFAULT_LAYOUT_ANIMATION_DURATION
    var layoutAnimationInterpolator: android.view.animation.Interpolator = 
        android.view.animation.AccelerateDecelerateInterpolator()

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
     * Performs automatic layout calculation with reconciliation coordination.
     * 
     * Executes layout calculation on a background thread and updates the UI on the main thread.
     * Reschedules if the calculation is deferred.
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

    private val pendingViewAttachments = mutableMapOf<Int, PendingAttachment>()
    private var isInDelayedRenderingMode = false
    
    data class PendingAttachment(
        val view: View,
        val parentId: Int,
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
     * Registers a view with the layout manager.
     * 
     * @param view The view to register
     * @param viewId Unique identifier for the view
     */
    fun registerView(view: View, viewId: Int) {
        viewRegistry[viewId] = view
    }

    /**
     * Unregisters a view from the layout manager.
     * 
     * Also removes it from the absolute layout views set if it was using absolute layout.
     * 
     * @param viewId Unique identifier for the view to unregister
     */
    fun unregisterView(viewId: Int) {
        val view = viewRegistry.remove(viewId)
        view?.let {
            absoluteLayoutViews.remove(it)
        }
    }

    /**
     * Get view by ID
     */
    fun getView(viewId: Int): View? = viewRegistry[viewId]


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
    fun cleanUp(viewId: Int) {
        val view = viewRegistry[viewId]
        view?.let {
            absoluteLayoutViews.remove(it)
        }
        viewRegistry.remove(viewId)
    }


    /**
     * Apply calculated layout to a view with optional animation - MATCH iOS exactly
     * Now uses component.applyLayout() instead of direct view manipulation
     */
    fun applyLayout(viewId: Int, left: Float, top: Float, width: Float, height: Float, animationDuration: Long = 0): Boolean {
        val view = getView(viewId) ?: return false

        val layout = DCFNodeLayout(
            left,
            top,
            max(1f, width),
            max(1f, height)
        )

        if (Looper.myLooper() == Looper.getMainLooper()) {
            applyLayoutDirectly(viewId, view, layout, animationDuration)
        } else {
            mainHandler.post {
                applyLayoutDirectly(viewId, view, layout, animationDuration)
            }
        }

        return true
    }

    /**
     * Apply layout without making view visible
     * Used for batch layout application to prevent flash
     */
    fun applyLayoutWithoutVisibility(viewId: Int, left: Float, top: Float, width: Float, height: Float): Boolean {
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

    /**
     * Apply layout using component.applyLayout() - MATCH iOS architecture
     * This removes "glue code" and lets components handle their own layout/transforms
     * 
     * Supports layout animations when animationDuration > 0
     */
    private fun applyLayoutDirectly(viewId: Int, view: View, layout: DCFNodeLayout, animationDuration: Long) {
        if (view.parent == null && view.rootView == null) {
            return
        }

        // Validate layout values
        if (!layout.width.isFinite() || !layout.height.isFinite() ||
            !layout.left.isFinite() || !layout.top.isFinite() ||
            layout.width.isNaN() || layout.height.isNaN() ||
            layout.left.isNaN() || layout.top.isNaN()) {
            return
        }

        if (layout.width > 10000 || layout.height > 10000 ||
            layout.width < 0 || layout.height < 0) {
            return
        }

            try {
                if (view.parent != null || view.rootView != null) {
                    val parent = view.parent
                    if (parent is DCFFrameLayout) {
                        parent.setChildManuallyPositioned(view, true)
                    }

                // Measure view first (framework controls measurement)
                    view.measure(
                    View.MeasureSpec.makeMeasureSpec(layout.width.toInt(), View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(layout.height.toInt(), View.MeasureSpec.EXACTLY)
                    )
                    
                // Get component type and instance
                val componentType = ViewRegistry.shared.getViewType(viewId) 
                    ?: view.getTag(DCFTags.COMPONENT_TYPE_KEY) as? String
                    ?: "View"
                
                val componentClass = DCFComponentRegistry.shared.getComponentType(componentType)
                
                // Apply layout with animation if duration > 0 and layout animations are enabled
                val shouldAnimate = animationDuration > 0 && layoutAnimationEnabled
                
                if (shouldAnimate) {
                    // Store current layout for animation
                    val currentLeft = view.left.toFloat()
                    val currentTop = view.top.toFloat()
                    val currentWidth = view.width.toFloat()
                    val currentHeight = view.height.toFloat()
                    
                    val targetLeft = layout.left
                    val targetTop = layout.top
                    val targetWidth = layout.width
                    val targetHeight = layout.height
                    
                    // Calculate translation needed (difference between current and target)
                    val deltaX = targetLeft - currentLeft
                    val deltaY = targetTop - currentTop
                    val deltaWidth = targetWidth - currentWidth
                    val deltaHeight = targetHeight - currentHeight
                    
                    // Set initial translation to current position
                    view.translationX = 0f
                    view.translationY = 0f
                    
                    // Apply target size immediately (size changes are instant for layout)
                    if (componentClass != null) {
                        val componentInstance = componentClass.getDeclaredConstructor().newInstance()
                        val sizeLayout = DCFNodeLayout(currentLeft, currentTop, targetWidth, targetHeight)
                        componentInstance.applyLayout(view, sizeLayout)
                    } else {
                        view.layout(
                            currentLeft.toInt(),
                            currentTop.toInt(),
                            (currentLeft + targetWidth).toInt(),
                            (currentTop + targetHeight).toInt()
                        )
                    }
                    
                    // Animate translation to target position
                    view.animate()
                        .translationX(deltaX)
                        .translationY(deltaY)
                        .setDuration(animationDuration)
                        .setInterpolator(layoutAnimationInterpolator)
                        .withEndAction {
                            // Final layout at target position, reset translation
                            view.translationX = 0f
                            view.translationY = 0f
                            
                            if (componentClass != null) {
                                val componentInstance = componentClass.getDeclaredConstructor().newInstance()
                                componentInstance.applyLayout(view, layout)
                            } else {
                                view.layout(
                                    layout.left.toInt(),
                                    layout.top.toInt(),
                                    (layout.left + layout.width).toInt(),
                                    (layout.top + layout.height).toInt()
                                )
                            }
                        }
                        .start()
                } else {
                    // No animation - apply layout directly
                    if (componentClass != null) {
                        // Framework controls everything - components just set frame
                        // No props needed - framework handles all lifecycle and state
                        val componentInstance = componentClass.getDeclaredConstructor().newInstance()
                        componentInstance.applyLayout(view, layout)
                    } else {
                        // Fallback to direct layout if component not found
                        view.layout(
                            layout.left.toInt(),
                            layout.top.toInt(),
                            (layout.left + layout.width).toInt(),
                            (layout.top + layout.height).toInt()
                        )
                    }
                }

                // CRITICAL FIX: Don't make visible here - batch visibility after ALL layouts are applied
                // This prevents flash during reconciliation (views flash when visible but not yet laid out)
                // Visibility will be set in batch after all layouts complete

                // Framework handles invalidation - components don't need to know
                        view.invalidate()
                        (view.parent as? View)?.invalidate()
                    }
                } catch (e: Exception) {
            Log.w(TAG, "Error applying layout to view $viewId", e)
            // Fallback to direct layout on error
            try {
                view.layout(
                    layout.left.toInt(),
                    layout.top.toInt(),
                    (layout.left + layout.width).toInt(),
                    (layout.top + layout.height).toInt()
                )
            } catch (e2: Exception) {
                Log.e(TAG, "Fallback layout also failed", e2)
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
    fun queueLayoutUpdate(viewId: Int, left: Float, top: Float, width: Float, height: Float): Boolean {
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

        val layoutsToApply = mutableMapOf<Int, Rect>()

        layoutExecutor.execute {
            layoutsToApply.putAll(pendingLayouts)
            pendingLayouts.clear()

            mainHandler.post {
                if (animationDuration > 0) {
                    for ((viewId, frame) in layoutsToApply) {
                        getView(viewId)?.let { view ->
                            val layout = DCFNodeLayout(
                                frame.left.toFloat(),
                                frame.top.toFloat(),
                                frame.width().toFloat(),
                                frame.height().toFloat()
                            )
                            applyLayoutDirectly(viewId, view, layout, animationDuration)
                        }
                    }
                } else {
                    for ((viewId, frame) in layoutsToApply) {
                        getView(viewId)?.let { view ->
                            val layout = DCFNodeLayout(
                                frame.left.toFloat(),
                                frame.top.toFloat(),
                                frame.width().toFloat(),
                                frame.height().toFloat()
                            )
                            applyLayoutDirectly(viewId, view, layout, 0)
                        }
                    }
                }
            }
        }
    }


    /**
     * Registers a view with the layout system and notifies the component instance.
     * 
     * Matches iOS behavior exactly. If the node is the root node, triggers an immediate layout calculation.
     * 
     * @param view The view to register
     * @param nodeId Unique identifier for the node
     * @param componentType Type of component (e.g., "View", "Text")
     * @param componentInstance The component instance to notify
     */
    fun registerView(view: View, nodeId: String, componentType: String, componentInstance: DCFComponent) {
        val nodeIdInt = nodeId.toIntOrNull() ?: return
        registerView(view, nodeIdInt)

        Log.d(TAG, "🎨 registerView: Calling viewRegisteredWithShadowTree for nodeId: $nodeId, componentType: $componentType")
        componentInstance.viewRegisteredWithShadowTree(view, nodeId)

        if (nodeIdInt == 0) {
            triggerLayoutCalculation()
        }
    }

    /**
     * Adds a child node to a parent in the layout tree.
     * 
     * Updates the YogaShadowTree and schedules a layout calculation.
     * 
     * @param parentId Unique identifier for the parent node
     * @param childId Unique identifier for the child node
     * @param index Position in the parent's child list
     */
    fun addChildNode(parentId: Int, childId: Int, index: Int) {
        YogaShadowTree.shared.addChildNode(parentId, childId, index)

        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Removes a node from the layout tree.
     * 
     * Updates the YogaShadowTree and schedules a layout calculation.
     * 
     * @param nodeId Unique identifier for the node to remove
     */
    fun removeNode(nodeId: String) {
        YogaShadowTree.shared.removeNode(nodeId)

        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Updates a node's layout properties.
     * 
     * Applies the properties to the YogaShadowTree node and schedules a layout calculation.
     * 
     * @param nodeId Unique identifier for the node
     * @param componentType Type of component (for reference)
     * @param props Map of layout properties to apply
     */
    fun updateNodeWithLayoutProps(nodeId: String, componentType: String, props: Map<String, Any>) {
        YogaShadowTree.shared.updateNodeLayoutProps(nodeId, props)

        needsLayoutCalculation.set(true)
        scheduleLayoutCalculation()
    }

    /**
     * Manually triggers a layout calculation.
     * 
     * Detects rapid updates and adjusts debouncing accordingly. Useful for initial layout
     * or when layout needs to be recalculated outside of normal update cycles.
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
     * Forces an immediate synchronous layout calculation.
     * 
     * Executes layout calculation immediately on a background thread, bypassing
     * the normal debounced scheduling. Used when immediate layout is required.
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
     * Prepares all views for hot restart by making them invisible.
     * 
     * Cancels all pending layout calculations first to prevent stale calculations
     * from firing after cleanup. This prevents flash during hot restart.
     */
    fun prepareForHotRestart() {
        // Cancel all pending layout calculations first to prevent stale calculations
        cancelAllPendingLayoutWork()
        
        for ((_, view) in viewRegistry) {
            view.visibility = View.INVISIBLE
            view.alpha = 0f
        }
    }
    
    /**
     * Makes all views visible after batch operations.
     * 
     * Ensures text and other components are visible after batch creation.
     */
    fun makeAllViewsVisible() {
        for ((_, view) in viewRegistry) {
            view.visibility = View.VISIBLE
            view.alpha = 1.0f
        }
    }
    
    /**
     * Optimizes layout application during rapid updates.
     * 
     * Prevents flash issues during slider drag by batching layout updates.
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
     * Handles slider updates to prevent flash during rapid value changes.
     * 
     * Called specifically when slider values change rapidly to optimize layout performance.
     */
    fun handleSliderUpdate() {
        isRapidUpdateMode.set(true)
        rapidUpdateTimer.set(System.currentTimeMillis())
        
        triggerLayoutCalculation()
    }
    
    /**
     * Handles device rotation by forcing text remeasurement.
     * 
     * Invalidates all views and their children to ensure text remains visible after rotation.
     */
    fun handleDeviceRotation() {
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
    }
    
    /**
     * Cancels all pending layout calculations.
     * 
     * Used during hot restart to prevent stale layout calculations from firing after cleanup.
     * Cancels Handler callbacks, ScheduledExecutorService tasks, and clears pending layouts.
     */
    fun cancelAllPendingLayoutWork() {
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
    }
    
}

