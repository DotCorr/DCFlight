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
        print("🎮 SKIA GPU: Creating GPU view with props: \(props)")
        let gpuView = SkiaGPUView()
        updateView(gpuView, withProps: props)
        return gpuView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let gpuView = view as? SkiaGPUView else {
            print("⚠️ SKIA GPU: View is not SkiaGPUView")
            return false
        }
        
        print("🎮 SKIA GPU: Updating GPU view with props: \(props)")
        print("🎮 SKIA GPU: View bounds: \(view.bounds), frame: \(view.frame)")
        
        if let gpuConfig = props["gpuConfig"] as? [String: Any] {
            print("🎮 SKIA GPU: Found gpuConfig in props: \(gpuConfig)")
            gpuView.configureGPU(gpuConfig)
        } else {
            print("⚠️ SKIA GPU: No gpuConfig found in props. Available keys: \(props.keys)")
        }
        
        view.applyStyles(props: props)
        
        // Ensure view is visible and trigger layout if needed
        view.isHidden = false
        view.setNeedsLayout()
        
        return true
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        if let gpuView = view as? SkiaGPUView {
            gpuView.nodeId = nodeId
        }
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        let frame = CGRect(
            x: CGFloat(layout.left),
            y: CGFloat(layout.top),
            width: CGFloat(layout.width),
            height: CGFloat(layout.height)
        )
        view.frame = frame
        print("🎮 SKIA GPU: Applied layout - frame: \(frame)")
        
        // Force layout update to trigger layoutSubviews
        if let gpuView = view as? SkiaGPUView {
            gpuView.setNeedsLayout()
            gpuView.layoutIfNeeded()
        }
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
    private var skiaSurface: UnsafeMutableRawPointer?
    private var skiaCanvas: UnsafeMutableRawPointer?
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
            print("⚠️ SKIA GPU: Metal not available - device: \(MTLCreateSystemDefaultDevice() != nil), layer: \(type(of: self.layer))")
            return
        }
        
        metalDevice = device
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.isOpaque = false
        
        print("🎮 SKIA GPU: Metal layer configured - device: \(device), layer: \(metalLayer)")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        print("🎮 SKIA GPU: layoutSubviews called - bounds: \(bounds), renderMode: \(renderMode), particles: \(particles.count), gpuConfig: \(gpuConfig)")
        
        // Create/update Skia surface when laid out
        updateSkiaSurface()
        
        // Always try to initialize particles if we have bounds and config, even if particles exist
        // This handles the case where configureGPU was called before layout
        if renderMode == "particles" && bounds.width > 0 && bounds.height > 0 {
            if particles.isEmpty {
                print("🎮 SKIA GPU: Initializing particles in layoutSubviews")
                initializeParticles()
            }
            
            let autoStart = gpuConfig["autoStart"] as? Bool ?? true
            print("🎮 SKIA GPU: autoStart=\(autoStart), isRendering=\(isRendering), particles.count=\(particles.count)")
            if (autoStart && !isRendering && !particles.isEmpty) {
                print("🎮 SKIA GPU: Starting rendering from layoutSubviews")
                startRendering()
            }
        } else {
            if renderMode != "particles" {
                print("⚠️ SKIA GPU: renderMode is not 'particles': \(renderMode)")
            }
            if particles.isEmpty {
                print("⚠️ SKIA GPU: Particles empty - renderMode: \(renderMode), bounds: \(bounds)")
            }
            if bounds.width == 0 || bounds.height == 0 {
                print("⚠️ SKIA GPU: Bounds are zero: \(bounds)")
            }
        }
    }
    
    private func updateSkiaSurface() {
        guard bounds.width > 0 && bounds.height > 0,
              let device = metalDevice,
              let metalLayer = self.layer as? CAMetalLayer else {
            print("⚠️ SKIA GPU: Cannot update surface - bounds: \(bounds), device: \(metalDevice != nil), layer: \(type(of: self.layer))")
            return
        }
        
        // Update Metal layer drawable size
        metalLayer.drawableSize = CGSize(
            width: bounds.width * contentScaleFactor,
            height: bounds.height * contentScaleFactor
        )
        
        if let surface = skiaSurface {
            SkiaRenderer.destroySurface(surface)
            skiaSurface = nil
            skiaCanvas = nil
        }
        
        let width = Int32(bounds.width * contentScaleFactor)
        let height = Int32(bounds.height * contentScaleFactor)
        
        print("🎮 SKIA GPU: Creating Skia surface \(width)x\(height)")
        skiaSurface = SkiaRenderer.createSkiaSurface(
            Unmanaged.passUnretained(device).toOpaque(),
            layer: Unmanaged.passUnretained(metalLayer).toOpaque(),
            width: width,
            height: height
        )
        
        if skiaSurface != nil {
            print("✅ SKIA GPU: Surface created successfully")
        } else {
            print("❌ SKIA GPU: Failed to create surface")
        }
        
        // Canvas will be available after prepareSurfaceForRender is called
        // Don't try to get it here as surface is created lazily
    }
    
    func configureGPU(_ config: [String: Any]) {
        print("🎮 SKIA GPU: Configuring GPU rendering with config: \(config)")
        self.gpuConfig = config
        
        if let mode = config["renderMode"] as? String {
            self.renderMode = mode
            print("🎮 SKIA GPU: Render mode: \(mode)")
        }
        
        if let count = config["particleCount"] as? Int {
            self.particleCount = count
            print("🎮 SKIA GPU: Particle count: \(count)")
        }
        
        // Initialize particles if we have bounds, otherwise wait for layoutSubviews
        if renderMode == "particles" {
            if bounds.width > 0 && bounds.height > 0 {
                initializeParticles()
                let autoStart = config["autoStart"] as? Bool ?? true
                if autoStart {
                    startRendering()
                }
            } else {
                print("⚠️ SKIA GPU: Bounds not ready, will initialize in layoutSubviews")
            }
        }
    }
    
    private func initializeParticles() {
        particles.removeAll()
        
        let width = bounds.width > 0 ? bounds.width : 400
        let height = bounds.height > 0 ? bounds.height : 800
        
        // Get parameters from gpuConfig
        let parameters = gpuConfig["parameters"] as? [String: Any]
        let colorArray = parameters?["colors"] as? [String] ?? ["#FF0000", "#00FF00", "#0000FF"]
        
        print("🎨 SKIA GPU: Initializing \(particleCount) particles in \(width)x\(height)")
        print("🎨 SKIA GPU: Parameters: \(parameters ?? [:])")
        print("🎨 SKIA GPU: Colors: \(colorArray)")
        
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
        
        let parameters = gpuConfig["parameters"] as? [String: Any]
        let gravity = parameters?["gravity"] as? Double ?? 9.8
        
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
              renderMode == "particles",
              !particles.isEmpty else {
            if particles.isEmpty {
                print("⚠️ SKIA GPU: No particles to render - count: \(particles.count)")
            }
            if skiaSurface == nil {
                print("⚠️ SKIA GPU: No surface available")
            }
            if renderMode != "particles" {
                print("⚠️ SKIA GPU: Wrong render mode: \(renderMode)")
            }
            return
        }
        
        // Prepare surface for rendering (gets new drawable)
        SkiaRenderer.prepareSurface(forRender: surface)
        
        // Get canvas after preparing surface
        guard let canvas = SkiaRenderer.getCanvasFromSurface(surface) else {
            print("⚠️ SKIA GPU: Failed to get canvas after preparing surface")
            return
        }
        
        print("🎨 SKIA GPU: Rendering \(particles.count) particles")
        
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
        particleData.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                print("⚠️ SKIA GPU: Failed to get buffer address")
                return
            }
            print("🎨 SKIA GPU: Drawing \(particles.count) particles at baseAddress: \(baseAddress)")
            SkiaParticleRenderer.drawParticles(
                canvas,
                particles: baseAddress,
                count: Int32(particles.count)
            )
            print("✅ SKIA GPU: Particles drawn")
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

