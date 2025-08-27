/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

// ============================================================================
// PURE REANIMATED COMPONENT - ZERO BRIDGE CALLS DURING ANIMATION
// ============================================================================

class DCFAnimatedViewComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let reanimatedView = PureReanimatedView()
        
        // Configure everything from props immediately - NO BRIDGE CALLS
        if let isPure = props["isPureReanimated"] as? Bool, isPure {
            print("🎯 PURE REANIMATED: Creating view with pure UI thread configuration")
            
            // Configure animation entirely from props
            if let animatedStyle = props["animatedStyle"] as? [String: Any] {
                reanimatedView.configurePureAnimation(animatedStyle)
            }
            
            // Auto-start if configured
            let autoStart = props["autoStart"] as? Bool ?? true
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
        
        return reanimatedView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let reanimatedView = view as? PureReanimatedView else { return false }
        
        // ✅ PURE: Only update if animation style changes - NO BRIDGE CALLS
        if let animatedStyle = props["animatedStyle"] as? [String: Any] {
            reanimatedView.updateAnimationConfig(animatedStyle)
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
        view.frame = CGRect(
            x: CGFloat(layout.left),
            y: CGFloat(layout.top),
            width: CGFloat(layout.width),
            height: CGFloat(layout.height)
        )
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}

// ============================================================================
// PURE REANIMATED VIEW - SELF-CONTAINED UI THREAD ANIMATION
// ============================================================================

class PureReanimatedView: UIView {
    
    // Animation configuration
    private var animationConfig: [String: Any] = [:]
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0
    private var isAnimating = false
    
    // Animation state
    private var currentAnimations: [String: PureAnimationState] = [:]
    
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
    // PURE ANIMATION CONFIGURATION - NO BRIDGE CALLS
    // ============================================================================
    
    /// Configure animation entirely from props - PURE
    func configurePureAnimation(_ animatedStyle: [String: Any]) {
        print("🎯 PURE REANIMATED: Configuring animation from props")
        self.animationConfig = animatedStyle
        
        // Parse animation configurations
        currentAnimations.removeAll()
        
        for (property, config) in animatedStyle {
            if let animConfig = config as? [String: Any] {
                currentAnimations[property] = PureAnimationState(
                    property: property,
                    config: animConfig,
                    view: self
                )
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
        guard !currentAnimations.isEmpty else {
            print("⚠️ PURE REANIMATED: No animations configured")
            return
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
        
        // Fire animation complete event
        fireAnimationEvent(eventType: "onAnimationComplete")
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
        }
        
        // Check if all animations are complete
        if allAnimationsComplete {
            stopPureAnimation()
        }
    }
    
    // ============================================================================
    // PURE EVENT SYSTEM - MINIMAL BRIDGE USAGE
    // ============================================================================
    
    private func fireAnimationEvent(eventType: String) {
        guard let nodeId = nodeId else { return }
        
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
    private let fromValue: CGFloat
    private let toValue: CGFloat
    private let duration: TimeInterval
    private let delay: TimeInterval
    private let curve: (Double) -> Double
    private let isRepeating: Bool
    private let repeatCount: Int?
    
    private weak var view: UIView?
    private var cycleCount = 0
    private var isReversing = false
    
    init(property: String, config: [String: Any], view: UIView) {
        self.property = property
        self.view = view
        
        // Parse configuration
        self.fromValue = CGFloat(config["from"] as? Double ?? 0.0)
        self.toValue = CGFloat(config["to"] as? Double ?? 1.0)
        
        let durationMs = config["duration"] as? Int ?? 300
        self.duration = TimeInterval(durationMs) / 1000.0
        
        let delayMs = config["delay"] as? Int ?? 0
        self.delay = TimeInterval(delayMs) / 1000.0
        
        self.isRepeating = config["repeat"] as? Bool ?? false
        self.repeatCount = config["repeatCount"] as? Int
        
        // Parse curve
        let curveString = config["curve"] as? String ?? "easeInOut"
        self.curve = PureAnimationState.getCurveFunction(curveString)
        
        print("🎯 PURE ANIMATION STATE: \(property) from \(fromValue) to \(toValue) over \(duration)s")
    }
    
    /// Update animation state - PURE UI THREAD
    func update(currentTime: CFTimeInterval, startTime: CFTimeInterval) -> PureAnimationResult {
        guard let view = view else {
            return PureAnimationResult(isActive: false, didRepeat: false)
        }
        
        let elapsed = currentTime - startTime - delay
        
        // Check if animation hasn't started yet (delay)
        if elapsed < 0 {
            return PureAnimationResult(isActive: true, didRepeat: false)
        }
        
        let progress = min(1.0, elapsed / duration)
        let easedProgress = curve(progress)
        
        // Calculate current value
        let currentFromValue = isReversing ? toValue : fromValue
        let currentToValue = isReversing ? fromValue : toValue
        let currentValue = currentFromValue + (currentToValue - currentFromValue) * CGFloat(easedProgress)
        
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
                    isReversing.toggle() // Reverse for ping-pong effect
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
            view.layer.transform = CATransform3DMakeRotation(value, 1, 0, 0)
        case "rotationY":
            view.layer.transform = CATransform3DMakeRotation(value, 0, 1, 0)
            
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
    static func getCurveFunction(_ curveString: String) -> (Double) -> Double {
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
            return springCurve
        default:
            return { $0 < 0.5 ? 2 * $0 * $0 : 1 - 2 * (1 - $0) * (1 - $0) } // Default to easeInOut
        }
    }
    
    /// Spring curve implementation
    static func springCurve(_ t: Double) -> Double {
        let damping = 0.8
        let frequency = 8.0
        
        if t == 0 || t == 1 {
            return t
        }
        
        let omega = frequency * 2 * Double.pi
        let exponential = pow(2, -damping * t)
        let sine = sin((omega * t) + acos(damping))
        
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
