/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_reanimated.components

import android.content.Context
import android.graphics.PointF
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Choreographer
import android.view.View
import android.widget.FrameLayout
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFLayoutIndependent
import com.dotcorr.dcflight.components.DCFNodeLayout
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.worklet.WorkletInterpreter
import java.util.concurrent.TimeUnit

/**
 * Reanimated View Component with worklet support for Android
 * 
 * Provides pure UI thread animation execution using Choreographer
 * for 60fps performance with zero bridge calls during animation.
 */
class DCFAnimatedViewComponent : DCFComponent() {

    companion object {
        private const val TAG = "DCFAnimatedView"
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        // Debug: Print all props to see what we're receiving
        Log.d(TAG, "🔍 REANIMATED: createView called with props keys: ${props.keys}")
        Log.d(TAG, "🔍 REANIMATED: isPureReanimated = ${props["isPureReanimated"]}")
        Log.d(TAG, "🔍 REANIMATED: worklet = ${if (props["worklet"] != null) "exists" else "nil"}")
        Log.d(TAG, "🔍 REANIMATED: workletConfig = ${if (props["workletConfig"] != null) "exists" else "nil"}")
        
        val reanimatedView = PureReanimatedView(context)
        
        reanimatedView.setTag(DCFTags.COMPONENT_TYPE_KEY, "ReanimatedView")
        
        // Configure worklet or animation from props
        if (props["isPureReanimated"] == true) {
            Log.d(TAG, "🎯 PURE REANIMATED: Creating view with pure UI thread configuration")
            
            // Configure worklet if provided (takes precedence)
            if (props["worklet"] is Map<*, *>) {
                val workletData = props["worklet"] as Map<String, Any?>
                val workletConfig = props["workletConfig"] as? Map<String, Any?>
                reanimatedView.configureWorklet(workletData, workletConfig)
            } else if (props["animatedStyle"] is Map<*, *>) {
                // Fall back to animated style
                val animatedStyle = props["animatedStyle"] as Map<String, Any?>
                reanimatedView.configurePureAnimation(animatedStyle)
            }
            
            // Auto-start if configured (default: true for AnimatedText, false for ReanimatedView)
            val autoStart = props["autoStart"] as? Boolean ?: true
            val startDelay = props["startDelay"] as? Int ?: 0
            
            if (autoStart) {
                if (startDelay > 0) {
                    reanimatedView.postDelayed({
                        reanimatedView.startPureAnimation()
                    }, startDelay.toLong())
                } else {
                    reanimatedView.startPureAnimation()
                }
            }
        }
        
        updateView(reanimatedView, props)
        
        return reanimatedView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val reanimatedView = view as? PureReanimatedView ?: return false
        
        // CRITICAL: Merge new props with existing stored props
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        // Check if autoStart changed
        val previousAutoStart = existingProps["autoStart"] as? Boolean ?: false
        val currentAutoStart = mergedProps["autoStart"] as? Boolean ?: false
        
        // 🔥 LIFECYCLE FIX: If worklet prop is removed (component replaced with non-worklet),
        // stop the old worklet animation immediately
        val hadWorklet = reanimatedView.isUsingWorklet
        val hasWorklet = mergedProps["worklet"] is Map<*, *>
        
        if (hadWorklet && !hasWorklet) {
            // Worklet was removed - stop animation immediately
            Log.d(TAG, "🛑 WORKLET: Worklet prop removed, stopping old animation")
            reanimatedView.stopPureAnimation()
            reanimatedView.workletConfig = null
            reanimatedView.isUsingWorklet = false
        }
        
        // Update worklet or animation style
        if (mergedProps["worklet"] is Map<*, *>) {
            val workletData = mergedProps["worklet"] as Map<String, Any?>
            val workletConfig = mergedProps["workletConfig"] as? Map<String, Any?>
            reanimatedView.updateWorklet(workletData, workletConfig)
        } else if (mergedProps["animatedStyle"] is Map<*, *>) {
            val animatedStyle = mergedProps["animatedStyle"] as Map<String, Any?>
            reanimatedView.updateAnimationConfig(animatedStyle)
        }
        
        // CRITICAL: Handle autoStart prop changes
        // If autoStart changed from false to true, start the animation
        // If autoStart changed from true to false, stop the animation
        if (currentAutoStart != previousAutoStart) {
            if (currentAutoStart && !reanimatedView.isAnimating) {
                Log.d(TAG, "🎯 PURE REANIMATED: autoStart changed to true, starting animation")
                reanimatedView.startPureAnimation()
            } else if (!currentAutoStart && reanimatedView.isAnimating) {
                Log.d(TAG, "🎯 PURE REANIMATED: autoStart changed to false, stopping animation")
                reanimatedView.stopPureAnimation()
            }
        }
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        reanimatedView.applyStyles(nonNullProps)
        
        return true
    }

    override fun applyLayout(view: View, layout: DCFNodeLayout) {
        val reanimatedView = view as? PureReanimatedView
        if (reanimatedView == null) {
            // For non-reanimated views, use default layout
            super.applyLayout(view, layout)
            return
        }
        
        // CRITICAL: For ReanimatedView, skip layout updates during state changes to prevent stuttering
        // Layout updates interfere with transform animations by recalculating anchor points
        // Only update if size actually changed significantly (more than 5 pixels)
        // NOTE: shouldSkipLayout is checked in YogaShadowTree.applyLayoutToView (framework layer)
        // This matches iOS behavior where the check is only in YogaShadowTree, not in component.applyLayout
        val newFrame = android.graphics.RectF(
            layout.left,
            layout.top,
            layout.left + layout.width,
            layout.top + layout.height
        )
        
        // Check if size changed significantly
        val sizeChanged = Math.abs(newFrame.width() - reanimatedView.width) > 5.0f ||
                         Math.abs(newFrame.height() - reanimatedView.height) > 5.0f
        
        // If size hasn't changed significantly, skip layout update entirely
        // This prevents stuttering caused by frame updates interfering with transforms
        if (!sizeChanged) {
            return
        }
        
        // CRITICAL: Always ensure pivot point is at center for proper transform behavior
        // This prevents content from appearing off-center when transforms are active
        if (reanimatedView.pivotX != reanimatedView.width / 2f || 
            reanimatedView.pivotY != reanimatedView.height / 2f) {
            reanimatedView.pivotX = reanimatedView.width / 2f
            reanimatedView.pivotY = reanimatedView.height / 2f
        }
        
        // Always use layout() to set position and size (preserves transforms)
        reanimatedView.layout(
            newFrame.left.toInt(),
            newFrame.top.toInt(),
            newFrame.right.toInt(),
            newFrame.bottom.toInt()
        )
    }

    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
        val reanimatedView = view as? PureReanimatedView ?: return
        reanimatedView.nodeId = nodeId
        Log.d(TAG, "ReanimatedView registered with shadow tree: $nodeId")
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        // 🔥 UI FREEZE FIX: Universal pause/resume for ALL UI thread work
        when (method) {
            "pauseAllUIWork" -> {
                PureReanimatedView.pauseAllUIWork()
                return true
            }
            "resumeAllUIWork" -> {
                PureReanimatedView.resumeAllUIWork()
                return true
            }
        }
        return null
    }
}

/**
 * Pure Reanimated View that runs animations entirely on UI thread
 * 
 * Uses Choreographer for 60fps frame updates with zero bridge calls.
 */
class PureReanimatedView(context: Context) : FrameLayout(context), DCFLayoutIndependent {
    
    companion object {
        private const val TAG = "PureReanimatedView"
        
        // 🔥 UI FREEZE FIX: Global pause state for ALL UI thread work
        // Universal solution - pauses ALL frame callbacks during rapid reconciliation
        private var globalPauseState = false
        
        // Check if globally paused (prevents any animation/worklet from starting)
        fun isGloballyPaused(): Boolean = globalPauseState
        
        // Pause ALL UI thread work globally (universal solution)
        fun pauseAllUIWork() {
            globalPauseState = true
            Log.d(TAG, "🛑 GLOBAL_PAUSE: Pausing ALL UI thread work (frame callbacks, etc.)")
            // 🔥 AGGRESSIVE: Force stop all frame callbacks immediately
            // This prevents any frame callbacks from running during rapid reconciliation
        }
        
        // Resume ALL UI thread work
        fun resumeAllUIWork() {
            globalPauseState = false
            Log.d(TAG, "▶️ GLOBAL_RESUME: Resuming UI thread work")
        }
    }
    
    // Choreographer for 60fps rendering
    private val choreographer = Choreographer.getInstance()
    private var frameCallback: Choreographer.FrameCallback? = null
    var isAnimating = false
    private var animationStartTime = 0L
    
    // MARK: - DCFLayoutIndependent Interface
    
    /**
     * Opt-out of layout updates when animating to prevent stuttering
     * This makes the view layout-independent during animation
     */
    override val shouldSkipLayout: Boolean
        get() = isAnimating
    
    // Animation configuration
    private var animationConfig: Map<String, Any?> = emptyMap()
    private var currentAnimations = mutableMapOf<String, PureAnimationState>()
    
    // Worklet configuration
    internal var workletConfig: Map<String, Any?>? = null
    private var workletExecutionConfig: Map<String, Any?>? = null
    internal var isUsingWorklet = false
    
    // 🔥 PERFORMANCE: Cache WorkletViewProxy directly (not just viewId) to avoid ANY lookups per frame
    // This is the real fix - native animations don't do lookups, they just update properties
    private var cachedWorkletProxy: com.dotcorr.dcflight.worklet.WorkletViewProxy? = null
    private var cachedTargetView: android.view.View? = null
    
    // Identifiers for callbacks
    var nodeId: String? = null
    
    // ============================================================================
    // WORKLET CONFIGURATION - UI THREAD EXECUTION
    // ============================================================================
    
    fun configureWorklet(workletData: Map<String, Any?>, config: Map<String, Any?>?) {
        Log.d(TAG, "🔧 WORKLET: Configuring worklet for pure UI thread execution")
        
        // Debug: Log full worklet structure
        Log.d(TAG, "🔍 WORKLET: configureWorklet - workletData keys: ${workletData.keys}")
        
        // Check if worklet is compiled
        val functionData = workletData["function"] as? Map<*, *>
        Log.d(TAG, "🔍 WORKLET: configureWorklet - functionData keys: ${functionData?.keys}")
        
        val isCompiled = workletData["isCompiled"] as? Boolean ?: false
        val workletType = functionData?.get("type") as? String ?: "dart_function"
        
        // Check if worklet has IR for runtime interpretation
        val ir = functionData?.get("ir")
        Log.d(TAG, "🔍 WORKLET: configureWorklet - ir type: ${ir?.javaClass?.name}, ir: $ir")
        
        if (ir != null || workletType == "interpretable") {
            val workletId = functionData?.get("workletId") as? String
            Log.d(TAG, "✅ WORKLET: Interpretable worklet detected! workletId=$workletId")
            Log.d(TAG, "📝 WORKLET: IR available for runtime interpretation (no rebuild needed!)")
        } else {
            Log.w(TAG, "⚠️ WORKLET: No IR found in configureWorklet - workletType=$workletType, ir=$ir")
        }
        
        this.workletConfig = workletData
        this.workletExecutionConfig = config
        this.isUsingWorklet = true
        
        // Clear animation config when using worklet
        currentAnimations.clear()
    }
    
    fun updateWorklet(workletData: Map<String, Any?>, config: Map<String, Any?>?) {
        // 🔥 LIFECYCLE FIX: UI thread worklets must be fully stopped before new ones start
        // Since worklets run on native UI thread (not Dart), they don't auto-cleanup when Dart components are replaced
        // We must explicitly stop the old worklet's frame callback and clear its state
        
        // CRITICAL: Always stop old worklet FIRST if it exists
        // This prevents orphaned frame callbacks from running after component replacement
        if (workletConfig != null) {
            // CRITICAL: Stop frame callback IMMEDIATELY and synchronously
            // This removes the callback so no more frames can execute
            isAnimating = false
            stopFrameCallback()
            
            // CRITICAL: Clear worklet config to prevent old worklet from being executed
            // This ensures the frame callback (if it somehow still fires) won't execute old worklet
            workletConfig = null
            isUsingWorklet = false
        }
        
        // 🔥 PERFORMANCE: Clear proxy cache when worklet changes (view hierarchy might have changed)
        cachedWorkletProxy = null
        cachedTargetView = null
        
        // Configure new worklet (this sets new workletConfig)
        configureWorklet(workletData, config)
        
        // Start new worklet on next frame to ensure old frame callback is fully removed
        Handler(Looper.getMainLooper()).post {
            // Final safety check - ensure old animation is stopped
            if (isAnimating && frameCallback != null) {
                Log.w(TAG, "⚠️ WORKLET: Old animation still running, force stopping")
                isAnimating = false
                stopFrameCallback()
            }
            // Start new worklet
            startPureAnimation()
        }
    }
    
    // ============================================================================
    // PURE ANIMATION CONFIGURATION
    // ============================================================================
    
    fun configurePureAnimation(animatedStyle: Map<String, Any?>) {
        Log.d(TAG, "🎯 PURE REANIMATED: Configuring animation from props")
        this.animationConfig = animatedStyle
        this.isUsingWorklet = false
        
        // Parse perspective if provided
        if (animatedStyle["perspective"] is Number) {
            val perspective = (animatedStyle["perspective"] as Number).toFloat()
            // Set camera distance for 3D perspective effect
            cameraDistance = perspective
        }
        
        // Parse animation configurations
        currentAnimations.clear()
        
        // Handle animations dictionary
        val animations = animatedStyle["animations"] as? Map<*, *>
        if (animations != null) {
            for ((property, config) in animations) {
                if (config is Map<*, *>) {
                    currentAnimations[property as String] = PureAnimationState(
                        property = property as String,
                        config = config as Map<String, Any?>,
                        view = this
                    )
                }
            }
        } else {
            // Legacy format: animations at top level
            for ((property, config) in animatedStyle) {
                if (property != "perspective" && property != "preserve3d" && config is Map<*, *>) {
                    currentAnimations[property] = PureAnimationState(
                        property = property,
                        config = config as Map<String, Any?>,
                        view = this
                    )
                }
            }
        }
    }
    
    fun updateAnimationConfig(animatedStyle: Map<String, Any?>) {
        val wasAnimating = isAnimating
        stopPureAnimation()
        configurePureAnimation(animatedStyle)
        // Only restart animation if it was already running
        // This prevents auto-starting on prop updates
        if (wasAnimating) {
            startPureAnimation()
        }
    }
    
    // ============================================================================
    // ANIMATION CONTROL
    // ============================================================================
    
    fun startPureAnimation() {
        // 🔥 UI FREEZE FIX: Don't start if globally paused (universal solution)
        if (isGloballyPaused()) {
            Log.d(TAG, "⏸️ PURE REANIMATED: Animation start blocked - UI work globally paused")
            return
        }
        
        if (isAnimating) return
        
        if (isUsingWorklet) {
            // For worklets, we need workletConfig (the serialized function) to exist
            // workletExecutionConfig (the parameters) is optional
            if (workletConfig == null) {
                Log.w(TAG, "⚠️ PURE REANIMATED: No worklet configured")
                return
            }
            // Text worklets run continuously (no duration), so we always start
            Log.d(TAG, "🚀 PURE REANIMATED: Starting worklet animation (workletConfig exists)")
        } else if (currentAnimations.isEmpty()) {
            Log.w(TAG, "⚠️ PURE REANIMATED: No animations configured")
            return
        }

        // CRITICAL: Apply initial values BEFORE starting animation
        // This ensures the view starts in the correct state
        if (!isUsingWorklet) {
            for ((_, animationState) in currentAnimations) {
                // Apply initial value immediately (before animation starts)
                animationState.applyInitialValue()
            }
        }

        Log.d(TAG, "🚀 PURE REANIMATED: Starting pure UI thread animation")
        
        // 🔥 CRITICAL: Set pivot points BEFORE animation starts to prevent "walking" or "eclipse" effects
        // This ensures transforms are applied from the center of the view
        if (width > 0 && height > 0) {
            pivotX = width / 2f
            pivotY = height / 2f
        }
        
        // 🔥 CRITICAL: Also set pivot points for all children to prevent text from moving
        // This is especially important for text views inside the animated container
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (child.width > 0 && child.height > 0) {
                child.pivotX = child.width / 2f
                child.pivotY = child.height / 2f
            }
        }
        
        isAnimating = true
        animationStartTime = System.nanoTime()
        
        // Fire animation start event
        fireAnimationEvent("onAnimationStart")
        
        // Start frame callback
        startFrameCallback()
    }
    
    fun stopPureAnimation() {
        if (!isAnimating) return
        
        Log.d(TAG, "🛑 PURE REANIMATED: Stopping pure UI thread animation")
        
        isAnimating = false
        stopFrameCallback()
        
        // CRITICAL: When animation stops, ensure layout is synchronized
        // If there's an active transform, we need to ensure the view's frame
        // accounts for it to prevent off-center content
        synchronizeLayoutAfterAnimation()
        
        // Fire animation complete event
        fireAnimationEvent("onAnimationComplete")
    }
    
    /**
     * Synchronize layout after animation stops to prevent off-center content
     */
    private fun synchronizeLayoutAfterAnimation() {
        // 🔥 CRITICAL: When animation stops, ensure pivot point is at center
        // This prevents content from appearing off-center when transforms are active
        // The pivot point determines where transforms are applied from
        if (width > 0 && height > 0) {
            pivotX = width / 2f
            pivotY = height / 2f
        }
        
        // 🔥 CRITICAL: Also reset pivot points for children
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (child.width > 0 && child.height > 0) {
                child.pivotX = child.width / 2f
                child.pivotY = child.height / 2f
            }
        }
    }
    
    // ============================================================================
    // FRAME CALLBACK - UI THREAD EXECUTION
    // ============================================================================
    
    private fun startFrameCallback() {
        if (frameCallback != null) return
        
        // CRITICAL: Create callback and store reference before posting
        // This ensures we have a valid reference even if stopFrameCallback() sets frameCallback to null
        val callback = Choreographer.FrameCallback { frameTimeNanos ->
            // 🔥 UI FREEZE FIX: Check pause flag FIRST before any work (universal solution)
            // This prevents any CPU consumption during rapid reconciliation
            if (isGloballyPaused()) {
                // Immediately stop and don't schedule next frame
                isAnimating = false
                stopFrameCallback()
                return@FrameCallback
            }
            
            if (!isAnimating) {
                stopFrameCallback()
                return@FrameCallback
            }
            
            // 🔥 LIFECYCLE FIX: Guard against orphaned worklet callbacks
            // Since worklets run on native UI thread, frame callbacks can fire even after
            // component is replaced. Check if workletConfig is still valid before executing.
            if (isUsingWorklet && workletConfig == null) {
                // Worklet was cleared (component replaced) but frame callback still fired
                Log.w(TAG, "🛑 WORKLET: Orphaned callback detected - worklet cleared, stopping")
                isAnimating = false
                stopFrameCallback()
                return@FrameCallback
            }
            
            // 🔥 LIFECYCLE FIX: Check if view is still in hierarchy
            // If view was removed from parent (deleted/replaced), stop worklet immediately
            if (parent == null) {
                Log.w(TAG, "🛑 WORKLET: View removed from hierarchy, stopping orphaned worklet")
                isAnimating = false
                workletConfig = null
                isUsingWorklet = false
                stopFrameCallback()
                return@FrameCallback
            }
            
            val currentTime = TimeUnit.NANOSECONDS.toMillis(frameTimeNanos)
            val elapsed = TimeUnit.NANOSECONDS.toMillis(frameTimeNanos - animationStartTime)
            val elapsedSeconds = elapsed / 1000.0
            
            // Execute worklet if configured
            if (isUsingWorklet && workletConfig != null) {
                executeWorklet(elapsedSeconds, workletConfig!!)
            } else {
                // Execute traditional animations
                updateAnimations(currentTime, elapsedSeconds)
            }
            
            // Schedule next frame using instance variable with null check
            // CRITICAL: Check frameCallback is not null before using it (could be null if stopFrameCallback was called)
            frameCallback?.let { choreographer.postFrameCallback(it) }
        }
        
        // Store callback in instance variable
        frameCallback = callback
        
        // Post initial frame callback
        choreographer.postFrameCallback(callback)
    }
    
    private fun stopFrameCallback() {
        frameCallback?.let {
            choreographer.removeFrameCallback(it)
            frameCallback = null
        }
    }
    
    private var lastRepeatEventTime = 0L
    private val REPEAT_EVENT_THROTTLE_MS = 100L // Throttle repeat events to once per 100ms
    
    private fun updateAnimations(currentTime: Long, elapsed: Double) {
        var allAnimationsComplete = true
        var anyAnimationRepeated = false
        
        for ((_, animationState) in currentAnimations) {
            val result = animationState.update(currentTime, elapsed)
            
            if (result.isActive) {
                allAnimationsComplete = false
            }
            if (result.didRepeat) {
                anyAnimationRepeated = true
            }
        }
        
        // Fire repeat event if any animation repeated (throttled to prevent spam)
        if (anyAnimationRepeated) {
            val now = System.currentTimeMillis()
            if (now - lastRepeatEventTime >= REPEAT_EVENT_THROTTLE_MS) {
                fireAnimationEvent("onAnimationRepeat")
                lastRepeatEventTime = now
            }
        }
        
        // Check if all animations are complete
        if (allAnimationsComplete) {
            stopPureAnimation()
        }
    }
    
    private fun executeWorklet(elapsed: Double, worklet: Map<String, Any?>) {
        // Get worklet configuration
        val functionData = worklet["function"] as? Map<*, *>
        // Check returnType from both worklet and workletExecutionConfig (AnimatedText sets it in config)
        val returnType = workletExecutionConfig?.get("returnType") as? String 
            ?: worklet["returnType"] as? String 
            ?: "dynamic"
        val updateTextChild = workletExecutionConfig?.get("updateTextChild") as? Boolean ?: false
        val isCompiled = worklet["isCompiled"] as? Boolean ?: false
        val workletType = functionData?.get("type") as? String ?: "dart_function"
        
        // 🔥 PERFORMANCE: Removed excessive logging - only log errors
        
        // Check if this is an interpretable worklet (runtime execution - NO REBUILD NEEDED!)
        // Extract IR with proper type handling (bridge serialization might change types)
        val irValue = functionData?.get("ir")
        
        // Convert IR to Map<String, Any?> - handle different map types from bridge
        // The IR structure from WorkletRuntimeInterpreter.serializeIR is:
        // { 'functionName': ..., 'returnType': ..., 'parameters': [...], 'body': {...} }
        val irMap = when {
            irValue == null -> {
                Log.w(TAG, "⚠️ WORKLET: IR value is null in executeWorklet")
                null
            }
            irValue is Map<*, *> -> {
                // Convert Map<*, *> to Map<String, Any?>
                try {
                    val converted = mutableMapOf<String, Any?>()
                    irValue.forEach { (key, value) ->
                        converted[key.toString()] = value
                    }
                    converted
                } catch (e: Exception) {
                    Log.e(TAG, "❌ WORKLET: Error converting IR map: ${e.message}", e)
                    null
                }
            }
            else -> null
        }
        
        // 🔥 PERFORMANCE: Removed excessive logging - only log errors
        
        // 🔥 CRITICAL: For text worklets, ALWAYS use pattern matching (works perfectly, no IR needed)
        // Text worklets often have loops which can't be compiled to IR, so pattern matching is the fallback
        // Auto-detect text worklets: if returnType is String, treat as text worklet
        if (returnType == "String") {
            executeTextWorklet(elapsed, worklet)
            return
        }
        
        // For numeric worklets, try IR interpretation first (framework-level WorkletInterpreter)
        if (irMap != null || workletType == "interpretable") {
            // For numeric worklets, interpret IR at runtime using framework-level WorkletInterpreter
            // This is the same as iOS - worklets are handled at framework level, not component level
            if (irMap != null) {
                try {
                    // Use framework-level WorkletInterpreter (same as iOS uses dcflight.WorkletInterpreter)
                    val result = com.dotcorr.dcflight.worklet.WorkletInterpreter.execute(
                        irMap,
                        elapsed,
                        workletExecutionConfig
                    )
                    if (result != null) {
                        applyWorkletResult(result, returnType)
                        return
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ WORKLET: Error executing worklet: ${e.message}", e)
                }
            }
        }
        
        // Legacy fallback - if we get here, worklet wasn't interpretable and isn't a text worklet
        stopPureAnimation()
    }
    
    
    /**
     * Apply worklet result to view based on return type and target property.
     * 
     * 🔥 NOW USES WorkletRuntime API - proper Reanimated-like abstraction!
     * No more component-specific glue code.
     */
    private fun applyWorkletResult(result: Any?, returnType: String) {
        when (returnType) {
            "double", "int" -> {
                val value = (result as? Number)?.toDouble() ?: return
                
                // Get target property from config
                val targetProperty = workletExecutionConfig?.get("targetProperty") as? String ?: "scale"
                
                // Get target view (from config or self) and use cached proxy (zero lookups per frame)
                val targetView = if (workletExecutionConfig?.get("targetViewId") != null) {
                    // Target view specified in config - would need lookup, but for now assume self
                    this
                } else {
                    // Target is self
                    this
                }
                
                // Use cached proxy (zero lookups after first frame)
                val viewProxy = getCachedWorkletProxy(targetView)
                if (viewProxy != null) {
                    viewProxy.setProperty(targetProperty, value)
                    return
                }
            }
            "String" -> {
                // String results are handled by executeTextWorklet
                // This shouldn't be called for String worklets
            }
            else -> {
                Log.d(TAG, "🔄 WORKLET: Result type $returnType not yet handled")
            }
        }
    }
    
    /**
     * Execute a text-returning worklet (e.g., typewriter effect) on UI thread.
     * This runs entirely natively without bridge calls.
     * 
     * For text worklets, we run continuously (no duration limit) to allow
     * infinite loops like typewriter effects.
     */
    private fun executeTextWorklet(elapsed: Double, worklet: Map<String, Any?>) {
        // 🔥 PERFORMANCE: Removed excessive logging - only log errors
        
        // Get worklet config parameters
        val words = (workletExecutionConfig?.get("words") as? List<*>)?.mapNotNull { it as? String } ?: emptyList()
        val typeSpeed = ((workletExecutionConfig?.get("typeSpeed") as? Number)?.toDouble() ?: 100.0) / 1000.0 // Convert ms to seconds
        val deleteSpeed = ((workletExecutionConfig?.get("deleteSpeed") as? Number)?.toDouble() ?: 50.0) / 1000.0
        val pauseDuration = ((workletExecutionConfig?.get("pauseDuration") as? Number)?.toDouble() ?: 2000.0) / 1000.0
        
        if (words.isEmpty()) {
            Log.w(TAG, "⚠️ WORKLET: No words provided for typewriter worklet")
            stopPureAnimation()
            return
        }
        
        // Calculate total time per word cycle
        var totalTimePerCycle = 0.0
        for (word in words) {
            totalTimePerCycle += (word.length * typeSpeed) + pauseDuration + (word.length * deleteSpeed)
        }
        
        // Find current word and position based on elapsed time
        val cycleTime = elapsed % totalTimePerCycle
        var wordIndex = 0
        var accumulatedTime = 0.0
        
        for (i in words.indices) {
            val word = words[i]
            val wordTypeTime = word.length * typeSpeed
            val wordPauseTime = pauseDuration
            val wordDeleteTime = word.length * deleteSpeed
            val wordTotalTime = wordTypeTime + wordPauseTime + wordDeleteTime
            
            if (cycleTime <= accumulatedTime + wordTotalTime) {
                wordIndex = i
                break
            }
            accumulatedTime += wordTotalTime
        }
        
        val currentWord = words[wordIndex]
        val wordStartTime = accumulatedTime
        val wordTypeTime = currentWord.length * typeSpeed
        val wordPauseTime = pauseDuration
        
        val relativeTime = cycleTime - wordStartTime
        
        val resultText = when {
            relativeTime < wordTypeTime -> {
                // Typing phase
                val charIndex = (relativeTime / typeSpeed).toInt().coerceAtMost(currentWord.length)
                currentWord.substring(0, charIndex)
            }
            relativeTime < wordTypeTime + wordPauseTime -> {
                // Pause phase - show full word
                currentWord
            }
            else -> {
                // Deleting phase
                val deleteStartTime = wordTypeTime + wordPauseTime
                val deleteElapsed = relativeTime - deleteStartTime
                val charsToDelete = (deleteElapsed / deleteSpeed).toInt()
                val remainingChars = (currentWord.length - charsToDelete).coerceAtLeast(0)
                currentWord.substring(0, remainingChars)
            }
        }
        
        // 🔥 PERFORMANCE: Removed logging - update text directly
        // Update child text component directly on UI thread
        updateChildText(resultText)
    }
    
    /**
     * Get or cache WorkletViewProxy for a view (works for ALL worklet types).
     * This avoids ANY lookups per frame - just direct property updates like native animations.
     * 
     * 🔥 PERFORMANCE: Check tag FIRST (O(1)) before doing linear search (O(n))
     */
    private fun getCachedWorkletProxy(view: android.view.View): com.dotcorr.dcflight.worklet.WorkletViewProxy? {
        // If same view, return cached proxy (zero lookups)
        if (cachedTargetView === view && cachedWorkletProxy != null) {
            return cachedWorkletProxy
        }
        
        // Cache miss - find viewId (only happens once)
        var viewId: Int? = null
        
        // 🔥 PERFORMANCE: Check tag FIRST (O(1) operation) before linear search
        viewId = view.getTag(com.dotcorr.dcflight.components.DCFTags.VIEW_ID_KEY) as? Int
        
        // Fallback: Try ViewRegistry lookup (only if tag is missing - rare case)
        if (viewId == null) {
            for (id in com.dotcorr.dcflight.layout.ViewRegistry.shared.allViewIds) {
                val viewInfo = com.dotcorr.dcflight.layout.ViewRegistry.shared.getViewInfo(id)
                if (viewInfo?.view === view) {
                    viewId = id
                    break
                }
            }
        }
        
        if (viewId != null) {
            // Get proxy and cache it
            val proxy = com.dotcorr.dcflight.worklet.WorkletRuntime.getView(viewId)
            if (proxy != null) {
                cachedWorkletProxy = proxy
                cachedTargetView = view
                return proxy
            }
        }
        
        return null
    }
    
    /**
     * Update child text component directly from UI thread (zero bridge calls).
     * Uses cached WorkletViewProxy - zero lookups per frame after first lookup.
     */
    private fun updateChildText(text: String) {
        // If we have cached proxy and view is still valid, use it directly (zero lookups)
        val cachedView = cachedTargetView
        val cachedProxy = cachedWorkletProxy
        if (cachedView != null && cachedProxy != null && cachedView.parent === this) {
            cachedProxy.setProperty("text", text)
            return
        }
        
        // Cache miss - find text view child (only happens once)
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            
            // Check if this is a DCFTextView (from DCFTextComponent)
            if (child.javaClass.simpleName == "DCFTextView") {
                val viewProxy = getCachedWorkletProxy(child)
                if (viewProxy != null) {
                    viewProxy.setProperty("text", text)
                    return
                }
            }
            
            // Recursively check children (in case text is nested)
            if (child is android.view.ViewGroup) {
                val found = updateChildTextRecursive(child, text)
                if (found) return
            }
        }
    }
    
    private fun updateChildTextRecursive(parent: android.view.ViewGroup, text: String): Boolean {
        for (i in 0 until parent.childCount) {
            val child = parent.getChildAt(i)
            if (child.javaClass.simpleName == "DCFTextView") {
                val viewProxy = getCachedWorkletProxy(child)
                if (viewProxy != null) {
                    viewProxy.setProperty("text", text)
                    return true
                }
            }
            if (child is android.view.ViewGroup) {
                if (updateChildTextRecursive(child, text)) {
                    return true
                }
            }
        }
        return false
    }
    
    // ============================================================================
    // EVENT SYSTEM
    // ============================================================================
    
    private fun fireAnimationEvent(eventType: String) {
        // Only fire event if view is registered and has event listeners
        val viewId = getTag(com.dotcorr.dcflight.components.DCFTags.VIEW_ID_KEY) as? Int
        if (viewId != null && nodeId != null) {
            propagateEvent(
                this,
                eventType,
                mapOf(
                    "timestamp" to System.currentTimeMillis()
                )
            )
        }
    }
    
    override fun onDetachedFromWindow() {
        // 🔥 LIFECYCLE FIX: Stop worklet when view is detached from window
        // This ensures worklets don't continue running after component is deleted
        // Since worklets run on UI thread, they don't auto-stop when Dart components are replaced
        isAnimating = false
        workletConfig = null
        isUsingWorklet = false
        stopFrameCallback()
        
        // 🔥 PERFORMANCE: Clear proxy cache when view is detached
        cachedWorkletProxy = null
        cachedTargetView = null
        
        super.onDetachedFromWindow()
    }
}

/**
 * Animation state for individual property animations
 */
data class PureAnimationResult(
    val isActive: Boolean,
    val didRepeat: Boolean
)

class PureAnimationState(
    val property: String,
    private val config: Map<String, Any?>,
    private val view: View
) {
    val fromValue: Float // Made public for initial value application
    private val toValue: Float
    private val keyframes: List<Float>? // Support keyframe animations
    private val duration: Long
    private val delay: Long
    private val isRepeating: Boolean
    private val repeatCount: Int?
    private val damping: Double? // Spring damping
    private val stiffness: Double? // Spring stiffness
    
    /// Apply initial value to view (before animation starts)
    fun applyInitialValue() {
        applyAnimationValue(fromValue)
    }
    
    private var cycleCount = 0
    private var isReversing = false
    private var cycleStartTime: Long = 0 // Track cycle start time for smooth repeats (matches iOS)
    
    private val curve: (Float) -> Float
    
    init {
        // Parse keyframes if present, otherwise use from/to
        if (config["keyframes"] is List<*>) {
            val keyframesList = config["keyframes"] as List<*>
            keyframes = keyframesList.mapNotNull { 
                when (it) {
                    is Number -> it.toDouble().toFloat()
                    is Double -> it.toFloat()
                    is Float -> it
                    else -> null
                }
            }
            fromValue = keyframes?.firstOrNull() ?: 0f
            toValue = keyframes?.lastOrNull() ?: 1f
        } else {
            keyframes = null
            fromValue = ((config["from"] as? Number)?.toDouble() ?: 0.0).toFloat()
            toValue = ((config["to"] as? Number)?.toDouble() ?: 1.0).toFloat()
        }
        
        val durationMs = (config["duration"] as? Number)?.toInt() ?: 300
        duration = durationMs.toLong()
        
        val delayMs = (config["delay"] as? Number)?.toInt() ?: 0
        delay = delayMs.toLong()
        
        isRepeating = config["repeat"] as? Boolean ?: false
        repeatCount = config["repeatCount"] as? Int
        
        // Parse spring parameters
        damping = (config["damping"] as? Number)?.toDouble()
        stiffness = (config["stiffness"] as? Number)?.toDouble()
        
        // Parse curve - support all curves from iOS
        val curveString = (config["curve"] as? String ?: "easeInOut").lowercase()
        curve = getCurveFunction(curveString, damping, stiffness)
        
        if (keyframes != null) {
            Log.d("PureAnimationState", "🎯 $property keyframes ${keyframes} over ${duration}ms with curve $curveString")
        } else {
            Log.d("PureAnimationState", "🎯 $property from $fromValue to $toValue over ${duration}ms with curve $curveString")
        }
    }
    
    companion object {
        /**
         * Get easing curve function - matches iOS implementation
         */
        fun getCurveFunction(curveString: String, damping: Double? = null, stiffness: Double? = null): (Float) -> Float {
            return when (curveString.lowercase()) {
                "linear" -> { t -> t }
                "easein" -> { t -> t * t }
                "easeout" -> { t -> 1 - (1 - t) * (1 - t) }
                "easeinout" -> { t -> 
                    if (t < 0.5f) {
                        2 * t * t
                    } else {
                        1 - 2 * (1 - t) * (1 - t)
                    }
                }
                "spring" -> { t -> springCurve(t, damping, stiffness) }
                "bouncein" -> { t -> bounceInCurve(t) }
                "bounceout" -> { t -> bounceOutCurve(t) }
                "elasticin" -> { t -> elasticInCurve(t) }
                "elasticout" -> { t -> elasticOutCurve(t) }
                else -> { t -> 
                    // Default to easeInOut
                    if (t < 0.5f) {
                        2 * t * t
                    } else {
                        1 - 2 * (1 - t) * (1 - t)
                    }
                }
            }
        }
        
        private fun springCurve(t: Float, damping: Double? = null, stiffness: Double? = null): Float {
            val dampingValue = (damping ?: 0.8).toFloat()
            val stiffnessValue = (stiffness ?: 300.0).toFloat()
            val frequency = Math.sqrt((stiffnessValue / 1.0).toDouble()).toFloat() // Mass = 1.0
            
            if (t == 0f || t == 1f) {
                return t
            }
            
            val omega = frequency * 2 * Math.PI.toFloat()
            val exponential = Math.pow(2.0, (-dampingValue * t).toDouble()).toFloat()
            val sine = Math.sin((omega * t + Math.acos(dampingValue.toDouble())).toDouble()).toFloat()
            
            return 1 - exponential * sine
        }
        
        private fun bounceInCurve(t: Float): Float {
            return 1 - bounceOutCurve(1 - t)
        }
        
        private fun bounceOutCurve(t: Float): Float {
            if (t < 1 / 2.75f) {
                return 7.5625f * t * t
            } else if (t < 2 / 2.75f) {
                val t2 = t - 1.5f / 2.75f
                return 7.5625f * t2 * t2 + 0.75f
            } else if (t < 2.5 / 2.75f) {
                val t2 = t - 2.25f / 2.75f
                return 7.5625f * t2 * t2 + 0.9375f
            } else {
                val t2 = t - 2.625f / 2.75f
                return 7.5625f * t2 * t2 + 0.984375f
            }
        }
        
        private fun elasticInCurve(t: Float): Float {
            if (t == 0f || t == 1f) return t
            val c4 = (2 * Math.PI / 3).toFloat()
            return -Math.pow(2.0, (10.0 * (t - 1.0)).toDouble()).toFloat() * Math.sin(((t - 1.0) * c4).toDouble()).toFloat()
        }
        
        private fun elasticOutCurve(t: Float): Float {
            if (t == 0f || t == 1f) return t
            val c4 = (2 * Math.PI / 3).toFloat()
            return Math.pow(2.0, (-10.0 * t).toDouble()).toFloat() * Math.sin(((t - 1.0) * c4).toDouble()).toFloat() + 1
        }
    }
    
    fun update(currentTime: Long, elapsed: Double): PureAnimationResult {
        // Initialize cycle start time on first update (matches iOS behavior)
        if (cycleStartTime == 0L) {
            cycleStartTime = currentTime
        }
        
        // Calculate elapsed time relative to current cycle (not overall animation start)
        // This ensures smooth repeats by resetting the timer for each cycle
        val cycleElapsed = currentTime - cycleStartTime
        val cycleElapsedMs = cycleElapsed - delay
        
        // Check if animation hasn't started yet (delay)
        if (cycleElapsedMs < 0) {
            return PureAnimationResult(isActive = true, didRepeat = false)
        }
        
        val progress = (cycleElapsedMs.toFloat() / duration).coerceIn(0f, 1f)
        val easedProgress = curve(progress)
        
        // Calculate current value - support keyframes
        val currentValue: Float = if (keyframes != null) {
            // Keyframe animation: interpolate between keyframes
            val keyframeCount = keyframes!!.size
            if (keyframeCount == 1) {
                keyframes!![0]
            } else {
                val segmentProgress = progress * (keyframeCount - 1)
                val segmentIndex = segmentProgress.toInt()
                val segmentT = segmentProgress - segmentIndex
                
                if (segmentIndex >= keyframeCount - 1) {
                    keyframes!![keyframeCount - 1]
                } else {
                    val fromKeyframe = keyframes!![segmentIndex]
                    val toKeyframe = keyframes!![segmentIndex + 1]
                    fromKeyframe + (toKeyframe - fromKeyframe) * segmentT
                }
            }
        } else {
            // Standard from/to animation
            val currentFromValue = if (isReversing) toValue else fromValue
            val currentToValue = if (isReversing) fromValue else toValue
            currentFromValue + (currentToValue - currentFromValue) * easedProgress
        }
        
        // Apply to view
        applyAnimationValue(currentValue)
        
        // Check if cycle is complete
        if (progress >= 1.0f) {
            if (isRepeating) {
                val shouldContinue = repeatCount == null || cycleCount < repeatCount
                
                if (shouldContinue) {
                    cycleCount++
                    isReversing = !isReversing
                    // CRITICAL: Reset cycle start time for smooth repeat (matches iOS)
                    // This prevents the animation from jumping to the end immediately
                    cycleStartTime = currentTime
                    return PureAnimationResult(isActive = true, didRepeat = true)
                }
            }
            
            return PureAnimationResult(isActive = false, didRepeat = false)
        }
        
        return PureAnimationResult(isActive = true, didRepeat = false)
    }
    
    private fun applyAnimationValue(value: Float) {
        when (property) {
            "opacity" -> view.alpha = value
            "scale" -> {
                view.scaleX = value
                view.scaleY = value
            }
            "scaleX" -> view.scaleX = value
            "scaleY" -> view.scaleY = value
            "translateX" -> view.translationX = value
            "translateY" -> view.translationY = value
            "translateZ" -> {
                // 3D translation requires elevation on Android
                view.translationZ = value
                // Also set elevation for proper 3D effect
                view.elevation = value
            }
            "rotation" -> view.rotation = value
            "rotationX" -> view.rotationX = value
            "rotationY" -> view.rotationY = value
            "rotationZ" -> view.rotation = value
            "scaleX" -> view.scaleX = value
            "scaleY" -> view.scaleY = value
            "translateX" -> view.translationX = value
            "translateY" -> view.translationY = value
            "rotation" -> view.rotation = value
            "rotationX" -> view.rotationX = value
            "rotationY" -> view.rotationY = value
            "backgroundColor" -> {
                // Convert value (0-1) to hue for color animation
                val hue = value * 360f
                view.setBackgroundColor(android.graphics.Color.HSVToColor(floatArrayOf(hue, 1f, 1f)))
            }
            "width" -> {
                val layoutParams = view.layoutParams
                layoutParams.width = value.toInt()
                view.layoutParams = layoutParams
            }
            "height" -> {
                val layoutParams = view.layoutParams
                layoutParams.height = value.toInt()
                view.layoutParams = layoutParams
            }
            else -> Log.w("PureAnimationState", "⚠️ Unknown animation property: $property")
        }
    }
}

