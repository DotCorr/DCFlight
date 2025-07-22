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
        // Clean up existing controller if it exists
        if let existingController = activeAnimations[controllerId] {
            print("🔄 DCFAnimationEngine: Replacing existing controller \(controllerId)")
        }
        
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
        
        // Update all active animations
        for (controllerId, controller) in activeAnimations {
            if controller.updateFrame(currentTime: currentTime) {
                hasActiveAnimations = true
            } else {
                // Animation finished and not repeating - remove it
                print("✅ DCFAnimationEngine: Animation \(controllerId) completed")
            }
        }
        
        // Clean up completed animations
        activeAnimations = activeAnimations.filter { _, controller in
            controller.updateFrame(currentTime: currentTime)
        }
        
        // Stop display link if no animations
        if activeAnimations.isEmpty && isRunning {
            displayLink?.invalidate()
            displayLink = nil
            isRunning = false
            print("🛑 DCFAnimationEngine: Stopped UI thread animation loop")
        }
    }
    
    // Clean up controller when view is removed
    func removeController(_ controllerId: String) {
        if let controller = activeAnimations[controllerId] {
            // Stop the animation
            controller.executeCommand(["type": "stop"])
        }
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
            view.resetToInitialState()
        default:
            break
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
    private var startTime: CFTimeInterval
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
            self.duration = 0.3
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
        
        print("🎯 DirectAnimation: Created with duration \(duration)s, repeat: \(repeatAnimation)")
        
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
            
            // Handle repeat - SIMPLE AND WORKING
            if repeatAnimation {
                print("🔄 DirectAnimation: Restarting animation cycle")
                
                // Reset start time for new cycle
                self.startTime = currentTime
                
                // Reset view to initial state
                resetViewToInitial(view: view)
                
                // Small delay to make the reset visible
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.fireAnimationStartEvent(view: view)
                }
                
                return true // Continue for next cycle
            }
            
            return false // Animation complete
        }
        
        return true // Continue current cycle
    }
    
    private func resetViewToInitial(view: AnimatedView) {
        // Reset to identity transform
        view.transform = CGAffineTransform.identity
        view.alpha = 1.0
        
        print("🔄 DirectAnimation: Reset view to initial state")
    }
    
    private func applyCurrentValues(view: AnimatedView, progress: Double) {
        var transform = CGAffineTransform.identity
        var hasTransform = false
        
        // Apply scale
        if let toScale = toValues["scale"] {
            let currentScale = 1.0 + (toScale - 1.0) * CGFloat(progress)
            transform = transform.scaledBy(x: currentScale, y: currentScale)
            hasTransform = true
        }
        
        // Apply translation
        if let toTranslateX = toValues["translateX"] {
            let currentTranslateX = toTranslateX * CGFloat(progress)
            transform = transform.translatedBy(x: currentTranslateX, y: 0)
            hasTransform = true
        }
        
        if let toTranslateY = toValues["translateY"] {
            let currentTranslateY = toTranslateY * CGFloat(progress)
            transform = transform.translatedBy(x: 0, y: currentTranslateY)
            hasTransform = true
        }
        
        // Apply rotation
        if let toRotation = toValues["rotation"] {
            let currentRotation = toRotation * CGFloat(progress)
            transform = transform.rotated(by: currentRotation)
            hasTransform = true
        }
        
        // Apply transform
        if hasTransform {
            view.transform = transform
        }
        
        // Apply opacity
        if let toOpacity = toValues["opacity"] {
            let currentOpacity = 1.0 + (toOpacity - 1.0) * CGFloat(progress)
            view.alpha = currentOpacity
        }
    }
    
    private func fireAnimationStartEvent(view: AnimatedView) {
        propagateEvent(on: view, eventName: "onAnimationStart", data: [:])
    }
    
    private func fireAnimationEndEvent(view: AnimatedView) {
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
            return { $0 < 0.5 ? 2 * $0 * $0 : 1 - 2 * (1 - $0) * (1 - $0) }
        }
    }
}
