/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight
 

class DCFAnimatedViewComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let reanimatedView = PureReanimatedView()
        
        // Configure everything from props immediately - NO BRIDGE CALLS
        if let isPure = props["isPureReanimated"] as? Bool, isPure {
            print("🎯 PURE REANIMATED: Creating view with pure UI thread configuration")
            
            // Configure worklet if provided (takes precedence)
            if let workletData = props["worklet"] as? [String: Any] {
                let workletConfig = props["workletConfig"] as? [String: Any]
                reanimatedView.configureWorklet(workletData, workletConfig)
            } else if let animatedStyle = props["animatedStyle"] as? [String: Any] {
                // Fall back to animated style
                reanimatedView.configurePureAnimation(animatedStyle)
            }
            
            // Auto-start if configured (default: false for explicit control)
            let autoStart = props["autoStart"] as? Bool ?? false
            let startDelay = props["startDelay"] as? Int ?? 0
            
            if autoStart {
                if startDelay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(startDelay)) {
                        reanimatedView.startPureAnimation()
                    }
                } else {
                    reanimatedView.startPureAnimation()
                }
            }
        }
        
        // Apply styles
        reanimatedView.applyStyles(props: props)
        
        // Setup viewport detection if callbacks are registered (low-level API)
        let hasViewportCallbacks = props["onViewportEnter"] != nil || props["onViewportLeave"] != nil
        if hasViewportCallbacks {
            let viewportData = props["viewport"] as? [String: Any]
            let config = ViewportConfig(
                once: viewportData?["once"] as? Bool ?? false,
                amount: viewportData?["amount"] as? Double
            )
            DispatchQueue.main.async {
                DCFViewportObserver.shared.observe(reanimatedView, config: config)
            }
        }
        
        return reanimatedView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let reanimatedView = view as? PureReanimatedView else { return false }
        
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
        
        // Handle viewport detection updates (low-level API)
        let hasViewportCallbacks = props["onViewportEnter"] != nil || props["onViewportLeave"] != nil
        if hasViewportCallbacks {
            let viewportData = props["viewport"] as? [String: Any]
            let config = ViewportConfig(
                once: viewportData?["once"] as? Bool ?? false,
                amount: viewportData?["amount"] as? Double
            )
            DCFViewportObserver.shared.observe(view, config: config)
        } else {
            DCFViewportObserver.shared.unobserve(view)
        }
        
        view.applyStyles(props: props)
        return true
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
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
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

// ============================================================================
// PURE REANIMATED VIEW - SELF-CONTAINED UI THREAD ANIMATION
// ============================================================================

class PureReanimatedView: UIView, DCFLayoutIndependent {
    
    // Animation configuration
    private var animationConfig: [String: Any] = [:]
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0
    var isAnimating = false
    
    // MARK: - DCFLayoutIndependent Protocol
    
    /// Opt-out of layout updates when animating to prevent stuttering
    /// This makes the view layout-independent during animation
    var shouldSkipLayout: Bool {
        return isAnimating
    }
    
    // Animation state
    private var currentAnimations: [String: PureAnimationState] = [:]
    
    // Worklet configuration
    private var workletConfig: [String: Any]?
    private var workletExecutionConfig: [String: Any]?
    private var isUsingWorklet = false
    
    // Identifiers for callbacks
    var nodeId: String?
    
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
        self.workletConfig = workletData
        self.workletExecutionConfig = config
        self.isUsingWorklet = true
        
        // Clear animation config when using worklet
        currentAnimations.removeAll()
    }
    
    func updateWorklet(_ workletData: [String: Any], _ config: [String: Any]?) {
        stopPureAnimation()
        configureWorklet(workletData, config)
        startPureAnimation()
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
        if isUsingWorklet && workletConfig == nil {
            print("⚠️ PURE REANIMATED: No worklet configured")
            return
        }
        
        if !isUsingWorklet && currentAnimations.isEmpty {
            print("⚠️ PURE REANIMATED: No animations configured")
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
        guard isAnimating else {
            stopDisplayLink()
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - animationStartTime
        let elapsedSeconds = elapsed
        
        // Execute worklet if configured
        if isUsingWorklet, let worklet = workletConfig {
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
        guard let functionData = worklet["function"] as? [String: Any] else {
            print("⚠️ WORKLET: Invalid worklet configuration")
            stopPureAnimation()
            return
        }
        
        // Get duration from config or use default
        let duration = (workletExecutionConfig?["duration"] as? Double ?? 2000.0) / 1000.0
        
        // Check if worklet should complete
        if elapsed >= duration {
            stopPureAnimation()
            return
        }
        
        // Execute worklet (simplified - in production would use compiled code or interpreter)
        // For now, this is a placeholder - the actual worklet execution would happen here
        // The worklet function would be properly executed based on the serialized function data
        
        // Apply worklet result to view (simplified example)
        // In production, the worklet function would be properly executed
        if let result = functionData["result"] as? Double {
            // Apply result to view properties based on worklet configuration
            // This is a simplified example
        }
        
        // Note: In production, the worklet function would be properly executed
        // This would involve either:
        // 1. Compiling the worklet to native code
        // 2. Using an interpreter to execute the serialized function
        // 3. Using a JIT compiler for dynamic execution
    }
    
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
    
    deinit {
        stopDisplayLink()
        print("🗑️ PURE REANIMATED: View deallocated")
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