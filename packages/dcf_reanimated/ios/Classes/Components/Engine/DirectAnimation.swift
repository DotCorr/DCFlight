import dcflight

class DirectAnimation {
    private weak var view: AnimatedView?
    private let startTime: CFTimeInterval
    private let duration: TimeInterval
    private let curve: (Double) -> Double
    private let fromValues: [String: CGFloat]
    private let toValues: [String: CGFloat]
    var isPaused = false
    private var pausedTime: CFTimeInterval = 0
    
    init(view: AnimatedView, command: [String: Any], startTime: CFTimeInterval) {
        self.view = view
        self.startTime = startTime
        
        // Extract animation parameters
        if let durationMs = command["duration"] as? Int {
            self.duration = TimeInterval(durationMs) / 1000.0
        } else if let durationSec = command["duration"] as? Double {
            self.duration = durationSec / 1000.0
        } else {
            self.duration = 0.3 // Default
        }
        
        // Convert curve string to function
        let curveString = command["curve"] as? String ?? "easeInOut"
        self.curve = Self.getCurveFunction(curveString)
        
        // Capture current values as starting point
        self.fromValues = Self.captureCurrentValues(view)
        
        // Extract target values
        self.toValues = Self.extractTargetValues(command)
        
        print("🎯 DirectAnimation: Created with duration \(duration)s, targets: \(toValues)")
    }
    
    // Returns true if animation should continue
    func updateFrame(currentTime: CFTimeInterval) -> Bool {
        guard let view = view, !isPaused else { return true }
        
        let elapsed = currentTime - startTime - pausedTime
        let progress = min(1.0, elapsed / duration)
        let easedProgress = curve(progress)
        
        // Calculate and apply current values
        applyCurrentValues(view: view, progress: easedProgress)
        
        // Check if animation is complete
        if progress >= 1.0 {
            // Trigger completion callback
            fireAnimationEndEvent(view: view)
            return false // Animation complete
        }
        
        return true // Continue animation
    }
    
    private func applyCurrentValues(view: AnimatedView, progress: Double) {
        var transform = CGAffineTransform.identity
        var hasTransform = false
        
        // Apply scale
        if let fromScale = fromValues["scale"], let toScale = toValues["scale"] {
            let currentScale = fromScale + (toScale - fromScale) * CGFloat(progress)
            transform = transform.scaledBy(x: currentScale, y: currentScale)
            hasTransform = true
        }
        
        // Apply translation
        let translateX = interpolateValue("translateX", progress: progress) ?? 0
        let translateY = interpolateValue("translateY", progress: progress) ?? 0
        if translateX != 0 || translateY != 0 {
            transform = transform.translatedBy(x: translateX, y: translateY)
            hasTransform = true
        }
        
        // Apply rotation
        if let rotation = interpolateValue("rotation", progress: progress) {
            transform = transform.rotated(by: rotation)
            hasTransform = true
        }
        
        // Apply transform
        if hasTransform {
            view.transform = transform
        }
        
        // Apply opacity
        if let opacity = interpolateValue("opacity", progress: progress) {
            view.alpha = opacity
        }
    }
    
    private func interpolateValue(_ key: String, progress: Double) -> CGFloat? {
        guard let fromValue = fromValues[key], let toValue = toValues[key] else { return nil }
        return fromValue + (toValue - fromValue) * CGFloat(progress)
    }
    
    private func fireAnimationEndEvent(view: AnimatedView) {
        // Use your existing global event system
        propagateEvent(on: view, eventName: "onAnimationEnd", data: [:])
    }
    
    // Static helper methods
    static func captureCurrentValues(_ view: AnimatedView) -> [String: CGFloat] {
        var values: [String: CGFloat] = [:]
        
        // Capture current transform components
        let transform = view.transform
        values["scale"] = sqrt(transform.a * transform.a + transform.c * transform.c)
        values["translateX"] = transform.tx
        values["translateY"] = transform.ty
        values["rotation"] = atan2(transform.b, transform.a)
        
        // Capture opacity
        values["opacity"] = view.alpha
        
        return values
    }
    
    static func extractTargetValues(_ command: [String: Any]) -> [String: CGFloat] {
        var targets: [String: CGFloat] = [:]
        
        if let toScale = command["toScale"] as? Double {
            targets["scale"] = CGFloat(toScale)
        }
        if let toOpacity = command["toOpacity"] as? Double {
            targets["opacity"] = CGFloat(toOpacity)
        }
        if let toTranslateX = command["toTranslateX"] as? Double {
            targets["translateX"] = CGFloat(toTranslateX)
        }
        if let toTranslateY = command["toTranslateY"] as? Double {
            targets["translateY"] = CGFloat(toTranslateY)
        }
        if let toRotation = command["toRotation"] as? Double {
            targets["rotation"] = CGFloat(toRotation)
        }
        
        return targets
    }
    
    static func getCurveFunction(_ curve: String) -> (Double) -> Double {
        switch curve.lowercased() {
        case "linear":
            return { $0 }
        case "easein":
            return { $0 * $0 }
        case "easeout":
            return { 1 - (1 - $0) * (1 - $0) }
        case "easeinout":
            return { $0 < 0.5 ? 2 * $0 * $0 : 1 - 2 * (1 - $0) * (1 - $0) }
        default:
            return { $0 < 0.5 ? 2 * $0 * $0 : 1 - 2 * (1 - $0) * (1 - $0) } // Default to easeInOut
        }
    }
}
