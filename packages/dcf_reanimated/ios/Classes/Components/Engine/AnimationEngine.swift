/*
 * DCF Reanimated Swift Implementation
 * Copyright (c) Dotcorr Studio. and affiliates.
 * Licensed under the MIT license
 */

import UIKit
import dcflight

// ============================================================================
// ANIMATION ENGINE - UI Thread CADisplayLink System
// ============================================================================

public class DCFAnimationEngine {
    static let shared = DCFAnimationEngine()
    
    private var displayLink: CADisplayLink?
    private var activeAnimations: [String: AnimationController] = [:]
    private var isRunning = false
    
    private init() {}
    
    // Register a view for UI thread animation
    func registerAnimationController(_ controllerId: String, view: AnimatedView) {
        activeAnimations[controllerId] = AnimationController(view: view)
        startDisplayLinkIfNeeded()
        print("🎬 DCFAnimationEngine: Registered controller \(controllerId)")
    }
    
    // Execute command on UI thread
    func executeCommand(_ controllerId: String, command: [String: Any]) {
        guard let controller = activeAnimations[controllerId] else { 
            print("⚠️ DCFAnimationEngine: Controller \(controllerId) not found")
            return 
        }
        controller.executeCommand(command)
    }
    
    private func startDisplayLinkIfNeeded() {
        guard !isRunning else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
        isRunning = true
        print("🚀 DCFAnimationEngine: Started UI thread animation loop")
    }
    
    @objc private func updateFrame() {
        let currentTime = CACurrentMediaTime()
        var hasActiveAnimations = false
        
        for (_, controller) in activeAnimations {
            if controller.updateFrame(currentTime: currentTime) {
                hasActiveAnimations = true
            }
        }
        
        // Stop display link if no animations
        if !hasActiveAnimations && isRunning {
            displayLink?.invalidate()
            displayLink = nil
            isRunning = false
            print("🛑 DCFAnimationEngine: Stopped UI thread animation loop")
        }
    }
    
    // Clean up controller
    func removeController(_ controllerId: String) {
        activeAnimations.removeValue(forKey: controllerId)
        print("🗑️ DCFAnimationEngine: Removed controller \(controllerId)")
    }
}

// ============================================================================
// ANIMATION CONTROLLER - Per-View Animation State
// ============================================================================

class AnimationController {
    private weak var view: AnimatedView?
    private var currentAnimation: DirectAnimation?
    
    init(view: AnimatedView) {
        self.view = view
    }
    
    func executeCommand(_ command: [String: Any]) {
        guard let view = view else { return }
        
        let commandType = command["type"] as? String ?? ""
        
        switch commandType {
        case "animate":
            startDirectAnimation(command)
        case "reset":
            view.resetToInitialState()
            currentAnimation = nil
        case "pause":
            currentAnimation?.isPaused = true
        case "resume":
            currentAnimation?.isPaused = false
        case "stop":
            currentAnimation = nil
        case "sequence":
            handleSequenceCommand(command)
        case "parallel":
            handleParallelCommand(command)
        default:
            print("⚠️ AnimationController: Unknown command type: \(commandType)")
        }
    }
    
    private func startDirectAnimation(_ command: [String: Any]) {
        guard let view = view else { return }
        
        // Stop any existing animation
        currentAnimation = nil
        
        // Create new direct animation
        currentAnimation = DirectAnimation(
            view: view,
            command: command,
            startTime: CACurrentMediaTime()
        )
        
        print("🎬 AnimationController: Started direct UI thread animation")
    }
    
    private func handleSequenceCommand(_ command: [String: Any]) {
        // TODO: Implement sequence animation handling
        print("📋 AnimationController: Sequence animations not yet implemented")
    }
    
    private func handleParallelCommand(_ command: [String: Any]) {
        // TODO: Implement parallel animation handling
        print("⚡ AnimationController: Parallel animations not yet implemented")
    }
    
    // Returns true if animation is active
    func updateFrame(currentTime: CFTimeInterval) -> Bool {
        guard let animation = currentAnimation else { return false }
        return animation.updateFrame(currentTime: currentTime)
    }
}

// ============================================================================
// DIRECT ANIMATION - Frame-by-Frame UI Thread Animation
// ============================================================================

class DirectAnimation {
    private weak var view: AnimatedView?
    private let startTime: CFTimeInterval
    private let duration: TimeInterval
    private let curve: (Double) -> Double
    private let fromValues: [String: CGFloat]
    private let toValues: [String: CGFloat]
    private let repeatAnimation: Bool
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
        
        // Extract repeat flag
        self.repeatAnimation = command["repeat"] as? Bool ?? false
        
        // Convert curve string to function
        let curveString = command["curve"] as? String ?? "easeInOut"
        self.curve = Self.getCurveFunction(curveString)
        
        // Capture current values as starting point
        self.fromValues = Self.captureCurrentValues(view)
        
        // Extract target values
        self.toValues = Self.extractTargetValues(command)
        
        print("🎯 DirectAnimation: Created with duration \(duration)s, targets: \(toValues)")
        
        // Fire animation start event
        fireAnimationStartEvent(view: view)
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
            
            // Handle repeat
            if repeatAnimation {
                // Reset and restart (simplified repeat logic)
                view.resetToInitialState()
                return true // Continue animation loop
            }
            
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
    
    private func fireAnimationStartEvent(view: AnimatedView) {
        propagateEvent(on: view, eventName: "onAnimationStart", data: [:])
    }
    
    private func fireAnimationEndEvent(view: AnimatedView) {
        propagateEvent(on: view, eventName: "onAnimationEnd", data: [:])
    }
    
    // MARK: - Static Helper Methods
    
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
        case "elasticout":
            return { sin(-13.0 * (.pi/2) * ($0 + 1)) * pow(2, -10 * $0) + 1 }
        case "bounceout":
            return { value in
                if value < 1/2.75 {
                    return 7.5625 * value * value
                } else if value < 2/2.75 {
                    let adjustedValue = value - 1.5/2.75
                    return 7.5625 * adjustedValue * adjustedValue + 0.75
                } else if value < 2.5/2.75 {
                    let adjustedValue = value - 2.25/2.75
                    return 7.5625 * adjustedValue * adjustedValue + 0.9375
                } else {
                    let adjustedValue = value - 2.625/2.75
                    return 7.5625 * adjustedValue * adjustedValue + 0.984375
                }
            }
        default:
            return { $0 < 0.5 ? 2 * $0 * $0 : 1 - 2 * (1 - $0) * (1 - $0) } // Default to easeInOut
        }
    }
}

