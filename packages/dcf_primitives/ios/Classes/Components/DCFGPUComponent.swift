/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Metal
import MetalKit
import dcflight

// ============================================================================
// GPU COMPONENT - DIRECT GPU RENDERING WITH TYPE SAFETY
// ============================================================================

class DCFGPUComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let gpuView = GPUView()
        
        // Configure GPU rendering from props
        if let gpuConfig = props["gpuConfig"] as? [String: Any] {
            gpuView.configureGPU(gpuConfig)
        }
        
        // Apply styles
        gpuView.applyStyles(props: props)
        
        return gpuView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let gpuView = view as? GPUView else { return false }
        
        // Update GPU configuration if changed
        if let gpuConfig = props["gpuConfig"] as? [String: Any] {
            gpuView.updateGPUConfig(gpuConfig)
        }
        
        view.applyStyles(props: props)
        return true
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        if let gpuView = view as? GPUView {
            gpuView.nodeId = nodeId
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
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

// ============================================================================
// GPU VIEW - METAL-BASED GPU RENDERING
// ============================================================================

class GPUView: UIView {
    
    // Metal rendering
    private var metalDevice: MTLDevice?
    private var metalLayer: CAMetalLayer?
    private var commandQueue: MTLCommandQueue?
    private var displayLink: CADisplayLink?
    
    // GPU configuration
    private var gpuConfig: [String: Any] = [:]
    private var renderMode: String = "particles"
    private var isRendering = false
    private var animationStartTime: CFTimeInterval = 0
    
    // Particle system (for confetti)
    private var particles: [Particle] = []
    private var particleCount: Int = 50
    
    // Identifiers for callbacks
    var nodeId: String?
    
    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupMetal()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupMetal()
    }
    
    private func setupView() {
        // Make view transparent
        backgroundColor = .clear
        isOpaque = false
    }
    
    private func setupMetal() {
        // Initialize Metal
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("⚠️ GPU: Metal not available on this device")
            return
        }
        
        metalDevice = device
        commandQueue = device.makeCommandQueue()
        
        // Setup Metal layer
        if let metalLayer = self.layer as? CAMetalLayer {
            self.metalLayer = metalLayer
            metalLayer.device = device
            metalLayer.pixelFormat = .bgra8Unorm
            metalLayer.framebufferOnly = false
            metalLayer.isOpaque = false // Transparent
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Re-initialize particles when view is laid out (bounds are now correct)
        if renderMode == "particles" && particles.isEmpty && bounds.width > 0 && bounds.height > 0 {
            initializeParticles()
            
            // Auto-start if configured
            let autoStart = gpuConfig["autoStart"] as? Bool ?? true
            if autoStart && !isRendering {
                startRendering()
            }
        }
    }
    
    // ============================================================================
    // GPU CONFIGURATION
    // ============================================================================
    
    func configureGPU(_ config: [String: Any]) {
        print("🎮 GPU: Configuring GPU rendering")
        self.gpuConfig = config
        
        // Parse configuration
        if let mode = config["renderMode"] as? String {
            self.renderMode = mode
        }
        
        if let count = config["particleCount"] as? Int {
            self.particleCount = count
        }
        
        // Initialize particle system if needed (will be re-initialized in layoutSubviews with correct bounds)
        if renderMode == "particles" && bounds.width > 0 && bounds.height > 0 {
            initializeParticles()
        }
        
        // Auto-start if configured (will be started in layoutSubviews if bounds not ready)
        let autoStart = config["autoStart"] as? Bool ?? true
        if autoStart && bounds.width > 0 && bounds.height > 0 {
            startRendering()
        }
    }
    
    func updateGPUConfig(_ config: [String: Any]) {
        stopRendering()
        configureGPU(config)
    }
    
    // ============================================================================
    // PARTICLE SYSTEM (CONFETTI)
    // ============================================================================
    
    private func initializeParticles() {
        particles.removeAll()
        
        // Use view bounds if available, otherwise use a default size
        let width = bounds.width > 0 ? bounds.width : 400
        let height = bounds.height > 0 ? bounds.height : 800
        
        let colors = gpuConfig["parameters"] as? [String: Any]? ?? nil
        let colorArray = colors?["colors"] as? [String] ?? ["#FF0000", "#00FF00", "#0000FF"]
        
        print("🎨 GPU: Initializing \(particleCount) particles in \(width)x\(height)")
        
        for i in 0..<particleCount {
            let particle = Particle(
                x: Double.random(in: 0...Double(width)),
                y: Double.random(in: -100...0), // Start above view
                velocityX: Double.random(in: -50.0...50.0),
                velocityY: Double.random(in: -100.0...(-50.0)),
                color: parseColor(colorArray[i % colorArray.count]),
                size: Double.random(in: 5...15)
            )
            particles.append(particle)
        }
        
        print("✅ GPU: Initialized \(particles.count) particles")
    }
    
    private func parseColor(_ hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    // ============================================================================
    // RENDERING LOOP
    // ============================================================================
    
    func startRendering() {
        guard !isRendering else { return }
        
        print("🚀 GPU: Starting GPU rendering")
        isRendering = true
        animationStartTime = CACurrentMediaTime()
        
        // Fire start event
        fireGPUEvent(eventType: "onGPUStart")
        
        // Start display link
        startDisplayLink()
    }
    
    func stopRendering() {
        guard isRendering else { return }
        
        print("🛑 GPU: Stopping GPU rendering")
        isRendering = false
        stopDisplayLink()
        
        // Fire complete event
        fireGPUEvent(eventType: "onGPUComplete")
    }
    
    private func startDisplayLink() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateFrame() {
        guard isRendering else {
            stopDisplayLink()
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - animationStartTime
        
        // Check duration
        if let duration = gpuConfig["duration"] as? Int {
            let durationSeconds = Double(duration) / 1000.0
            if elapsed >= durationSeconds {
                stopRendering()
                return
            }
        }
        
        // Update and render
        updateParticles(elapsed: elapsed)
        renderFrame()
    }
    
    private func updateParticles(elapsed: CFTimeInterval) {
        guard renderMode == "particles" else { return }
        
        let gravity = (gpuConfig["parameters"] as? [String: Any])?["gravity"] as? Double ?? 9.8
        
        for i in 0..<particles.count {
            var particle = particles[i]
            
            // Update position
            particle.x += particle.velocityX * 0.016 // ~60fps
            particle.y += particle.velocityY * 0.016
            particle.velocityY += gravity * 0.016 // Apply gravity
            
            // Reset if out of bounds
            if particle.y > Double(bounds.height) {
                particle.y = -10
                particle.x = Double.random(in: 0...Double(bounds.width))
                particle.velocityY = Double.random(in: -100.0...(-50.0))
            }
            
            particles[i] = particle
        }
    }
    
    private func renderFrame() {
        // Use Core Graphics for rendering (simpler and works reliably)
        // In production, this could be upgraded to Metal shaders for true GPU rendering
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Clear background
        context.clear(rect)
        
        // Draw particles
        for particle in particles {
            context.setFillColor(particle.color.cgColor)
            context.fillEllipse(in: CGRect(
                x: particle.x - particle.size/2,
                y: particle.y - particle.size/2,
                width: particle.size,
                height: particle.size
            ))
        }
    }
    
    // ============================================================================
    // EVENT SYSTEM
    // ============================================================================
    
    private func fireGPUEvent(eventType: String) {
        guard let nodeId = nodeId else { return }
        
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
        print("🗑️ GPU: View deallocated")
    }
}

// ============================================================================
// PARTICLE STRUCTURE
// ============================================================================

struct Particle {
    var x: Double
    var y: Double
    var velocityX: Double
    var velocityY: Double
    var color: UIColor
    var size: Double
}

