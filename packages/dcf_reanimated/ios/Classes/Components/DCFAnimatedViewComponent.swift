/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit
import dcflight
import ObjectiveC
import Foundation
import Darwin

class DCFAnimatedViewComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Debug: Print all props to see what we're receiving
        print("🔍 REANIMATED: createView called with props keys: \(Array(props.keys))")
        print("🔍 REANIMATED: isPureReanimated = \(props["isPureReanimated"] ?? "nil")")
        print("🔍 REANIMATED: worklet = \(props["worklet"] != nil ? "exists" : "nil")")
        print("🔍 REANIMATED: workletConfig = \(props["workletConfig"] != nil ? "exists" : "nil")")
        print("🔍 REANIMATED: autoStart = \(props["autoStart"] ?? "nil")")
        
        // Print worklet structure if it exists
        if let workletData = props["worklet"] as? [String: Any] {
            print("🔍 REANIMATED: worklet keys: \(Array(workletData.keys))")
            if let functionData = workletData["function"] as? [String: Any] {
                print("🔍 REANIMATED: function keys: \(Array(functionData.keys))")
            }
            if let returnType = workletData["returnType"] as? String {
                print("🔍 REANIMATED: returnType = \(returnType)")
            }
        }
        
        // Print workletConfig structure if it exists
        if let workletConfig = props["workletConfig"] as? [String: Any] {
            print("🔍 REANIMATED: workletConfig keys: \(Array(workletConfig.keys))")
            print("🔍 REANIMATED: workletConfig content: \(workletConfig)")
        }
        
        let reanimatedView = PureReanimatedView()
        
        // Configure everything from props immediately - NO BRIDGE CALLS
        if let isPure = props["isPureReanimated"] as? Bool, isPure {
            print("🎯 PURE REANIMATED: Creating view with pure UI thread configuration")
            
            // Configure worklet if provided (takes precedence)
            if let workletData = props["worklet"] as? [String: Any] {
                let workletConfig = props["workletConfig"] as? [String: Any]
                print("🎯 PURE REANIMATED: Found worklet in props, configuring...")
                print("🎯 PURE REANIMATED: workletData type: \(type(of: workletData))")
                print("🎯 PURE REANIMATED: workletConfig: \(workletConfig ?? [:])")
                reanimatedView.configureWorklet(workletData, workletConfig)
            } else if let animatedStyle = props["animatedStyle"] as? [String: Any] {
                // Fall back to animated style
                print("🎯 PURE REANIMATED: No worklet found, using animatedStyle")
                reanimatedView.configurePureAnimation(animatedStyle)
            } else {
                print("⚠️ PURE REANIMATED: No worklet or animatedStyle found!")
            }
            
            // Auto-start if configured (default: true for AnimatedText)
            let autoStart = props["autoStart"] as? Bool ?? true
            let startDelay = props["startDelay"] as? Int ?? 0
            
            print("🎯 PURE REANIMATED: autoStart=\(autoStart), startDelay=\(startDelay)")
            
            if autoStart {
                if startDelay > 0 {
                    print("⏳ PURE REANIMATED: Delaying animation start by \(startDelay)ms")
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(startDelay)) {
                        print("🚀 PURE REANIMATED: Starting animation after delay")
                        reanimatedView.startPureAnimation()
                    }
                } else {
                    print("🚀 PURE REANIMATED: Starting animation immediately")
                    reanimatedView.startPureAnimation()
                }
            } else {
                print("⏸️ PURE REANIMATED: autoStart=false, animation not starting automatically")
            }
        } else {
            print("⚠️ REANIMATED: isPureReanimated is false or missing!")
        }
        
        // Apply styles
        reanimatedView.applyStyles(props: props)
        
        return reanimatedView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let reanimatedView = view as? PureReanimatedView else { return false }
        
        // 🔥 LIFECYCLE FIX: If worklet prop is removed (component replaced with non-worklet),
        // stop the old worklet animation immediately
        let hadWorklet = reanimatedView.isUsingWorklet
        let hasWorklet = props["worklet"] != nil
        
        if hadWorklet && !hasWorklet {
            // Worklet was removed - stop animation immediately
            print("🛑 WORKLET: Worklet prop removed in updateView, stopping old animation")
            reanimatedView.stopPureAnimation()
            reanimatedView.workletConfig = nil
            reanimatedView.isUsingWorklet = false
        }
        
        // Update worklet or animation style
        if let workletData = props["worklet"] as? [String: Any] {
            let workletConfig = props["workletConfig"] as? [String: Any]
            reanimatedView.updateWorklet(workletData, workletConfig)
        } else if let animatedStyle = props["animatedStyle"] as? [String: Any] {
            reanimatedView.updateAnimationConfig(animatedStyle)
        }
        
        // Handle autoStart changes - control animation start/stop
        if let autoStart = props["autoStart"] as? Bool {
            if autoStart && !reanimatedView.isAnimating {
                // Start animation if autoStart is true and not already animating
                reanimatedView.startPureAnimation()
            } else if !autoStart && reanimatedView.isAnimating {
                // Stop animation if autoStart is false and currently animating
                reanimatedView.stopPureAnimation()
            }
        }
        
        view.applyStyles(props: props)
        return true
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        // Store node ID for event callbacks
        if let reanimatedView = view as? PureReanimatedView {
            reanimatedView.nodeId = nodeId
        }
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        guard let reanimatedView = view as? PureReanimatedView else {
            // For non-reanimated views, set frame directly
            view.frame = CGRect(
                x: CGFloat(layout.left),
                y: CGFloat(layout.top),
                width: CGFloat(layout.width),
                height: CGFloat(layout.height)
            )
            return
        }
        
        // CRITICAL: For ReanimatedView, skip layout updates during state changes to prevent stuttering
        // Layout updates interfere with transform animations by recalculating anchor points
        // Only update if size actually changed significantly (more than 5 pixels)
        let newFrame = CGRect(
            x: CGFloat(layout.left),
            y: CGFloat(layout.top),
            width: CGFloat(layout.width),
            height: CGFloat(layout.height)
        )
        
        // Check if size changed significantly
        let sizeChanged = abs(newFrame.width - reanimatedView.bounds.width) > 5.0 ||
                         abs(newFrame.height - reanimatedView.bounds.height) > 5.0
        
        // If size hasn't changed significantly, skip layout update entirely
        // This prevents stuttering caused by frame/bounds updates interfering with transforms
        if !sizeChanged {
            return
        }
        
        // CRITICAL: Always ensure anchor point is at center for proper transform behavior
        // This prevents content from appearing off-center when transforms are active
        if reanimatedView.layer.anchorPoint != CGPoint(x: 0.5, y: 0.5) {
            // Calculate offset to maintain visual position when changing anchor point
            let currentFrame = reanimatedView.frame
            let anchorPointOffset = CGPoint(
                x: (reanimatedView.layer.anchorPoint.x - 0.5) * reanimatedView.bounds.width,
                y: (reanimatedView.layer.anchorPoint.y - 0.5) * reanimatedView.bounds.height
            )
            
            // Reset anchor point to center
            reanimatedView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            
            // Adjust center to maintain visual position
            reanimatedView.center = CGPoint(
                x: reanimatedView.center.x + anchorPointOffset.x,
                y: reanimatedView.center.y + anchorPointOffset.y
            )
        }
        
        // Always use bounds/center to preserve transforms (both during and after animation)
        // This ensures content stays centered and animations aren't interrupted
        reanimatedView.bounds = CGRect(origin: .zero, size: newFrame.size)
        reanimatedView.center = CGPoint(
            x: newFrame.midX,
            y: newFrame.midY
        )
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        // 🔥 UI FREEZE FIX: Universal pause/resume for ALL UI thread work
        switch method {
        case "pauseAllUIWork":
            PureReanimatedView.pauseAllUIWork()
            return true
        case "resumeAllUIWork":
            PureReanimatedView.resumeAllUIWork()
            return true
        default:
            return nil
        }
    }
}

// ============================================================================
// PURE REANIMATED VIEW - SELF-CONTAINED UI THREAD ANIMATION
// ============================================================================

class PureReanimatedView: UIView, DCFLayoutIndependent {
    
    // 🔥 UI FREEZE FIX: Global pause state for ALL UI thread work
    // Universal solution - pauses ALL frame callbacks/display links during rapid reconciliation
    private static var globalPauseState = false
    
    // Check if globally paused (prevents any animation/worklet from starting)
    private static func isGloballyPaused() -> Bool {
        return globalPauseState
    }
    
    // Pause ALL UI thread work globally (universal solution)
    static func pauseAllUIWork() {
        globalPauseState = true
        print("🛑 GLOBAL_PAUSE: Pausing ALL UI thread work (frame callbacks, display links, etc.)")
    }
    
    // Resume ALL UI thread work
    static func resumeAllUIWork() {
        globalPauseState = false
        print("▶️ GLOBAL_RESUME: Resuming UI thread work")
    }
    
    // Animation configuration
    private var animationConfig: [String: Any] = [:]
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0
    private var frameCount = 0
    var isAnimating = false
    private var logCounter = 0 // Counter for reducing log spam
    
    // MARK: - DCFLayoutIndependent Protocol
    
    /// Opt-out of layout updates when animating to prevent stuttering
    /// This makes the view layout-independent during animation
    var shouldSkipLayout: Bool {
        return isAnimating
    }
    
    // Animation state
    private var currentAnimations: [String: PureAnimationState] = [:]
    
    // Worklet configuration
    internal var workletConfig: [String: Any]?
    private var workletExecutionConfig: [String: Any]?
    internal var isUsingWorklet = false
    
    // Identifiers for callbacks
    var nodeId: String?
    
    // ============================================================================
    // PURE EVENT SYSTEM - MINIMAL BRIDGE USAGE
    // ============================================================================
    
    private func fireAnimationEvent(eventType: String) {
        guard let nodeId = nodeId else { return }
        
        // Check if event callback is registered before calling propagateEvent
        // This prevents infinite log spam when no callbacks are registered
        let callback = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!) 
            as? (String, String, [String: Any]) -> Void
        
        guard callback != nil else {
            // No event callback registered - silently return (don't spam logs)
            return
        }
        
        // Use global event propagation system
        propagateEvent(
            on: self,
            eventName: eventType,
            data: [
                "timestamp": CACurrentMediaTime()
            ]
        )
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        clipsToBounds = true
    }
    
    // ============================================================================
    // WORKLET CONFIGURATION - UI THREAD EXECUTION
    // ============================================================================
    
    func configureWorklet(_ workletData: [String: Any], _ config: [String: Any]?) {
        print("🔧 WORKLET: Configuring worklet for pure UI thread execution")
        print("🔧 WORKLET: workletData keys: \(Array(workletData.keys))")
        print("🔧 WORKLET: workletData full: \(workletData)")
        print("🔧 WORKLET: config: \(config ?? [:])")
        
        // Check if worklet is compiled
        let functionData = workletData["function"] as? [String: Any]
        let isCompiled = workletData["isCompiled"] as? Bool ?? false
        let workletType = functionData?["type"] as? String ?? "dart_function"
        
        print("🔧 WORKLET: functionData exists: \(functionData != nil)")
        print("🔧 WORKLET: isCompiled: \(isCompiled)")
        print("🔧 WORKLET: workletType: \(workletType)")
        
        // Check if worklet has IR for runtime interpretation
        let ir = functionData?["ir"] as? [String: Any]
        if ir != nil || workletType == "interpretable" {
            let workletId = functionData?["workletId"] as? String
            print("✅ WORKLET: Interpretable worklet detected! workletId=\(workletId ?? "unknown")")
            print("📝 WORKLET: IR available for runtime interpretation (no rebuild needed!)")
        } else {
            print("⚠️ WORKLET: No IR found, will use pattern matching for text worklets")
        }
        
        // Merge returnType from config into workletData if provided (for AnimatedText compatibility)
        var mergedWorkletData = workletData
        if let config = config, let configReturnType = config["returnType"] as? String {
            mergedWorkletData["returnType"] = configReturnType
            print("🔧 WORKLET: Merged returnType from config: \(configReturnType)")
        }
        
        self.workletConfig = mergedWorkletData
        self.workletExecutionConfig = config
        self.isUsingWorklet = true
        
        // Clear animation config when using worklet
        currentAnimations.removeAll()
        
        // Check return type (from workletData or config)
        let returnType = mergedWorkletData["returnType"] as? String ?? config?["returnType"] as? String ?? "dynamic"
        let updateTextChild = config?["updateTextChild"] as? Bool ?? false
        print("🔧 WORKLET: returnType=\(returnType), updateTextChild=\(updateTextChild)")
        print("🔧 WORKLET: isUsingWorklet set to true")
        print("🔧 WORKLET: workletConfig stored: \(workletConfig != nil)")
        print("🔧 WORKLET: workletExecutionConfig stored: \(workletExecutionConfig != nil)")
    }
    
    func updateWorklet(_ workletData: [String: Any], _ config: [String: Any]?) {
        // 🔥 LIFECYCLE FIX: UI thread worklets must be fully stopped before new ones start
        // Since worklets run on native UI thread (not Dart), they don't auto-cleanup when Dart components are replaced
        // We must explicitly stop the old worklet's display link and clear its state
        
        // CRITICAL: Always stop old worklet FIRST if it exists
        // This prevents orphaned display link callbacks from running after component replacement
        if workletConfig != nil {
            let functionData = workletData["function"] as? [String: Any]
            let newWorkletId = functionData?["workletId"] as? String
            let oldFunctionData = workletConfig?["function"] as? [String: Any]
            let oldWorkletId = oldFunctionData?["workletId"] as? String
            
            if let newId = newWorkletId, let oldId = oldWorkletId, newId != oldId {
                print("🛑 WORKLET: Worklet ID changed (old: \(oldId), new: \(newId)), stopping old worklet")
            } else {
                print("🛑 WORKLET: Worklet updated, stopping old worklet to prevent orphaned callbacks")
            }
            
            // CRITICAL: Stop display link IMMEDIATELY and synchronously
            // This invalidates the display link so no more frame callbacks can execute
            isAnimating = false
            stopDisplayLink()
            
            // CRITICAL: Clear worklet config to prevent old worklet from being executed
            // This ensures the frame callback (if it somehow still fires) won't execute old worklet
            workletConfig = nil
            isUsingWorklet = false
        }
        
        // Configure new worklet (this sets new workletConfig)
        configureWorklet(workletData, config)
        
        // Start new worklet on next frame to ensure old display link is fully invalidated
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Final safety check - ensure old animation is stopped
            if self.isAnimating && self.displayLink != nil {
                print("⚠️ WORKLET: Old animation still running, force stopping")
                self.isAnimating = false
                self.stopDisplayLink()
            }
            // Start new worklet
            self.startPureAnimation()
        }
    }
    
    // ============================================================================
    // PURE ANIMATION CONFIGURATION - NO BRIDGE CALLS
    // ============================================================================
    
    /// Configure animation entirely from props - PURE
    func configurePureAnimation(_ animatedStyle: [String: Any]) {
        self.isUsingWorklet = false
        print("🎯 PURE REANIMATED: Configuring animation from props")
        self.animationConfig = animatedStyle
        
        // Parse perspective if provided
        if let perspective = animatedStyle["perspective"] as? Double {
            // Set perspective on layer's sublayerTransform
            var transform = CATransform3DIdentity
            transform.m34 = -1.0 / CGFloat(perspective)
            self.layer.sublayerTransform = transform
        }
        
        // Parse animation configurations
        currentAnimations.removeAll()
        
        // Handle animations dictionary
        if let animations = animatedStyle["animations"] as? [String: Any] {
            for (property, config) in animations {
                if let animConfig = config as? [String: Any] {
                    currentAnimations[property] = PureAnimationState(
                        property: property,
                        config: animConfig,
                        view: self
                    )
                }
            }
        } else {
            // Legacy format: animations at top level
            for (property, config) in animatedStyle {
                if property != "perspective" && property != "preserve3d", let animConfig = config as? [String: Any] {
                    currentAnimations[property] = PureAnimationState(
                        property: property,
                        config: animConfig,
                        view: self
                    )
                }
            }
        }
    }
    
    /// Update animation configuration - PURE
    func updateAnimationConfig(_ animatedStyle: [String: Any]) {
        // Stop current animation
        stopPureAnimation()
        
        // Reset properties that are NOT in the new animation config
        resetUnusedProperties(newAnimationConfig: animatedStyle)
        
        // Reconfigure
        configurePureAnimation(animatedStyle)
        
        // Restart
        startPureAnimation()
    }
    
    /// Reset visual properties that are not being used by the new animation
    private func resetUnusedProperties(newAnimationConfig: [String: Any]) {
        // Reset alpha only if opacity is not in the new config
        if !newAnimationConfig.keys.contains("opacity") {
            self.alpha = 1.0
        }
        
        // Reset transform only if no transform properties in new config
        let transformProps = ["scale", "scaleX", "scaleY", "translateX", "translateY", "rotation", "rotationX", "rotationY"]
        let hasTransform = transformProps.contains { newAnimationConfig.keys.contains($0) }
        if !hasTransform {
            self.transform = CGAffineTransform.identity
        }
        
        // Reset width constraint if width is not being animated
        if !newAnimationConfig.keys.contains("width") {
            // Remove any width constraints that might have been set by previous animations
            if let widthConstraint = self.constraints.first(where: { $0.firstAttribute == .width }) {
                self.removeConstraint(widthConstraint)
            }
        }
    }
    
    /// Start pure UI thread animation - NO BRIDGE CALLS
    func startPureAnimation() {
        // 🔥 UI FREEZE FIX: Don't start if globally paused (universal solution)
        if Self.isGloballyPaused() {
            print("⏸️ PURE REANIMATED: Animation start blocked - UI work globally paused")
            return
        }
        
        print("🚀 PURE REANIMATED: startPureAnimation called")
        print("🚀 PURE REANIMATED: isUsingWorklet=\(isUsingWorklet)")
        print("🚀 PURE REANIMATED: workletConfig exists=\(workletConfig != nil)")
        print("🚀 PURE REANIMATED: workletExecutionConfig exists=\(workletExecutionConfig != nil)")
        print("🚀 PURE REANIMATED: currentAnimations count=\(currentAnimations.count)")
        
        if isUsingWorklet {
            // For worklets, we need workletConfig (the serialized function) to exist
            // workletExecutionConfig (the parameters) is optional
            if workletConfig == nil {
                print("⚠️ PURE REANIMATED: No worklet configured - cannot start animation")
            return
        }
            // Text worklets run continuously (no duration), so we always start
            print("🚀 PURE REANIMATED: Starting worklet animation (workletConfig exists)")
            if let worklet = workletConfig {
                let returnType = worklet["returnType"] as? String ?? "dynamic"
                let updateTextChild = workletExecutionConfig?["updateTextChild"] as? Bool ?? false
                print("🚀 PURE REANIMATED: Worklet returnType=\(returnType), updateTextChild=\(updateTextChild)")
            }
        } else if currentAnimations.isEmpty {
            print("⚠️ PURE REANIMATED: No animations configured - cannot start")
            return
        }
        
        // CRITICAL: Apply initial values BEFORE starting animation
        // This ensures the view starts in the correct state
        if !isUsingWorklet {
            for (_, animationState) in currentAnimations {
                // Apply initial value immediately (before animation starts)
                let initialValue = animationState.fromValue
                animationState.applyInitialValue(initialValue, to: self)
            }
        }
        
        print("🚀 PURE REANIMATED: Starting pure UI thread animation")
        
        // Reset animation state
        animationStartTime = CACurrentMediaTime()
        isAnimating = true
        
        print("🚀 PURE REANIMATED: isAnimating set to true, animationStartTime=\(animationStartTime)")
        
        // Fire animation start event
        fireAnimationEvent(eventType: "onAnimationStart")
        
        // Start display link for pure UI thread animation
        startDisplayLink()
    }
    
    /// Stop pure animation
    func stopPureAnimation() {
        guard isAnimating else { return }
        
        print("🛑 PURE REANIMATED: Stopping pure UI thread animation")
        
        isAnimating = false
        stopDisplayLink()
        
        // CRITICAL: When animation stops, ensure layout is synchronized
        // If there's an active transform, we need to ensure the view's frame
        // accounts for it to prevent off-center content
        synchronizeLayoutAfterAnimation()
        
        // Fire animation complete event
        fireAnimationEvent(eventType: "onAnimationComplete")
    }
    
    /// Synchronize layout after animation stops to prevent off-center content
    private func synchronizeLayoutAfterAnimation() {
        // CRITICAL: When animation stops, ensure anchor point is at center
        // This prevents content from appearing off-center when transforms are active
        // The anchor point determines where transforms are applied from
        guard bounds.width > 0 && bounds.height > 0 else {
            // View not laid out yet, skip synchronization
            return
        }
        
        // Store current visual position before changing anchor point
        let currentCenter = center
        let currentBounds = bounds
        
        // Calculate offset if anchor point is not centered
        if layer.anchorPoint != CGPoint(x: 0.5, y: 0.5) {
            let anchorPointOffset = CGPoint(
                x: (layer.anchorPoint.x - 0.5) * bounds.width,
                y: (layer.anchorPoint.y - 0.5) * bounds.height
            )
            
            // Reset anchor point to center
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            
            // Adjust center to maintain visual position
            center = CGPoint(
                x: currentCenter.x + anchorPointOffset.x,
                y: currentCenter.y + anchorPointOffset.y
            )
        } else {
            // Anchor point is already centered, just ensure bounds origin is zero
            if bounds.origin != .zero {
                bounds = CGRect(origin: .zero, size: currentBounds.size)
            }
        }
        
        // Force layout update to ensure everything is synchronized
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    // ============================================================================
    // PURE UI THREAD DISPLAY LINK - NO BRIDGE INTERFERENCE
    // ============================================================================
    
    private func startDisplayLink() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(updatePureAnimationFrame))
        displayLink?.add(to: .main, forMode: .common)
        
        print("🎬 PURE REANIMATED: Started pure UI thread display link")
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        
        print("🎬 PURE REANIMATED: Stopped pure UI thread display link")
    }
    
    @objc private func updatePureAnimationFrame() {
        // 🔥 UI FREEZE FIX: Check pause flag FIRST before any work (universal solution)
        // This prevents any CPU consumption during rapid reconciliation
        if Self.isGloballyPaused() {
            // Immediately stop and don't schedule next frame
            isAnimating = false
            stopDisplayLink()
            return
        }
        
        guard isAnimating else {
            print("⏸️ PURE REANIMATED: Animation stopped, stopping display link")
            stopDisplayLink()
            return
        }
        
        // 🔥 LIFECYCLE FIX: Guard against orphaned worklet callbacks
        // Since worklets run on native UI thread, display link callbacks can fire even after
        // component is replaced. Check if workletConfig is still valid before executing.
        guard isUsingWorklet, workletConfig != nil else {
            // Worklet was cleared (component replaced) but display link callback still fired
            print("🛑 WORKLET: Orphaned callback detected - worklet cleared, stopping")
            isAnimating = false
            stopDisplayLink()
            return
        }
        
        // 🔥 LIFECYCLE FIX: Check if view is still in hierarchy
        // If view was removed from superview (deleted/replaced), stop worklet immediately
        if superview == nil {
            print("🛑 WORKLET: View removed from hierarchy, stopping orphaned worklet")
            isAnimating = false
            workletConfig = nil
            isUsingWorklet = false
            stopDisplayLink()
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - animationStartTime
        let elapsedSeconds = elapsed
        
        // Execute worklet if configured
        if isUsingWorklet, let worklet = workletConfig {
            if frameCount == 0 {
                print("🎬 WORKLET: First frame - elapsed=\(elapsedSeconds), isUsingWorklet=\(isUsingWorklet)")
            }
            frameCount += 1
            if frameCount % 60 == 0 { // Log every second (60fps)
                print("🎬 WORKLET: Frame \(frameCount), elapsed=\(elapsedSeconds)")
            }
            executeWorklet(elapsed: elapsedSeconds, worklet: worklet)
            return
        }
        
        var allAnimationsComplete = true
        var anyAnimationRepeated = false
        
        // Update all animations
        for (_, animationState) in currentAnimations {
            let result = animationState.update(currentTime: currentTime, startTime: animationStartTime)
            
            if result.isActive {
                allAnimationsComplete = false
            }
            if result.didRepeat {
                anyAnimationRepeated = true
            }
        }
        
        // Fire repeat event if any animation repeated
        if anyAnimationRepeated {
            fireAnimationEvent(eventType: "onAnimationRepeat")
            // Reset start time for smooth repeating animations
            animationStartTime = currentTime
        }
        
        // Check if all animations are complete
        if allAnimationsComplete {
            stopPureAnimation()
        }
    }
    
    private func executeWorklet(elapsed: CFTimeInterval, worklet: [String: Any]) {
        // Get worklet configuration
        let returnType = worklet["returnType"] as? String ?? "dynamic"
        let updateTextChild = workletExecutionConfig?["updateTextChild"] as? Bool ?? false
        let isCompiled = worklet["isCompiled"] as? Bool ?? false
        let functionData = worklet["function"] as? [String: Any]
        let workletType = functionData?["type"] as? String ?? "dart_function"
        
        // Only log every 100th execution to reduce CPU usage
        logCounter += 1
        if logCounter % 100 == 0 {
        print("🔄 WORKLET: Executing worklet - returnType=\(returnType), updateTextChild=\(updateTextChild), elapsed=\(elapsed)")
        }
        
        // Check if this is an interpretable worklet (runtime execution - NO REBUILD NEEDED!)
        let ir = functionData?["ir"] as? [String: Any]
        if ir != nil || workletType == "interpretable" {
            if logCounter % 100 == 0 {
            print("🚀 WORKLET: Executing worklet at runtime (no rebuild needed!)")
            }
            
            // For text worklets, use existing pattern matching (works perfectly)
            if returnType == "String" && updateTextChild {
                executeTextWorklet(elapsed: elapsed, worklet: worklet)
                return
            }
            
            // For numeric worklets, interpret IR at runtime (like React Native Reanimated!)
            if let ir = ir {
                if let result = dcflight.WorkletInterpreter.execute(ir, elapsed: elapsed, config: workletExecutionConfig) {
                    print("✅ WORKLET: Successfully executed worklet at runtime")
                    applyWorkletResult(result, returnType: returnType)
                    return
                }
            }
            
            // Fall back to pattern matching if interpretation failed
            print("⚠️ WORKLET: Could not interpret worklet, falling back to pattern matching")
        }
        
        // Check if this is a text-updating worklet (like typewriter)
        if returnType == "String" && updateTextChild {
            print("✅ WORKLET: Detected text worklet, executing typewriter logic")
            executeTextWorklet(elapsed: elapsed, worklet: worklet)
            return
        }
        
        // For numeric worklets, check if we have a source (legacy support)
        guard let functionData = functionData else {
            print("⚠️ WORKLET: Invalid worklet configuration")
            stopPureAnimation()
            return
        }
        
        // Legacy fallback - if we get here, worklet wasn't interpretable
        // This shouldn't happen with proper IR, but handle gracefully
        print("⚠️ WORKLET: No IR found, cannot execute worklet")
            stopPureAnimation()
    }
    
    
    /**
     * Apply worklet result to view based on return type and target property.
     * 
     * 🔥 NOW USES WorkletRuntime API - proper Reanimated-like abstraction!
     * No more component-specific glue code.
     */
    private func applyWorkletResult(_ result: Any?, returnType: String) {
        switch returnType {
        case "double", "int":
            guard let value = result as? NSNumber else { return }
            let floatValue = value.doubleValue
            
            // Get target property from config
            let targetProperty = workletExecutionConfig?["targetProperty"] as? String ?? "scale"
            
            // Get target viewId from config, or use self's viewId
            var targetViewId: Int? = workletExecutionConfig?["targetViewId"] as? Int
            
            // If no targetViewId specified, find self's viewId from ViewRegistry
            if targetViewId == nil {
                for (viewId, viewInfo) in ViewRegistry.shared.registry {
                    if viewInfo.view === self {
                        targetViewId = viewId
                        break
                    }
                }
            }
            
            // Use WorkletRuntime API - clean abstraction!
            if let viewId = targetViewId, let viewProxy = dcflight.WorkletRuntime.getView(viewId) {
                viewProxy.setProperty(targetProperty, floatValue)
            } else {
                print("❌ WORKLET: WorkletRuntime.getView failed for viewId=\(targetViewId?.description ?? "nil")")
            }
            
        case "String":
            // String results are handled by executeTextWorklet
            // This shouldn't be called for String worklets
            break
        default:
            print("🔄 WORKLET: Result type \(returnType) not yet handled")
        }
    }
    
    
    /**
     * Execute a text-returning worklet (e.g., typewriter effect) on UI thread.
     * This runs entirely natively without bridge calls.
     */
    private func executeTextWorklet(elapsed: CFTimeInterval, worklet: [String: Any]) {
        // Get worklet config parameters
        let words = (workletExecutionConfig?["words"] as? [Any])?.compactMap { $0 as? String } ?? []
        let typeSpeed = ((workletExecutionConfig?["typeSpeed"] as? Double) ?? 100.0) / 1000.0 // Convert ms to seconds
        let deleteSpeed = ((workletExecutionConfig?["deleteSpeed"] as? Double) ?? 50.0) / 1000.0
        let pauseDuration = ((workletExecutionConfig?["pauseDuration"] as? Double) ?? 2000.0) / 1000.0
        
        if words.isEmpty {
            print("⚠️ WORKLET: No words provided for typewriter worklet")
            return
        }
        
        if frameCount == 1 {
            print("📝 WORKLET: First execution - elapsed=\(elapsed), words=\(words.count), typeSpeed=\(typeSpeed), deleteSpeed=\(deleteSpeed), pauseDuration=\(pauseDuration)")
        }
        
        // Calculate total time per word cycle
        var totalTimePerCycle: Double = 0.0
        for word in words {
            totalTimePerCycle += (Double(word.count) * typeSpeed) + pauseDuration + (Double(word.count) * deleteSpeed)
        }
        
        // Find current word and position based on elapsed time
        let cycleTime = elapsed.truncatingRemainder(dividingBy: totalTimePerCycle)
        var wordIndex = 0
        var accumulatedTime: Double = 0.0
        
        for (i, word) in words.enumerated() {
            let wordTypeTime = Double(word.count) * typeSpeed
            let wordPauseTime = pauseDuration
            let wordDeleteTime = Double(word.count) * deleteSpeed
            let wordTotalTime = wordTypeTime + wordPauseTime + wordDeleteTime
            
            if cycleTime <= accumulatedTime + wordTotalTime {
                wordIndex = i
                break
            }
            accumulatedTime += wordTotalTime
        }
        
        let currentWord = words[wordIndex]
        let wordStartTime = accumulatedTime
        let wordTypeTime = Double(currentWord.count) * typeSpeed
        let wordPauseTime = pauseDuration
        
        let relativeTime = cycleTime - wordStartTime
        
        let resultText: String
        if relativeTime < wordTypeTime {
            // Typing phase
            let charIndex = min(Int(relativeTime / typeSpeed), currentWord.count)
            resultText = String(currentWord.prefix(charIndex))
        } else if relativeTime < wordTypeTime + wordPauseTime {
            // Pause phase - show full word
            resultText = currentWord
        } else {
            // Deleting phase
            let deleteStartTime = wordTypeTime + wordPauseTime
            let deleteElapsed = relativeTime - deleteStartTime
            let charsToDelete = Int(deleteElapsed / deleteSpeed)
            let remainingChars = max(currentWord.count - charsToDelete, 0)
            resultText = String(currentWord.prefix(remainingChars))
        }
        
        // Log every 10 frames to avoid spam
        if frameCount % 10 == 0 {
            print("📝 WORKLET: Updating text to '\(resultText)' (elapsed=\(elapsed), wordIndex=\(wordIndex), charCount=\(resultText.count))")
        }
        
        // Update child text component directly on UI thread
        // Only update if text actually changed to prevent unnecessary work
        if resultText != lastUpdatedText {
        updateChildText(resultText)
        }
    }
    
    // Guard to prevent infinite loops
    private var isUpdatingText = false
    private var lastUpdatedText: String = ""
    private var consecutiveFailures = 0
    private let maxConsecutiveFailures = 10
    private var isWorkletDisabled = false
    
    /**
     * Update child text component directly from UI thread (zero bridge calls).
     * Uses runtime type checking and method invocation to avoid direct type dependencies.
     */
    private func updateChildText(_ text: String) {
        // 🔥 CRITICAL: Disable worklet if it keeps failing to prevent CPU drain
        if isWorkletDisabled {
            return
        }
        
        // 🔥 CRITICAL: Prevent infinite loops
        if isUpdatingText {
            return // Already updating, skip this call
        }
        
        // Skip if text hasn't changed
        if text == lastUpdatedText {
            return
        }
        
        isUpdatingText = true
        defer { 
            isUpdatingText = false
            // Reset failure counter on success
            if consecutiveFailures > 0 {
                consecutiveFailures = 0
            }
        }
        
        lastUpdatedText = text
        
        // Only log every 100th call to reduce spam
        if arc4random_uniform(100) == 0 {
        print("🔍 WORKLET: updateChildText called with text='\(text)', subviews count=\(subviews.count)")
        }
        
        // Find child text views using runtime type checking
        for subview in subviews {
            // Check if this is a DCFTextView using runtime class name (avoids import issues)
            let className = String(describing: type(of: subview))
            // Only log occasionally to reduce spam
            if arc4random_uniform(100) == 0 {
            print("🔍 WORKLET: Checking subview type: \(className)")
            }
            
            if className.contains("DCFTextView") {
                // Only log occasionally to reduce spam
                if arc4random_uniform(100) == 0 {
                print("✅ WORKLET: Found DCFTextView!")
                }
                // Get the viewId from ViewRegistry or associated object
                var viewId: Int? = nil
                
                // Try to get from ViewRegistry first
                for (id, viewInfo) in ViewRegistry.shared.registry {
                    if viewInfo.view === subview {
                        viewId = id
                        // Only log occasionally to reduce spam
                        if arc4random_uniform(100) == 0 {
                        print("✅ WORKLET: Found viewId=\(id) from ViewRegistry")
                        }
                        break
                    }
                }
                
                // Fallback: try to get from associated object
                if viewId == nil {
                    if let viewIdString = objc_getAssociatedObject(subview, UnsafeRawPointer(bitPattern: "viewId".hashValue)!) as? String {
                        viewId = Int(viewIdString)
                        print("✅ WORKLET: Found viewId=\(viewIdString) from associated object")
                    }
                }
                
                if let viewId = viewId {
                    // Only log occasionally to reduce spam
                    if arc4random_uniform(100) == 0 {
                    print("🔍 WORKLET: Attempting to update text for viewId=\(viewId)")
                    }
                    
                    // 🔥 FIX: Access YogaShadowTree directly since we import dcflight
                    // No need for runtime lookup - we can access it directly!
                    let shadowView = YogaShadowTree.shared.getShadowView(for: viewId)
                    
                    if let shadowView = shadowView {
                                    // Check if it's a DCFTextShadowView and update text property
                                    let shadowClassName = String(describing: type(of: shadowView))
                        // Only log occasionally to reduce spam
                        if arc4random_uniform(100) == 0 {
                                    print("🔍 WORKLET: Shadow view type: \(shadowClassName)")
                        }
                        
                        // 🔥 Use WorkletRuntime API - proper Reanimated-like abstraction
                        // No component-specific glue code needed!
                        if let viewProxy = dcflight.WorkletRuntime.getView(viewId) {
                            viewProxy.setProperty("text", text)
                            consecutiveFailures = 0 // Reset on success
                                        return
                                    } else {
                            consecutiveFailures += 1
                            if consecutiveFailures >= maxConsecutiveFailures {
                                isWorkletDisabled = true
                                print("❌ WORKLET: Disabled worklet after \(maxConsecutiveFailures) consecutive failures (WorkletRuntime.getView failed)")
                                return
                            }
                                }
                            } else {
                        consecutiveFailures += 1
                        if consecutiveFailures >= maxConsecutiveFailures {
                            isWorkletDisabled = true
                            print("❌ WORKLET: Disabled worklet after \(maxConsecutiveFailures) consecutive failures (shadowView is nil)")
                            return
                        }
                        // Only log failure occasionally to reduce spam
                        if arc4random_uniform(100) == 0 {
                            print("⚠️ WORKLET: Could not get shadowView for viewId=\(viewId)")
                        }
                    }
                } else {
                    // Only log failure occasionally to reduce spam
                    if arc4random_uniform(100) == 0 {
                    print("⚠️ WORKLET: Could not find viewId for DCFTextView")
                    }
                }
            }
            
            // Recursively check children (in case text is nested)
            updateChildTextRecursive(subview, text: text)
        }
        
        // Only log failure occasionally to reduce spam
        if arc4random_uniform(100) == 0 {
        print("⚠️ WORKLET: No text view found to update!")
        }
    }
    
    private func updateChildTextRecursive(_ parent: UIView, text: String) {
        for subview in parent.subviews {
            let className = String(describing: type(of: subview))
            if className.contains("DCFTextView") {
                var viewId: Int? = nil
                
                // Try to get from ViewRegistry first
                for (id, viewInfo) in ViewRegistry.shared.registry {
                    if viewInfo.view === subview {
                        viewId = id
                        break
                    }
                }
                
                // Fallback: try to get from associated object
                if viewId == nil {
                    if let viewIdString = objc_getAssociatedObject(subview, UnsafeRawPointer(bitPattern: "viewId".hashValue)!) as? String {
                        viewId = Int(viewIdString)
                    }
                }
                
                if let viewId = viewId {
                    // Use WorkletRuntime API
                    if let viewProxy = dcflight.WorkletRuntime.getView(viewId) {
                        viewProxy.setProperty("text", text)
                                        return
                    }
                }
            }
            updateChildTextRecursive(subview, text: text)
        }
    }
    
    deinit {
        // 🔥 LIFECYCLE FIX: Stop worklet when view is deallocated
        // This ensures worklets don't continue running after component is deleted
        print("🛑 WORKLET: View deallocated, stopping worklet")
        isAnimating = false
        workletConfig = nil
        isUsingWorklet = false
        stopDisplayLink()
    }
    
    override func removeFromSuperview() {
        // 🔥 LIFECYCLE FIX: Stop worklet when view is removed from hierarchy
        // This catches cases where view is deleted but not yet deallocated
        // Since worklets run on UI thread, they don't auto-stop when Dart components are replaced
        print("🛑 WORKLET: View removed from superview, stopping worklet")
        isAnimating = false
        workletConfig = nil
        isUsingWorklet = false
        stopDisplayLink()
        super.removeFromSuperview()
    }
}

// ============================================================================
// PURE ANIMATION STATE - INDIVIDUAL PROPERTY ANIMATION
// ============================================================================

struct PureAnimationResult {
    let isActive: Bool
    let didRepeat: Bool
}

class PureAnimationState {
    let property: String
    let fromValue: CGFloat // Made public for initial value application
    private let toValue: CGFloat
    private let keyframes: [CGFloat]? // Support keyframe animations
    private let duration: TimeInterval
    private let delay: TimeInterval
    private let curve: (Double) -> Double
    private let isRepeating: Bool
    private let repeatCount: Int?
    private let repeatType: String? // 'loop', 'reverse', 'mirror'
    private let damping: Double? // Spring damping
    private let stiffness: Double? // Spring stiffness
    
    private weak var view: UIView?
    private var cycleCount = 0
    private var isReversing = false
    private var cycleStartTime: CFTimeInterval = 0
    
    /// Apply initial value to view (before animation starts)
    func applyInitialValue(_ value: CGFloat, to view: UIView) {
        applyAnimationValue(value, to: view)
    }
    
    init(property: String, config: [String: Any], view: UIView) {
        self.property = property
        self.view = view
        
        // Parse keyframes if present, otherwise use from/to
        if let keyframesArray = config["keyframes"] as? [Double] {
            self.keyframes = keyframesArray.map { CGFloat($0) }
            self.fromValue = self.keyframes!.first ?? 0.0
            self.toValue = self.keyframes!.last ?? 1.0
        } else {
            self.keyframes = nil
            self.fromValue = CGFloat(config["from"] as? Double ?? 0.0)
            self.toValue = CGFloat(config["to"] as? Double ?? 1.0)
        }
        
        let durationMs = config["duration"] as? Int ?? 300
        self.duration = TimeInterval(durationMs) / 1000.0
        
        let delayMs = config["delay"] as? Int ?? 0
        self.delay = TimeInterval(delayMs) / 1000.0
        
        self.isRepeating = config["repeat"] as? Bool ?? false
        self.repeatCount = config["repeatCount"] as? Int
        self.repeatType = config["repeatType"] as? String ?? "loop" // Default to 'loop'
        
        // Parse spring parameters
        self.damping = config["damping"] as? Double
        self.stiffness = config["stiffness"] as? Double
        
        // Parse curve
        let curveString = config["curve"] as? String ?? "easeInOut"
        self.curve = PureAnimationState.getCurveFunction(curveString, damping: damping, stiffness: stiffness)
        
        if let keyframes = keyframes {
            print("🎯 PURE ANIMATION STATE: \(property) keyframes \(keyframes) over \(duration)s")
        } else {
            print("🎯 PURE ANIMATION STATE: \(property) from \(fromValue) to \(toValue) over \(duration)s")
        }
    }
    
    /// Update animation state - PURE UI THREAD
    func update(currentTime: CFTimeInterval, startTime: CFTimeInterval) -> PureAnimationResult {
        guard let view = view else {
            return PureAnimationResult(isActive: false, didRepeat: false)
        }
        
        // Initialize cycle start time on first update
        if cycleStartTime == 0 {
            cycleStartTime = startTime
        }
        
        let elapsed = currentTime - cycleStartTime - delay
        
        // Check if animation hasn't started yet (delay)
        if elapsed < 0 {
            return PureAnimationResult(isActive: true, didRepeat: false)
        }
        
        let progress = min(1.0, elapsed / duration)
        let easedProgress = curve(progress)
        
        // Calculate current value - support keyframes
        let currentValue: CGFloat
        if let keyframes = keyframes {
            // Keyframe animation: interpolate between keyframes
            let keyframeCount = keyframes.count
            if keyframeCount == 1 {
                currentValue = keyframes[0]
            } else {
                let segmentProgress = progress * Double(keyframeCount - 1)
                let segmentIndex = Int(segmentProgress)
                let segmentT = segmentProgress - Double(segmentIndex)
                
                if segmentIndex >= keyframeCount - 1 {
                    currentValue = keyframes[keyframeCount - 1]
                } else {
                    let fromKeyframe = keyframes[segmentIndex]
                    let toKeyframe = keyframes[segmentIndex + 1]
                    currentValue = fromKeyframe + (toKeyframe - fromKeyframe) * CGFloat(segmentT)
                }
            }
        } else {
            // Standard from/to animation
            let currentFromValue = isReversing ? toValue : fromValue
            let currentToValue = isReversing ? fromValue : toValue
            currentValue = currentFromValue + (currentToValue - currentFromValue) * CGFloat(easedProgress)
        }
        
        // Apply to view
        applyAnimationValue(currentValue, to: view)
        
        // Check if cycle is complete
        if progress >= 1.0 {
            if isRepeating {
                let shouldContinue: Bool
                
                if let maxRepeats = repeatCount {
                    shouldContinue = cycleCount < maxRepeats
                } else {
                    shouldContinue = true // Infinite repeat
                }
                
                if shouldContinue {
                    cycleCount += 1
                    
                    // Handle different repeat types
                    let repeatTypeValue = repeatType ?? "loop"
                    switch repeatTypeValue {
                    case "reverse", "mirror":
                        // Ping-pong: reverse direction
                        isReversing.toggle()
                    case "loop":
                        // Loop: restart from beginning
                        isReversing = false
                    default:
                        // Default to loop behavior
                        isReversing = false
                    }
                    
                    // Reset cycle start time for smooth repeat
                    cycleStartTime = currentTime
                    return PureAnimationResult(isActive: true, didRepeat: true)
                }
            }
            
            // Animation complete
            return PureAnimationResult(isActive: false, didRepeat: false)
        }
        
        // Animation continuing
        return PureAnimationResult(isActive: true, didRepeat: false)
    }
    
    /// Apply animation value to view property - PURE UI THREAD
    private func applyAnimationValue(_ value: CGFloat, to view: UIView) {
        switch property {
        // Transform properties
        case "scale":
            view.transform = CGAffineTransform(scaleX: value, y: value)
        case "scaleX":
            view.transform = CGAffineTransform(scaleX: value, y: view.transform.d)
        case "scaleY":
            view.transform = CGAffineTransform(scaleX: view.transform.a, y: value)
        case "translateX":
            view.transform = CGAffineTransform(translationX: value, y: view.transform.ty)
        case "translateY":
            view.transform = CGAffineTransform(translationX: view.transform.tx, y: value)
        case "rotation":
            view.transform = CGAffineTransform(rotationAngle: value)
        case "rotationX":
            var transform = view.layer.transform
            transform = CATransform3DRotate(transform, value, 1, 0, 0)
            view.layer.transform = transform
        case "rotationY":
            var transform = view.layer.transform
            transform = CATransform3DRotate(transform, value, 0, 1, 0)
            view.layer.transform = transform
        case "rotationZ":
            var transform = view.layer.transform
            transform = CATransform3DRotate(transform, value, 0, 0, 1)
            view.layer.transform = transform
        case "translateZ":
            var transform = view.layer.transform
            transform = CATransform3DTranslate(transform, 0, 0, value)
            view.layer.transform = transform
            
        // Opacity
        case "opacity":
            view.alpha = value
            
        // Background color (assuming value is a hue for demo)
        case "backgroundColor":
            view.backgroundColor = UIColor(hue: value, saturation: 1.0, brightness: 1.0, alpha: 1.0)
            
        // Layout properties
        case "width":
            var frame = view.frame
            frame.size.width = value
            view.frame = frame
        case "height":
            var frame = view.frame
            frame.size.height = value
            view.frame = frame
        case "top":
            var frame = view.frame
            frame.origin.y = value
            view.frame = frame
        case "left":
            var frame = view.frame
            frame.origin.x = value
            view.frame = frame
            
        default:
            print("⚠️ PURE REANIMATED: Unknown animation property: \(property)")
        }
    }
    
    /// Get easing curve function
    static func getCurveFunction(_ curveString: String, damping: Double? = nil, stiffness: Double? = nil) -> (Double) -> Double {
        switch curveString.lowercased() {
        case "linear":
            return { $0 }
        case "easein":
            return { $0 * $0 }
        case "easeout":
            return { 1 - (1 - $0) * (1 - $0) }
        case "easeinout":
            return { $0 < 0.5 ? 2 * $0 * $0 : 1 - 2 * (1 - $0) * (1 - $0) }
        case "spring":
            return { t in springCurve(t, damping: damping, stiffness: stiffness) }
        default:
            return { $0 < 0.5 ? 2 * $0 * $0 : 1 - 2 * (1 - $0) * (1 - $0) } // Default to easeInOut
        }
    }
    
    /// Spring curve implementation with configurable damping and stiffness
    static func springCurve(_ t: Double, damping: Double? = nil, stiffness: Double? = nil) -> Double {
        let dampingValue = damping ?? 0.8
        let stiffnessValue = stiffness ?? 300.0
        let frequency = sqrt(stiffnessValue / 1.0) // Mass = 1.0
        
        if t == 0 || t == 1 {
            return t
        }
        
        let omega = frequency * 2 * Double.pi
        let exponential = pow(2, -dampingValue * t)
        let sine = sin((omega * t) + acos(dampingValue))
        
        return 1 - exponential * sine
    }
}

// ============================================================================
// PURE ANIMATION UTILITIES
// ============================================================================

extension UIView {
    /// Reset all animations to initial state - PURE
    func resetPureAnimations() {
        layer.removeAllAnimations()
        transform = CGAffineTransform.identity
        layer.transform = CATransform3DIdentity
        alpha = 1.0
    }
}