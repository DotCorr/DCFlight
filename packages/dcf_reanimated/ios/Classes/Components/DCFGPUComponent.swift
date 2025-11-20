/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

// ============================================================================
// GPU COMPONENT - SKIA-BASED GPU RENDERING
// ============================================================================

class DCFGPUComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let gpuView = SkiaGPUView()
        updateView(gpuView, withProps: props)
        return gpuView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let gpuView = view as? SkiaGPUView else { return false }
        
        if let gpuConfig = props["gpuConfig"] as? [String: Any] {
            gpuView.configureGPU(gpuConfig)
        }
        
        view.applyStyles(props: props)
        return true
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        if let gpuView = view as? SkiaGPUView {
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
// SKIA GPU VIEW - PARTICLE SYSTEMS AND GPU EFFECTS
// ============================================================================

class SkiaGPUView: UIView {
    var nodeId: String?
    
    // Skia surface and canvas
    private var skiaSurface: OpaquePointer?
    private var skiaCanvas: OpaquePointer?
    private var metalDevice: MTLDevice?
    private var displayLink: CADisplayLink?
    
    // GPU configuration
    private var gpuConfig: [String: Any] = [:]
    private var renderMode: String = "particles"
    private var particleCount: Int = 50
    private var particles: [Particle] = []
    private var isRendering = false
    private var animationStartTime: CFTimeInterval = 0
    
    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSkia()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSkia()
    }
    
    private func setupSkia() {
        backgroundColor = .clear
        isOpaque = false
        initializeSkiaMetal()
    }
    
    private func initializeSkiaMetal() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let metalLayer = self.layer as? CAMetalLayer else {
            print("⚠️ SKIA GPU: Metal not available")
            return
        }
        
        metalDevice = device
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.isOpaque = false
        
        print("🎮 SKIA GPU: Metal layer configured")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Create/update Skia surface when laid out
        updateSkiaSurface()
        
        if renderMode == "particles" && particles.isEmpty && bounds.width > 0 && bounds.height > 0 {
            initializeParticles()
            
            let autoStart = gpuConfig["autoStart"] as? Bool ?? true
            if (autoStart && !isRendering) {
                startRendering()
            }
        }
    }
    
    private func updateSkiaSurface() {
        guard bounds.width > 0 && bounds.height > 0,
              let device = metalDevice,
              let metalLayer = self.layer as? CAMetalLayer else { return }
        
        if let surface = skiaSurface {
            SkiaRenderer.destroySurface(surface)
            skiaSurface = nil
            skiaCanvas = nil
        }
        
        let width = Int(bounds.width * contentScaleFactor)
        let height = Int(bounds.height * contentScaleFactor)
        
        skiaSurface = SkiaRenderer.createSkiaSurface(
            Unmanaged.passUnretained(device).toOpaque(),
            layer: Unmanaged.passUnretained(metalLayer).toOpaque(),
            width: width,
            height: height
        )
        
        if let surface = skiaSurface {
            skiaCanvas = SkiaRenderer.getCanvasFromSurface(surface)
        }
    }
    
    func configureGPU(_ config: [String: Any]) {
        print("🎮 SKIA GPU: Configuring GPU rendering")
        self.gpuConfig = config
        
        if let mode = config["renderMode"] as? String {
            self.renderMode = mode
        }
        
        if let count = config["particleCount"] as? Int {
            self.particleCount = count
        }
        
        if renderMode == "particles" && bounds.width > 0 && bounds.height > 0 {
            initializeParticles()
        }
        
        let autoStart = config["autoStart"] as? Bool ?? true
        if autoStart && bounds.width > 0 && bounds.height > 0 {
            startRendering()
        }
    }
    
    private func initializeParticles() {
        particles.removeAll()
        
        let width = bounds.width > 0 ? bounds.width : 400
        let height = bounds.height > 0 ? bounds.height : 800
        
        let colors = gpuConfig["parameters"] as? [String: Any]? ?? nil
        let colorArray = colors?["colors"] as? [String] ?? ["#FF0000", "#00FF00", "#0000FF"]
        
        print("🎨 SKIA GPU: Initializing \(particleCount) particles in \(width)x\(height)")
        
        for i in 0..<particleCount {
            let particle = Particle(
                x: Double.random(in: 0...Double(width)),
                y: Double.random(in: -100...0),
                velocityX: Double.random(in: -50.0...50.0),
                velocityY: Double.random(in: -100.0...(-50.0)),
                color: parseColor(colorArray[i % colorArray.count]),
                size: Double.random(in: 5...15)
            )
            particles.append(particle)
        }
        
        print("✅ SKIA GPU: Initialized \(particles.count) particles")
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
    
    func startRendering() {
        guard !isRendering else { return }
        
        print("🚀 SKIA GPU: Starting GPU rendering")
        isRendering = true
        animationStartTime = CACurrentMediaTime()
        
        startDisplayLink()
    }
    
    func stopRendering() {
        guard isRendering else { return }
        
        print("🛑 SKIA GPU: Stopping GPU rendering")
        isRendering = false
        stopDisplayLink()
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
        
        if let duration = gpuConfig["duration"] as? Int {
            let durationSeconds = Double(duration) / 1000.0
            if elapsed >= durationSeconds {
                stopRendering()
                return
            }
        }
        
        updateParticles(elapsed: elapsed)
        renderWithSkia()
    }
    
    private func updateParticles(elapsed: CFTimeInterval) {
        guard renderMode == "particles" else { return }
        
        let gravity = (gpuConfig["parameters"] as? [String: Any])?["gravity"] as? Double ?? 9.8
        
        for i in 0..<particles.count {
            var particle = particles[i]
            
            particle.x += particle.velocityX * 0.016
            particle.y += particle.velocityY * 0.016
            particle.velocityY += gravity * 0.016
            
            if particle.y > Double(bounds.height) {
                particle.y = -10
                particle.x = Double.random(in: 0...Double(bounds.width))
                particle.velocityY = Double.random(in: -100.0...(-50.0))
            }
            
            particles[i] = particle
        }
    }
    
    private func renderWithSkia() {
        guard let surface = skiaSurface,
              let canvas = skiaCanvas,
              renderMode == "particles" else {
            return
        }
        
        // Convert particles to C array for Skia rendering
        var particleData = particles.map { p -> ParticleData in
            var color: UInt32 = 0
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            p.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            color = (UInt32(a * 255) << 24) |
                    (UInt32(r * 255) << 16) |
                    (UInt32(g * 255) << 8) |
                    UInt32(b * 255)
            
            return ParticleData(
                x: p.x,
                y: p.y,
                size: p.size,
                color: color
            )
        }
        
        // Render particles using Skia
        particleData.withUnsafeMutableBufferPointer { buffer in
            SkiaParticleRenderer.drawParticles(
                canvas,
                particles: buffer.baseAddress,
                count: Int32(particles.count)
            )
        }
        
        // Flush to Metal
        SkiaRenderer.flushSurface(surface)
    }
    
    deinit {
        stopDisplayLink()
        if let surface = skiaSurface {
            SkiaRenderer.destroySurface(surface)
        }
    }
}

struct Particle {
    var x: Double
    var y: Double
    var velocityX: Double
    var velocityY: Double
    let color: UIColor
    let size: Double
}

