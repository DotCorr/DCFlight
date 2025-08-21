/*
 * DCF Reanimated Swift Implementation
 * Copyright (c) Dotcorr Studio. and affiliates.
 * Licensed under the MIT license
 */

import UIKit
import dcflight

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
        layer.removeAllAnimations()
        transform = CGAffineTransform.identity
        alpha = 1.0
    }
    
    deinit {
        if let controllerId = controllerId {
            DCFAnimationEngine.shared.removeController(controllerId)
        }
    }
}

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
    }
    
    func removeController(_ controllerId: String) {
        controllerIds.remove(controllerId)
    }
    
    func getAllControllerIds() -> Set<String> {
        return controllerIds
    }
    
    func isEmpty() -> Bool {
        return controllerIds.isEmpty
    }
}

public class DCFAnimationEngine {
    static let shared = DCFAnimationEngine()
    
    private var displayLink: CADisplayLink?
    private var activeAnimations: [String: AnimationController] = [:]
    private var animationGroups: [String: AnimationGroup] = [:]
    private var pendingGroupRegistrations: [String: [String]] = [:]
    private var isRunning = false
    
    private init() {}
    
    // ✅ NEW: Method to check if controller exists
    func hasController(_ controllerId: String) -> Bool {
        let exists = activeAnimations[controllerId] != nil
        print("🔍 Checking controller \(controllerId): \(exists ? "EXISTS" : "NOT FOUND")")
        print("🔍 Active controllers: \(Array(activeAnimations.keys))")
        return exists
    }
    
    func registerAnimationGroup(_ groupId: String, autoStart: Bool = true, debugName: String? = nil) {
        if animationGroups[groupId] != nil {
            print("⚠️ Animation group \(groupId) already exists")
            return
        }
        
        print("🎯 Registering animation group: \(groupId)")
        animationGroups[groupId] = AnimationGroup(
            id: groupId,
            autoStart: autoStart,
            debugName: debugName ?? groupId
        )
        
        if let pendingControllers = pendingGroupRegistrations[groupId] {
            for controllerId in pendingControllers {
                animationGroups[groupId]?.addController(controllerId)
            }
            pendingGroupRegistrations.removeValue(forKey: groupId)
        }
    }
    
    func addControllerToGroup(_ groupId: String, controllerId: String) {
        if let group = animationGroups[groupId] {
            group.addController(controllerId)
            print("🎯 Added controller \(controllerId) to existing group \(groupId)")
        } else {
            if pendingGroupRegistrations[groupId] == nil {
                pendingGroupRegistrations[groupId] = []
            }
            pendingGroupRegistrations[groupId]?.append(controllerId)
            print("🎯 Queued controller \(controllerId) for pending group \(groupId)")
        }
    }
    
    func executeGroupCommand(_ groupId: String, command: [String: Any]) {
        let commandType = command["type"] as? String ?? ""
        print("🎯 executeGroupCommand: \(groupId) - \(commandType)")
        
        if commandType == "individual" {
            if let controllerId = command["controllerId"] as? String,
               let individualCommand = command["command"] as? [String: Any] {
                executeCommand(controllerId, command: individualCommand)
                return
            }
        }
        
        guard let group = animationGroups[groupId] else {
            print("❌ Animation group \(groupId) not found")
            return
        }
        
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
            print("❌ Unknown group command: \(commandType)")
            break
        }
    }
    
    func disposeAnimationGroup(_ groupId: String) {
        guard let group = animationGroups[groupId] else { return }
        
        print("🗑️ Disposing animation group: \(groupId)")
        
        for controllerId in group.getAllControllerIds() {
            if let controller = activeAnimations[controllerId] {
                controller.executeCommand(["type": "stop"])
            }
            activeAnimations.removeValue(forKey: controllerId)
        }
        
        animationGroups.removeValue(forKey: groupId)
        pendingGroupRegistrations.removeValue(forKey: groupId)
        
        // ✅ CRITICAL FIX: Only stop display link if NO controllers exist at all
        if activeAnimations.isEmpty && isRunning {
            stopDisplayLink()
        }
    }
    
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
        } else {
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.startAllControllersInGroup(group)
                }
            } else {
                startAllControllersInGroup(group)
            }
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
        
        for controllerId in group.getAllControllerIds() {
            if let controller = activeAnimations[controllerId] {
                let stopCommand = ["type": immediate ? "stop" : "pause"]
                controller.executeCommand(stopCommand)
            }
        }
    }
    
    private func executePauseAllCommand(group: AnimationGroup) {
        for controllerId in group.getAllControllerIds() {
            if let controller = activeAnimations[controllerId] {
                controller.executeCommand(["type": "pause"])
            }
        }
    }
    
    private func executeResumeAllCommand(group: AnimationGroup) {
        for controllerId in group.getAllControllerIds() {
            if let controller = activeAnimations[controllerId] {
                controller.executeCommand(["type": "resume"])
            }
        }
    }
    
    private func executeResetAllCommand(group: AnimationGroup, command: [String: Any]) {
        let animated = command["animated"] as? Bool ?? false
        
        for controllerId in group.getAllControllerIds() {
            if let controller = activeAnimations[controllerId] {
                controller.executeCommand([
                    "type": "reset",
                    "animated": animated
                ])
            }
        }
    }
    
    func registerAnimationController(_ controllerId: String, view: AnimatedView) {
        print("🎯 registerAnimationController: \(controllerId)")
        activeAnimations[controllerId] = AnimationController(view: view)
        view.setControllerId(controllerId)
        startDisplayLinkIfNeeded()
        print("🎯 Active controllers after registration: \(Array(activeAnimations.keys))")
    }
    
    func executeCommand(_ controllerId: String, command: [String: Any]) {
        print("🎯 executeCommand: \(controllerId) with \(command)")
        guard let controller = activeAnimations[controllerId] else {
            print("❌ Controller \(controllerId) not found for command execution")
            return
        }
        controller.executeCommand(command)
    }
    
    private func startDisplayLinkIfNeeded() {
        guard !isRunning else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
        isRunning = true
        print("🎯 Display link started")
    }
    
    // ✅ CRITICAL FIX: Only stop display link manually, don't auto-stop based on animations
    private func stopDisplayLink() {
        guard isRunning else { return }
        
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
        print("🎯 Display link stopped manually")
    }
    
    @objc private func updateFrame() {
        let currentTime = CACurrentMediaTime()
        
        // ✅ CRITICAL FIX: Track running animations separately, don't remove controllers
        var runningAnimations: [String: AnimationController] = [:]
        
        for (controllerId, controller) in activeAnimations {
            let isStillRunning = controller.updateFrame(currentTime: currentTime)
            
            // Keep controller in activeAnimations regardless of animation state
            // Only track which ones are currently animating
            if isStillRunning {
                runningAnimations[controllerId] = controller
            }
        }
        
        // ✅ CRITICAL FIX: Only stop display link if no animations are running
        // BUT keep all controllers registered
        if runningAnimations.isEmpty && isRunning {
            stopDisplayLink()
        }
        
        print("🎯 Update frame - Active controllers: \(activeAnimations.count), Running animations: \(runningAnimations.count)")
    }
    
    func removeController(_ controllerId: String) {
        if let controller = activeAnimations[controllerId] {
            controller.executeCommand(["type": "stop"])
        }
        activeAnimations.removeValue(forKey: controllerId)
        print("🎯 Removed controller: \(controllerId)")
        
        // Stop display link if no controllers remain
        if activeAnimations.isEmpty && isRunning {
            stopDisplayLink()
        }
    }
}

class AnimationController {
    private weak var view: AnimatedView?
    private var currentAnimation: DirectAnimation?
    
    init(view: AnimatedView) {
        self.view = view
    }
    
    func executeCommand(_ command: [String: Any]) {
        guard let view = view else { return }
        
        let commandType = command["type"] as? String ?? ""
        print("🎯 AnimationController.executeCommand: \(commandType)")
        
        switch commandType {
        case "animate":
            startDirectAnimation(command)
        case "reset":
            currentAnimation?.forceInterrupt()
            currentAnimation = nil
            view.resetToInitialState()
        case "pause":
            if let animation = currentAnimation {
                animation.forcePause()
            }
        case "resume":
            if let animation = currentAnimation {
                animation.forceResume()
            }
        case "stop":
            currentAnimation?.forceInterrupt()
            currentAnimation = nil
            view.resetToInitialState()
        case "restart":
            if let animation = currentAnimation {
                let originalCommand = animation.getOriginalCommand()
                currentAnimation?.forceInterrupt()
                currentAnimation = nil
                view.resetToInitialState()
                startDirectAnimation(originalCommand)
            }
        case "stopRepeat":
            if let animation = currentAnimation {
                animation.forceStopRepeat()
            }
        default:
            print("❌ Unknown animation command: \(commandType)")
            break
        }
    }
    
    private func startDirectAnimation(_ command: [String: Any]) {
        guard let view = view else { return }
        
        print("🎬 Starting direct animation with command: \(command)")
        currentAnimation = nil
        currentAnimation = DirectAnimation(
            view: view,
            command: command,
            startTime: CACurrentMediaTime()
        )
    }
    
    // ✅ CRITICAL FIX: Return true if animation is running, false if finished/not running
    func updateFrame(currentTime: CFTimeInterval) -> Bool {
        guard let animation = currentAnimation else {
            return false // No animation running
        }
        return animation.updateFrame(currentTime: currentTime)
    }
}

class DirectAnimation {
    private weak var view: AnimatedView?
    private var startTime: CFTimeInterval
    private let duration: TimeInterval
    private let curve: (Double) -> Double
    private let fromValues: [String: CGFloat]
    private let toValues: [String: CGFloat]
    private var repeatAnimation: Bool
    var isPaused = false
    private var pausedTime: CFTimeInterval = 0
    private var isInterrupted = false
    private let originalCommand: [String: Any]
    
    init(view: AnimatedView, command: [String: Any], startTime: CFTimeInterval) {
        self.view = view
        self.startTime = startTime
        self.originalCommand = command
        
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
        
        print("🎬 DirectAnimation initialized - duration: \(duration), repeat: \(repeatAnimation)")
        print("🎬 Target values: \(toValues)")
        
        fireAnimationStartEvent(view: view)
    }
    
    func getOriginalCommand() -> [String: Any] {
        return originalCommand
    }
    
    func forcePause() {
        isPaused = true
        pausedTime = CACurrentMediaTime() - startTime
    }
    
    func forceResume() {
        isPaused = false
        startTime = CACurrentMediaTime() - pausedTime
    }
    
    func forceInterrupt() {
        isInterrupted = true
    }
    
    func forceStopRepeat() {
        repeatAnimation = false
    }
    
    func updateFrame(currentTime: CFTimeInterval) -> Bool {
        guard let view = view, !isInterrupted else {
            return false
        }
        
        if isPaused {
            return true
        }
        
        let elapsed = currentTime - startTime - pausedTime
        let progress = min(1.0, elapsed / duration)
        let easedProgress = curve(progress)
        
        applyCurrentValues(view: view, progress: easedProgress)
        
        if progress >= 1.0 {
            fireAnimationEndEvent(view: view)
            
            if repeatAnimation && !isInterrupted && !isPaused {
                self.startTime = currentTime
                resetViewToInitial(view: view)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
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
