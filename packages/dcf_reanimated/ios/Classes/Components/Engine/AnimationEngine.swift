/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

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
    }
    
    // Execute command on UI thread
    func executeCommand(_ controllerId: String, command: [String: Any]) {
        guard let controller = activeAnimations[controllerId] else { return }
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
}
