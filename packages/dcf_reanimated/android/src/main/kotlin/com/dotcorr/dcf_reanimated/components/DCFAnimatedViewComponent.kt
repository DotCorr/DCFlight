/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_reanimated.components

import android.content.Context
import android.graphics.PointF
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
            
            // Auto-start if configured
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
        
        // Update worklet or animation style
        if (mergedProps["worklet"] is Map<*, *>) {
            val workletData = mergedProps["worklet"] as Map<String, Any?>
            val workletConfig = mergedProps["workletConfig"] as? Map<String, Any?>
            reanimatedView.updateWorklet(workletData, workletConfig)
        } else if (mergedProps["animatedStyle"] is Map<*, *>) {
            val animatedStyle = mergedProps["animatedStyle"] as Map<String, Any?>
            reanimatedView.updateAnimationConfig(animatedStyle)
        }
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }
        reanimatedView.applyStyles(nonNullProps)
        
        return true
    }

    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        return PointF(0f, 0f)
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

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
        val reanimatedView = view as? PureReanimatedView ?: return
        reanimatedView.nodeId = nodeId
        Log.d(TAG, "ReanimatedView registered with shadow tree: $nodeId")
    }
    
    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
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
    private var workletConfig: Map<String, Any?>? = null
    private var workletExecutionConfig: Map<String, Any?>? = null
    private var isUsingWorklet = false
    
    // Identifiers for callbacks
    var nodeId: String? = null
    
    // ============================================================================
    // WORKLET CONFIGURATION - UI THREAD EXECUTION
    // ============================================================================
    
    fun configureWorklet(workletData: Map<String, Any?>, config: Map<String, Any?>?) {
        Log.d(TAG, "🔧 WORKLET: Configuring worklet for pure UI thread execution")
        this.workletConfig = workletData
        this.workletExecutionConfig = config
        this.isUsingWorklet = true
        
        // Clear animation config when using worklet
        currentAnimations.clear()
    }
    
    fun updateWorklet(workletData: Map<String, Any?>, config: Map<String, Any?>?) {
        stopPureAnimation()
        configureWorklet(workletData, config)
        startPureAnimation()
    }
    
    // ============================================================================
    // PURE ANIMATION CONFIGURATION
    // ============================================================================
    
    fun configurePureAnimation(animatedStyle: Map<String, Any?>) {
        Log.d(TAG, "🎯 PURE REANIMATED: Configuring animation from props")
        this.animationConfig = animatedStyle
        this.isUsingWorklet = false
        
        // Parse animation configurations
        currentAnimations.clear()
        
        for ((property, config) in animatedStyle) {
            if (config is Map<*, *>) {
                currentAnimations[property] = PureAnimationState(
                    property = property,
                    config = config as Map<String, Any?>,
                    view = this
                )
            }
        }
    }
    
    fun updateAnimationConfig(animatedStyle: Map<String, Any?>) {
        stopPureAnimation()
        configurePureAnimation(animatedStyle)
        startPureAnimation()
    }
    
    // ============================================================================
    // ANIMATION CONTROL
    // ============================================================================
    
    fun startPureAnimation() {
        if (isAnimating) return
        
        if (isUsingWorklet && workletConfig == null) {
            Log.w(TAG, "⚠️ PURE REANIMATED: No worklet configured")
            return
        }
        
        if (!isUsingWorklet && currentAnimations.isEmpty()) {
            Log.w(TAG, "⚠️ PURE REANIMATED: No animations configured")
            return
        }
        
        Log.d(TAG, "🚀 PURE REANIMATED: Starting pure UI thread animation")
        
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
        // CRITICAL: When animation stops, ensure pivot point is at center
        // This prevents content from appearing off-center when transforms are active
        // The pivot point determines where transforms are applied from
        if (width > 0 && height > 0) {
            pivotX = width / 2f
            pivotY = height / 2f
        }
    }
    
    // ============================================================================
    // FRAME CALLBACK - UI THREAD EXECUTION
    // ============================================================================
    
    private fun startFrameCallback() {
        if (frameCallback != null) return
        
        frameCallback = Choreographer.FrameCallback { frameTimeNanos ->
            if (!isAnimating) {
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
            
            // Schedule next frame
            choreographer.postFrameCallback(frameCallback!!)
        }
        
        choreographer.postFrameCallback(frameCallback!!)
    }
    
    private fun stopFrameCallback() {
        frameCallback?.let {
            choreographer.removeFrameCallback(it)
            frameCallback = null
        }
    }
    
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
        
        // Fire repeat event if any animation repeated
        if (anyAnimationRepeated) {
            fireAnimationEvent("onAnimationRepeat")
        }
        
        // Check if all animations are complete
        if (allAnimationsComplete) {
            stopPureAnimation()
        }
    }
    
    private fun executeWorklet(elapsed: Double, worklet: Map<String, Any?>) {
        // Get worklet configuration
        val functionData = worklet["function"] as? Map<*, *>
        val source = functionData?.get("source") as? String
        
        if (source == null) {
            Log.w(TAG, "⚠️ WORKLET: Invalid worklet configuration")
            stopPureAnimation()
            return
        }
        
        // Get duration from config (default: 2000ms)
        val duration = ((workletExecutionConfig?.get("duration") as? Number)?.toDouble() ?: 2000.0) / 1000.0
        
        // Check if worklet should complete
        if (elapsed >= duration) {
            stopPureAnimation()
            return
        }
        
        // Execute worklet (simplified - in production would use compiled code or interpreter)
        // For now, we'll use a simple evaluation approach
        val progress = elapsed / duration
        val normalizedTime = progress
        
        // Apply worklet result to view (simplified example)
        // In production, the worklet function would be properly executed
        val scale = (1.0 + Math.sin(normalizedTime * Math.PI * 2) * 0.1).toFloat()
        scaleX = scale
        scaleY = scale
        
        // Note: In production, the worklet function would be properly executed
        // This is a simplified placeholder that demonstrates the concept
    }
    
    // ============================================================================
    // EVENT SYSTEM
    // ============================================================================
    
    private fun fireAnimationEvent(eventType: String) {
        nodeId?.let { id ->
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
        super.onDetachedFromWindow()
        stopPureAnimation()
        Log.d(TAG, "🗑️ PURE REANIMATED: View detached from window")
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
    private val fromValue: Float
    private val toValue: Float
    private val duration: Long
    private val delay: Long
    private val isRepeating: Boolean
    private val repeatCount: Int?
    
    private var cycleCount = 0
    private var isReversing = false
    
    private val curve: (Float) -> Float
    
    init {
        fromValue = ((config["from"] as? Number)?.toDouble() ?: 0.0).toFloat()
        toValue = ((config["to"] as? Number)?.toDouble() ?: 1.0).toFloat()
        
        val durationMs = (config["duration"] as? Number)?.toInt() ?: 300
        duration = durationMs.toLong()
        
        val delayMs = (config["delay"] as? Number)?.toInt() ?: 0
        delay = delayMs.toLong()
        
        isRepeating = config["repeat"] as? Boolean ?: false
        repeatCount = config["repeatCount"] as? Int
        
        // Parse curve - support all curves from iOS
        val curveString = (config["curve"] as? String ?: "easeInOut").lowercase()
        curve = getCurveFunction(curveString)
        
        Log.d("PureAnimationState", "🎯 $property from $fromValue to $toValue over ${duration}ms with curve $curveString")
    }
    
    companion object {
        /**
         * Get easing curve function - matches iOS implementation
         */
        fun getCurveFunction(curveString: String): (Float) -> Float {
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
                "spring" -> { t -> springCurve(t) }
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
        
        private fun springCurve(t: Float): Float {
            val damping = 0.8f
            val frequency = 8.0f
            
            if (t == 0f || t == 1f) {
                return t
            }
            
            val omega = frequency * 2 * Math.PI.toFloat()
            val exponential = Math.pow(2.0, (-damping * t).toDouble()).toFloat()
            val sine = Math.sin((omega * t + Math.acos(damping.toDouble())).toDouble()).toFloat()
            
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
        val elapsedMs = (elapsed * 1000).toLong() - delay
        
        // Check if animation hasn't started yet (delay)
        if (elapsedMs < 0) {
            return PureAnimationResult(isActive = true, didRepeat = false)
        }
        
        val progress = (elapsedMs.toFloat() / duration).coerceIn(0f, 1f)
        val easedProgress = curve(progress)
        
        // Calculate current value
        val currentFromValue = if (isReversing) toValue else fromValue
        val currentToValue = if (isReversing) fromValue else toValue
        val currentValue = currentFromValue + (currentToValue - currentFromValue) * easedProgress
        
        // Apply to view
        applyAnimationValue(currentValue)
        
        // Check if cycle is complete
        if (progress >= 1.0f) {
            if (isRepeating) {
                val shouldContinue = repeatCount == null || cycleCount < repeatCount
                
                if (shouldContinue) {
                    cycleCount++
                    isReversing = !isReversing
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

