/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Flutter
import dcflight

/// Particle structure for confetti animation
struct CanvasParticle {
    let initialX: Double
    let initialY: Double
    let vx: Double
    let vy: Double
    let color: UIColor
    let radius: Double
    let life: Int
    
    var currentX: Double = 0
    var currentY: Double = 0
    var currentVX: Double = 0
    var currentVY: Double = 0
    var currentLife: Int = 0
}

/// Lightweight UIView that renders particle animations at 60fps
class DCFCanvasView: UIView {
    var particles: [CanvasParticle] = []
    var gravity: Double = 1.0
    var decay: Double = 0.9
    var displayLink: CADisplayLink?
    var isAnimating = false
    var nodeId: String?
    var onComplete: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.clear(rect)
        
        // Draw all particles
        for particle in particles where particle.currentLife > 0 {
            context.setFillColor(particle.color.cgColor)
            context.fillEllipse(in: CGRect(
                x: particle.currentX - particle.radius,
                y: particle.currentY - particle.radius,
                width: particle.radius * 2,
                height: particle.radius * 2
            ))
        }
    }
    
    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        
        // Initialize particle positions
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2
        
        for i in 0..<particles.count {
            particles[i].currentX = centerX
            particles[i].currentY = centerY
            particles[i].currentVX = particles[i].vx
            particles[i].currentVY = particles[i].vy
            particles[i].currentLife = particles[i].life
        }
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateFrame() {
        var activeCount = 0
        
        // Update all particles with physics
        for i in 0..<particles.count {
            if particles[i].currentLife > 0 {
                particles[i].currentVY += gravity
                particles[i].currentX += particles[i].currentVX
                particles[i].currentY += particles[i].currentVY
                particles[i].currentVX *= decay
                particles[i].currentVY *= decay
                particles[i].currentLife -= 1
                activeCount += 1
            }
        }
        
        // Trigger redraw
        setNeedsDisplay()
        
        // Check if animation complete
        if activeCount == 0 {
            stopAnimation()
            fireCompleteEvent()
        }
    }
    
    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        isAnimating = false
    }
    
    private func fireCompleteEvent() {
        propagateEvent(on: self, eventName: "onAnimationComplete", data: [:])
    }
    
    deinit {
        stopAnimation()
    }
}

class DCFCanvasComponent: NSObject, DCFComponent {
    
    override required init() { super.init() }
    
    func createView(props: [String: Any]) -> UIView {
        let view = DCFCanvasView()
        configureView(view, with: props)
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let canvasView = view as? DCFCanvasView else { return false }
        
        // Handle commands first (for user interaction during animation)
        handleCommand(canvasView: canvasView, props: props)
        
        // Then update configuration if needed
        configureView(canvasView, with: props)
        return true
    }
    
    /// Handle commands for user interaction during animation
    private func handleCommand(canvasView: DCFCanvasView, props: [String: Any]) {
        guard let commandData = props["command"] as? [String: Any] else {
            return
        }
        
        // Stop animation command
        if let stop = commandData["stop"] as? Bool, stop {
            canvasView.stopAnimation()
        }
        
        // Pause/resume animation command
        if let pause = commandData["pause"] as? Bool {
            canvasView.displayLink?.isPaused = pause
        }
        
        // Update physics parameters mid-flight
        if let updatePhysics = commandData["updatePhysics"] as? [String: Any] {
            if let gravity = updatePhysics["gravity"] as? Double {
                canvasView.gravity = gravity
            }
            if let decay = updatePhysics["decay"] as? Double {
                canvasView.decay = decay
            }
        }
    }
    
    private func configureView(_ view: DCFCanvasView, with props: [String: Any]) {
        // Handle confetti animation
        if let animationType = props["animationType"] as? String, animationType == "confetti" {
            guard let particlesData = props["particles"] as? [[String: Any]],
                  let physics = props["physics"] as? [String: Any] else {
                return
            }
            
            view.gravity = physics["gravity"] as? Double ?? 1.0
            view.decay = physics["decay"] as? Double ?? 0.9
            
            // Parse particle descriptions
            view.particles = particlesData.compactMap { data in
                guard let initialX = data["initialX"] as? Double,
                      let initialY = data["initialY"] as? Double,
                      let vx = data["vx"] as? Double,
                      let vy = data["vy"] as? Double,
                      let colorInt = data["color"] as? Int,
                      let radius = data["radius"] as? Double,
                      let life = data["life"] as? Int else {
                    return nil
                }
                
                let color = UIColor(
                    red: CGFloat((colorInt >> 16) & 0xFF) / 255.0,
                    green: CGFloat((colorInt >> 8) & 0xFF) / 255.0,
                    blue: CGFloat(colorInt & 0xFF) / 255.0,
                    alpha: CGFloat((colorInt >> 24) & 0xFF) / 255.0
                )
                
                return CanvasParticle(
                    initialX: initialX,
                    initialY: initialY,
                    vx: vx,
                    vy: vy,
                    color: color,
                    radius: radius,
                    life: life
                )
            }
            
            // Auto-start if configured
            if let autoStart = props["autoStart"] as? Bool, autoStart {
                view.startAnimation()
            }
        }
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(
            x: layout.left,
            y: layout.top,
            width: layout.width,
            height: layout.height
        )
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Set nodeId using objc_setAssociatedObject for propagateEvent to work
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "viewId".hashValue)!, 
                               nodeId, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        if let canvasView = view as? DCFCanvasView {
            canvasView.nodeId = nodeId
        }
    }
    
    func prepareForRecycle(_ view: UIView) {
        if let canvasView = view as? DCFCanvasView {
            canvasView.stopAnimation()
            canvasView.particles = []
            canvasView.nodeId = nil
        }
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        // No tunnel methods needed for Canvas - all done via props/commands
        return nil
    }
}

