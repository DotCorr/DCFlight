/*
 * DCF Reanimated Swift Implementation
 * Copyright (c) Dotcorr Studio. and affiliates.
 * Licensed under the MIT license
 */

import UIKit
import dcflight

// ============================================================================
// ANIMATED VIEW CLASS
// ============================================================================

public class AnimatedView: UIView {
    private var controllerId: String?
    
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
    
    func setControllerId(_ id: String) {
        self.controllerId = id
    }
    
    func resetToInitialState() {
        print("🔄 AnimatedView: Resetting to initial state")
        layer.removeAllAnimations()
        transform = CGAffineTransform.identity
        alpha = 1.0
    }
    
    deinit {
        if let controllerId = controllerId {
            DCFAnimationEngine.shared.removeController(controllerId)
            print("🗑️ AnimatedView: Cleaned up controller \(controllerId)")
        }
    }
}

// ============================================================================
// ANIMATION GROUP
// ============================================================================

public class AnimationGroup {
    let id: String
    let debugName: String
    let autoStart: Bool
    private var controllerIds: Set<String> = []
    
    init(id: String, autoStart: Bool = true, debugName: String) {
        self.id = id
        self.autoStart = autoStart
        self.debugName = debugName
    }
    
    func addController(_ controllerId: String) {
        controllerIds.insert(controllerId)
        print("🔗 AnimationGroup[\(debugName)]: Added controller \(controllerId) (total: \(controllerIds.count))")
    }
    
    func removeController(_ controllerId: String) {
        controllerIds.remove(controllerId)
        print("🗑️ AnimationGroup[\(debugName)]: Removed controller \(controllerId) (remaining: \(controllerIds.count))")
    }
    
    func getAllControllerIds() -> Set<String> {
        return controllerIds
    }
    
    func isEmpty() -> Bool {
        return controllerIds.isEmpty
    }
}

// ============================================================================
// ANIMATION ENGINE - FIXED VERSION
// ============================================================================

public class DCFAnimationEngine {
    static let shared = DCFAnimationEngine()
    
    private var displayLink: CADisplayLink?
    private var activeAnimations: [String: AnimationController] = [:]
    private var animationGroups: [String: AnimationGroup] = [:]
    private var pendingGroupRegistrations: [String: [String]] = [:] // NEW: Handle timing issues
    private var isRunning = false
    
    private init() {}
    
    // MARK: - Group Management - FIXED
    
    func registerAnimationGroup(_ groupId: String, autoStart: Bool = true, debugName: String? = nil) {
        print("🎬 DCFAnimationEngine: Registering group '\(groupId)' (autoStart: \(autoStart))")
        
        // ✅ FIX: Don't re-register if already exists
        if animationGroups[groupId] != nil {
            print("♻️ DCFAnimationEngine: Group '\(groupId)' already exists, skipping registration")
            return
        }
        
        animationGroups[groupId] = AnimationGroup(
            id: groupId,
            autoStart: autoStart,
            debugName: debugName ?? groupId
        )
        
        // FIXED: Process any pending controller registrations for this group
        if let pendingControllers = pendingGroupRegistrations[groupId] {
            print("🔄 DCFAnimationEngine: Adding \(pendingControllers.count) pending controllers to group '\(groupId)'")
            for controllerId in pendingControllers {
                animationGroups[groupId]?.addController(controllerId)
            }
            pendingGroupRegistrations.removeValue(forKey: groupId)
            print("✅ DCFAnimationEngine: All pending controllers added to group '\(groupId)'")
        }
    }
    
    func addControllerToGroup(_ groupId: String, controllerId: String) {
        print("🔗 DCFAnimationEngine: Attempting to add controller '\(controllerId)' to group '\(groupId)'")
        
        if let group = animationGroups[groupId] {
            // Group exists, add immediately
            group.addController(controllerId)
            print("✅ DCFAnimationEngine: Successfully added controller '\(controllerId)' to existing group '\(groupId)'")
            
            // Debug: Print current group state
            print("📊 DCFAnimationEngine: Group '\(groupId)' now has \(group.getAllControllerIds().count) controllers: \(group.getAllControllerIds())")
        } else {
            // FIXED: Group doesn't exist yet, store for later
            print("⏳ DCFAnimationEngine: Group '\(groupId)' not ready yet, storing controller '\(controllerId)' for later")
            if pendingGroupRegistrations[groupId] == nil {
                pendingGroupRegistrations[groupId] = []
            }
            pendingGroupRegistrations[groupId]?.append(controllerId)
            print("📊 DCFAnimationEngine: Pending controllers for group '\(groupId)': \(pendingGroupRegistrations[groupId] ?? [])")
        }
    }
    
    func executeGroupCommand(_ groupId: String, command: [String: Any]) {
        // ✅ EXECUTE IMMEDIATELY - NO QUEUING
        let commandType = command["type"] as? String ?? ""
        print("🎮 DCFAnimationEngine: IMMEDIATELY executing '\(commandType)' on group '\(groupId)'")
        
        // ✅ Handle individual commands first
        if commandType == "individual" {
            if let controllerId = command["controllerId"] as? String,
               let individualCommand = command["command"] as? [String: Any] {
                print("🎯 DCFAnimationEngine: Executing individual command on controller '\(controllerId)'")
                executeCommand(controllerId, command: individualCommand)
                return
            }
        }
        
        // ✅ Handle group commands
        guard let group = animationGroups[groupId] else {
            print("⚠️ DCFAnimationEngine: Group '\(groupId)' not found for command")
            print("📊 DCFAnimationEngine: Available groups: \(Array(animationGroups.keys))")
            return
        }
        
        let controllerIds = group.getAllControllerIds()
        print("📊 DCFAnimationEngine: Group controllers: \(controllerIds)")
        print("📊 DCFAnimationEngine: Active animations: \(Array(activeAnimations.keys))")
        
        switch commandType {
        case "startAll":
            executeStartAllCommand(group: group, command: command)
        case "stopAll":
            executeStopAllCommand(group: group, command: command)
        case "pauseAll":
            executePauseAllCommand(group: group)
        case "resumeAll":
            executeResumeAllCommand(group: group)
        case "resetAll":
            executeResetAllCommand(group: group, command: command)
        case "dispose":
            disposeAnimationGroup(groupId)
        default:
            print("⚠️ DCFAnimationEngine: Unknown group command '\(commandType)'")
        }
    }
    
    func disposeAnimationGroup(_ groupId: String) {
        guard let group = animationGroups[groupId] else {
            print("⚠️ DCFAnimationEngine: Group '\(groupId)' not found for disposal")
            return
        }
        
        print("🗑️ DCFAnimationEngine: Disposing group '\(groupId)' with \(group.getAllControllerIds().count) controllers")
        
        // Stop and remove all controllers in the group
        for controllerId in group.getAllControllerIds() {
            if let controller = activeAnimations[controllerId] {
                controller.executeCommand(["type": "stop"])
            }
            activeAnimations.removeValue(forKey: controllerId)
            print("🗑️ DCFAnimationEngine: Removed controller \(controllerId) from group")
        }
        
        // Remove the group
        animationGroups.removeValue(forKey: groupId)
        
        // Clean up any pending registrations for this group
        pendingGroupRegistrations.removeValue(forKey: groupId)
        
        // Stop display link if no active animations
        if activeAnimations.isEmpty && isRunning {
            displayLink?.invalidate()
            displayLink = nil
            isRunning = false
            print("🛑 DCFAnimationEngine: Stopped UI thread animation loop (no active animations)")
        }
        
        print("✅ DCFAnimationEngine: Successfully disposed group '\(groupId)'")
    }
    
    // MARK: - Group Command Implementations
    
    private func executeStartAllCommand(group: AnimationGroup, command: [String: Any]) {
        let staggered = command["staggered"] as? Bool ?? false
        let staggerInterval = Double(command["staggerInterval"] as? Int ?? 0) / 1000.0
        let delay = Double(command["delay"] as? Int ?? 0) / 1000.0
        
        let controllerIds = Array(group.getAllControllerIds())
        
        if staggered && staggerInterval > 0 {
            for (index, controllerId) in controllerIds.enumerated() {
                let totalDelay = delay + (Double(index) * staggerInterval)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                    if let controller = self.activeAnimations[controllerId] {
                        controller.executeCommand(["type": "resume"])
                    }
                }
            }
            print("🎬 DCFAnimationEngine: Started \(controllerIds.count) animations with stagger interval \(staggerInterval)s")
        } else {
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.startAllControllersInGroup(group)
                }
            } else {
                startAllControllersInGroup(group)
            }
            print("🎬 DCFAnimationEngine: Started \(controllerIds.count) animations simultaneously")
        }
    }
    
    private func startAllControllersInGroup(_ group: AnimationGroup) {
        for controllerId in group.getAllControllerIds() {
            if let controller = activeAnimations[controllerId] {
                controller.executeCommand(["type": "resume"])
            }
        }
    }
    
    private func executeStopAllCommand(group: AnimationGroup, command: [String: Any]) {
        let immediate = command["immediate"] as? Bool ?? true
        
        // ✅ CRITICAL FIX: Stop all animations IMMEDIATELY
        for controllerId in group.getAllControllerIds() {
            if let controller = activeAnimations[controllerId] {
                let stopCommand = ["type": immediate ? "stop" : "pause"]
                controller.executeCommand(stopCommand)
            }
        }
        print("🛑 DCFAnimationEngine: IMMEDIATELY stopped \(group.getAllControllerIds().count) animations (immediate: \(immediate))")
    }
    
    private func executePauseAllCommand(group: AnimationGroup) {
        // ✅ IMMEDIATE pause execution
        for controllerId in group.getAllControllerIds() {
            if let controller = activeAnimations[controllerId] {
                controller.executeCommand(["type": "pause"])
            }
        }
        print("⏸️ DCFAnimationEngine: IMMEDIATELY paused \(group.getAllControllerIds().count) animations")
    }
    
    private func executeResumeAllCommand(group: AnimationGroup) {
        // ✅ IMMEDIATE resume execution
        for controllerId in group.getAllControllerIds() {
            if let controller = activeAnimations[controllerId] {
                controller.executeCommand(["type": "resume"])
            }
        }
        print("▶️ DCFAnimationEngine: IMMEDIATELY resumed \(group.getAllControllerIds().count) animations")
    }
    
    private func executeResetAllCommand(group: AnimationGroup, command: [String: Any]) {
        let animated = command["animated"] as? Bool ?? false
        
        // ✅ IMMEDIATE reset execution
        for controllerId in group.getAllControllerIds() {
            if let controller = activeAnimations[controllerId] {
                controller.executeCommand([
                    "type": "reset",
                    "animated": animated
                ])
            }
        }
        print("🔄 DCFAnimationEngine: IMMEDIATELY reset \(group.getAllControllerIds().count) animations (animated: \(animated))")
    }
    
    // MARK: - Individual Controller Management
    
    func registerAnimationController(_ controllerId: String, view: AnimatedView) {
        if let existingController = activeAnimations[controllerId] {
            print("🔄 DCFAnimationEngine: Replacing existing controller \(controllerId)")
        }
        
        activeAnimations[controllerId] = AnimationController(view: view)
        startDisplayLinkIfNeeded()
        print("🎬 DCFAnimationEngine: Registered controller \(controllerId)")
    }
    
    func executeCommand(_ controllerId: String, command: [String: Any]) {
        // ✅ EXECUTE IMMEDIATELY - NO QUEUING
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
        
        for (controllerId, controller) in activeAnimations {
            if controller.updateFrame(currentTime: currentTime) {
                hasActiveAnimations = true
            } else {
                print("✅ DCFAnimationEngine: Animation \(controllerId) completed")
            }
        }
        
        activeAnimations = activeAnimations.filter { _, controller in
            controller.updateFrame(currentTime: currentTime)
        }
        
        if activeAnimations.isEmpty && isRunning {
            displayLink?.invalidate()
            displayLink = nil
            isRunning = false
            print("🛑 DCFAnimationEngine: Stopped UI thread animation loop")
        }
    }
    
    func removeController(_ controllerId: String) {
        if let controller = activeAnimations[controllerId] {
            controller.executeCommand(["type": "stop"])
        }
        activeAnimations.removeValue(forKey: controllerId)
        print("🗑️ DCFAnimationEngine: Removed controller \(controllerId)")
    }
}

// ============================================================================
// ANIMATION CONTROLLER
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
        
        // ✅ EXECUTE IMMEDIATELY - NO DELAYS, NO QUEUING
        switch commandType {
        case "animate":
            startDirectAnimation(command)
        case "reset":
            // ✅ IMMEDIATE reset - kill animation NOW
            currentAnimation?.interrupt()
            currentAnimation = nil
            view.resetToInitialState()
            print("🔄 AnimationController: IMMEDIATE reset executed")
        case "pause":
            // ✅ IMMEDIATE pause with proper timing
            if let animation = currentAnimation {
                animation.pause()
                print("⏸️ AnimationController: IMMEDIATE pause executed")
            }
        case "resume":
            // ✅ IMMEDIATE resume with proper timing
            if let animation = currentAnimation {
                animation.resume()
                print("▶️ AnimationController: IMMEDIATE resume executed")
            }
        case "stop":
            // ✅ IMMEDIATE stop - kill animation NOW
            currentAnimation?.interrupt()
            currentAnimation = nil
            view.resetToInitialState()
            print("🛑 AnimationController: IMMEDIATE stop executed")
        default:
            break
        }
    }
    
    private func startDirectAnimation(_ command: [String: Any]) {
        guard let view = view else { return }
        
        currentAnimation = nil
        
        currentAnimation = DirectAnimation(
            view: view,
            command: command,
            startTime: CACurrentMediaTime()
        )
        
        print("🎬 AnimationController: Started direct UI thread animation")
    }
    
    func updateFrame(currentTime: CFTimeInterval) -> Bool {
        guard let animation = currentAnimation else { return false }
        return animation.updateFrame(currentTime: currentTime)
    }
}

// ============================================================================
// DIRECT ANIMATION
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
    private var isInterrupted = false // ✅ NEW: Interruption flag
    
    init(view: AnimatedView, command: [String: Any], startTime: CFTimeInterval) {
        self.view = view
        self.startTime = startTime
        
        if let durationMs = command["duration"] as? Int {
            self.duration = TimeInterval(durationMs) / 1000.0
        } else if let durationSec = command["duration"] as? Double {
            self.duration = durationSec / 1000.0
        } else {
            self.duration = 0.3
        }
        
        self.repeatAnimation = command["repeat"] as? Bool ?? false
        
        let curveString = command["curve"] as? String ?? "easeInOut"
        self.curve = Self.getCurveFunction(curveString)
        
        self.fromValues = Self.captureCurrentValues(view)
        self.toValues = Self.extractTargetValues(command)
        
        print("🎯 DirectAnimation: Created with duration \(duration)s, repeat: \(repeatAnimation)")
        
        fireAnimationStartEvent(view: view)
    }
    
    // ✅ NEW: Proper pause method with timing
    func pause() {
        if !isPaused {
            isPaused = true
            pausedTime = CACurrentMediaTime() - startTime
            print("⏸️ DirectAnimation: Paused at time \(pausedTime)")
        }
    }
    
    // ✅ NEW: Proper resume method with timing
    func resume() {
        if isPaused {
            isPaused = false
            startTime = CACurrentMediaTime() - pausedTime
            print("▶️ DirectAnimation: Resumed from time \(pausedTime)")
        }
    }
    
    // ✅ NEW: Interrupt method for immediate stopping
    func interrupt() {
        isInterrupted = true
        print("🛑 DirectAnimation: Animation interrupted immediately")
    }
    
    func updateFrame(currentTime: CFTimeInterval) -> Bool {
        guard let view = view, !isInterrupted else {
            return false // ✅ Exit immediately if interrupted
        }
        
        // ✅ CRITICAL FIX: Handle pause separately - don't exit the function
        if isPaused {
            print("⏸️ DirectAnimation: Animation is paused, skipping frame")
            return true // Stay alive but don't animate
        }
        
        let elapsed = currentTime - startTime - pausedTime
        let progress = min(1.0, elapsed / duration)
        let easedProgress = curve(progress)
        
        applyCurrentValues(view: view, progress: easedProgress)
        
        if progress >= 1.0 {
            fireAnimationEndEvent(view: view)
            
            // ✅ CRITICAL FIX: Check pause AND interruption before repeating
            if repeatAnimation && !isInterrupted && !isPaused {
                print("🔄 DirectAnimation: Restarting animation cycle")
                
                self.startTime = currentTime
                resetViewToInitial(view: view)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    // ✅ Check pause again before firing start event
                    if let self = self, !self.isPaused {
                        self.fireAnimationStartEvent(view: view)
                    }
                }
                
                return true
            }
            
            return false
        }
        
        return true
    }
    
    private func resetViewToInitial(view: AnimatedView) {
        view.transform = CGAffineTransform.identity
        view.alpha = 1.0
        
        print("🔄 DirectAnimation: Reset view to initial state")
    }
    
    private func applyCurrentValues(view: AnimatedView, progress: Double) {
        var transform = CGAffineTransform.identity
        var hasTransform = false
        
        if let toScale = toValues["scale"] {
            let currentScale = 1.0 + (toScale - 1.0) * CGFloat(progress)
            transform = transform.scaledBy(x: currentScale, y: currentScale)
            hasTransform = true
        }
        
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
        
        if let toRotation = toValues["rotation"] {
            let currentRotation = toRotation * CGFloat(progress)
            transform = transform.rotated(by: currentRotation)
            hasTransform = true
        }
        
        if hasTransform {
            view.transform = transform
        }
        
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
    
    static func captureCurrentValues(_ view: AnimatedView) -> [String: CGFloat] {
        var values: [String: CGFloat] = [:]
        
        let transform = view.transform
        values["scale"] = sqrt(transform.a * transform.a + transform.c * transform.c)
        values["translateX"] = transform.tx
        values["translateY"] = transform.ty
        values["rotation"] = atan2(transform.b, transform.a)
        
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
