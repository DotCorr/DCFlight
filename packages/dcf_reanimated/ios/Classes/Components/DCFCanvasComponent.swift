/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Flutter
import dcflight
import VideoToolbox

class DCFCanvasComponent: NSObject, DCFComponent {
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let view = DCFCanvasView()
        view.update(props: props)
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let canvasView = view as? DCFCanvasView else { return false }
        canvasView.update(props: props)
        return true
    }
    
    // Handle tunnel methods from Dart
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        print("DCFCanvasComponent: handleTunnelMethod \(method)")
        if method == "updateTexture" {
            guard let canvasId = params["canvasId"] as? String,
                  let pixels = params["pixels"] as? FlutterStandardTypedData,
                  let width = params["width"] as? Int,
                  let height = params["height"] as? Int else {
                print("DCFCanvasComponent: Invalid params for updateTexture")
                return nil
            }
            
            if let view = DCFCanvasView.getCanvasView(forId: canvasId) {
                view.updateTexture(pixels: pixels.data, width: width, height: height)
                return true
            } else {
                print("DCFCanvasComponent: View not found for canvasId: \(canvasId) - view may not be registered yet")
                return false  // Return false instead of nil to indicate view not ready
            }
        }
        return nil
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        // Canvas size is determined by layout or props, not intrinsic content
        if let width = props["width"] as? Double, let height = props["height"] as? Double {
            return CGSize(width: width, height: height)
        }
        return .zero
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // No-op for canvas
    }
}

// Particle data structure for native rendering
struct Particle {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var rotation: Double
    var rotationSpeed: Double
    let size: Double
    let color: UInt32 // ARGB
}

class DCFCanvasView: UIView, FlutterTexture {
    // Static registry to track active canvas views by ID
    // Use a serial queue to synchronize access and prevent race conditions
    private static let accessQueue = DispatchQueue(label: "com.dotcorr.dcfcanvas.views", attributes: .concurrent)
    private static var _canvasViews: [String: DCFCanvasView] = [:]
    
    static var canvasViews: [String: DCFCanvasView] {
        get {
            return accessQueue.sync { _canvasViews }
        }
    }
    
    static func setCanvasView(_ view: DCFCanvasView?, forId id: String) {
        accessQueue.async(flags: .barrier) {
            if let view = view {
                _canvasViews[id] = view
            } else {
                _canvasViews.removeValue(forKey: id)
            }
        }
    }
    
    static func getCanvasView(forId id: String) -> DCFCanvasView? {
        return accessQueue.sync {
            return _canvasViews[id]
        }
    }
    
    private var canvasId: String?
    private var textureId: Int64 = -1
    private var pixelBuffer: CVPixelBuffer?
    private var displayLink: CADisplayLink?
    private var repaintOnFrame: Bool = false
    private var onPaintCallback: FlutterCallbackInformation?
    
    // Native particle system
    private var particles: [Particle] = []
    private var particleConfig: [String: Any]?
    private var animationStartTime: CFTimeInterval = 0
    private var animationDuration: Double = 0
    private var gravity: Double = 9.8
    private var canvasWidth: Double = 0
    private var canvasHeight: Double = 0
    private var isAnimating: Bool = false
    
    // Layer to display the pixel buffer
    private var contentLayer: CALayer = CALayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        // Transparent background - canvas content comes from texture
        self.backgroundColor = .clear
        // Allow touches to pass through to views behind the canvas
        self.isUserInteractionEnabled = false
        NSLog("DCFCanvasView: init frame: \(frame)")
        setupLayer()
        registerTexture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // Transparent background - canvas content comes from texture
        self.backgroundColor = .clear
        // Allow touches to pass through to views behind the canvas
        self.isUserInteractionEnabled = false
        NSLog("DCFCanvasView: init coder")
        setupLayer()
        registerTexture()
    }
    
    private func setupLayer() {
        layer.addSublayer(contentLayer)
        contentLayer.contentsGravity = .resizeAspect
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentLayer.frame = bounds
        NSLog("DCFCanvasView: layoutSubviews bounds: \(bounds)")
    }

    private func registerTexture() {
        // Get the Flutter engine from the registry/delegate
        if let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate,
           let registrar = appDelegate.pluginRegistrant as? FlutterPluginRegistrar {
             textureId = registrar.textures().register(self)
        }
    }
    
    func update(props: [String: Any]) {
        // Register this view if canvasId is provided
        if let id = props["canvasId"] as? String {
            // Always register, even if ID is the same (in case view was recreated)
            if canvasId != id {
                // Unregister old ID if changed
                if let oldId = canvasId {
                    DCFCanvasView.setCanvasView(nil, forId: oldId)
                    NSLog("DCFCanvasView: Unregistered old canvasId: \(oldId)")
                }
            }
            canvasId = id
            DCFCanvasView.setCanvasView(self, forId: id)
            NSLog("DCFCanvasView: Registered canvasId: \(id)")
        }

        // Check for particle config (native rendering mode)
        if let config = props["particleConfig"] as? [String: Any] {
            configureParticles(config: config)
            return // Native rendering handles everything
        }

        if let repaint = props["repaintOnFrame"] as? Bool {
            self.repaintOnFrame = repaint
            if repaint {
                startDisplayLink()
            } else {
                stopDisplayLink()
            }
        }
        
        // Trigger a redraw
        drawFrame()
    }
    
    private func configureParticles(config: [String: Any]) {
        NSLog("🎉 DCFCanvasView: Configuring native particle system")
        particleConfig = config
        
        guard let particlesData = config["particles"] as? [[String: Any]],
              let width = config["width"] as? Double,
              let height = config["height"] as? Double,
              let duration = config["duration"] as? Int,
              let gravityValue = config["gravity"] as? Double else {
            NSLog("⚠️ DCFCanvasView: Invalid particle config")
            return
        }
        
        canvasWidth = width
        canvasHeight = height
        animationDuration = Double(duration) / 1000.0 // Convert ms to seconds
        gravity = gravityValue
        
        // Initialize particles
        particles = particlesData.compactMap { particleData in
            guard let x = particleData["x"] as? Double,
                  let y = particleData["y"] as? Double,
                  let vx = particleData["vx"] as? Double,
                  let vy = particleData["vy"] as? Double,
                  let rotation = particleData["rotation"] as? Double,
                  let rotationSpeed = particleData["rotationSpeed"] as? Double,
                  let size = particleData["size"] as? Double,
                  let colorValue = particleData["color"] as? Int else {
                return nil
            }
            
            return Particle(
                x: x,
                y: y,
                vx: vx,
                vy: vy,
                rotation: rotation,
                rotationSpeed: rotationSpeed,
                size: size,
                color: UInt32(colorValue)
            )
        }
        
        NSLog("🎉 DCFCanvasView: Initialized \(particles.count) particles")
        
        // Create buffer for rendering
        createBuffer(width: Int(width), height: Int(height))
        
        // Start animation
        animationStartTime = CACurrentMediaTime()
        isAnimating = true
        startDisplayLink()
    }

    func updateTexture(pixels: Data, width: Int, height: Int) {
        NSLog("DCFCanvasView: updateTexture width: \(width) height: \(height) bytes: \(pixels.count)")
        // Create or resize buffer if needed
        if pixelBuffer == nil || CVPixelBufferGetWidth(pixelBuffer!) != width || CVPixelBufferGetHeight(pixelBuffer!) != height {
            createBuffer(width: width, height: height)
        }
        
        guard let buffer = pixelBuffer else { 
            NSLog("DCFCanvasView: Failed to create buffer")
            return 
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            let destination = baseAddress.assumingMemoryBound(to: UInt8.self)
            
            pixels.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
                if let sourceAddress = rawBuffer.baseAddress {
                    let source = sourceAddress.assumingMemoryBound(to: UInt8.self)
                    
                    // Convert RGBA to BGRA (iOS expects BGRA format)
                    for y in 0..<height {
                        let srcRowOffset = y * width * 4
                        let dstRowOffset = y * bytesPerRow
                        
                        // Convert RGBA to BGRA pixel by pixel
                        for x in 0..<width {
                            let srcPixelOffset = srcRowOffset + (x * 4)
                            let dstPixelOffset = dstRowOffset + (x * 4)
                            
                            // RGBA: R, G, B, A
                            // BGRA: B, G, R, A
                            destination[dstPixelOffset + 0] = source[srcPixelOffset + 2] // B
                            destination[dstPixelOffset + 1] = source[srcPixelOffset + 1] // G
                            destination[dstPixelOffset + 2] = source[srcPixelOffset + 0] // R
                            destination[dstPixelOffset + 3] = source[srcPixelOffset + 3] // A
                        }
                    }
                }
            }
        }
        
        if let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate,
           let registrar = appDelegate.pluginRegistrant as? FlutterPluginRegistrar {
            registrar.textures().textureFrameAvailable(textureId)
        }
        
        DispatchQueue.main.async {
            self.drawFrame()
        }
    }
    
    private func createBuffer(width: Int, height: Int) {
        NSLog("DCFCanvasView: createBuffer \(width)x\(height)")
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            options as CFDictionary,
            &pixelBuffer
        )
        
        if status != kCVReturnSuccess {
            NSLog("DCFCanvasView: CVPixelBufferCreate failed: \(status)")
        }
    }

    // MARK: - FlutterTexture Protocol
    
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = pixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }
    
    // MARK: - Rendering
    
    private func startDisplayLink() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func onDisplayLink() {
        if isAnimating {
            updateAndRenderParticles()
        } else {
            drawFrame()
        }
    }
    
    private func updateAndRenderParticles() {
        guard let buffer = pixelBuffer else { return }
        
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - animationStartTime
        
        // Check if animation is complete
        if elapsed >= animationDuration {
            isAnimating = false
            stopDisplayLink()
            NSLog("🎉 DCFCanvasView: Particle animation complete")
            // TODO: Fire onComplete callback
            return
        }
        
        // Update particles
        let deltaTime = 1.0 / 60.0 // Assume 60fps
        for i in 0..<particles.count {
            particles[i].x += particles[i].vx * deltaTime
            particles[i].y += (particles[i].vy + gravity) * deltaTime
            particles[i].vy += gravity * deltaTime
            particles[i].rotation += particles[i].rotationSpeed * deltaTime
        }
        
        // Render particles to pixel buffer
        renderParticlesToBuffer(buffer)
        
        // Notify Flutter that frame is available
        if let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate,
           let registrar = appDelegate.pluginRegistrant as? FlutterPluginRegistrar {
            registrar.textures().textureFrameAvailable(textureId)
        }
        
        DispatchQueue.main.async {
            self.drawFrame()
        }
    }
    
    private func renderParticlesToBuffer(_ buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        
        // Clear buffer (transparent)
        let destination = baseAddress.assumingMemoryBound(to: UInt8.self)
        memset(destination, 0, bytesPerRow * height)
        
        // Render each particle
        for particle in particles {
            let x = Int(particle.x)
            let y = Int(particle.y)
            
            // Skip if out of bounds
            if x < 0 || x >= width || y < 0 || y >= height {
                continue
            }
            
            let radius = Int(particle.size / 2.0)
            let color = particle.color
            
            // Extract ARGB components
            let a = UInt8((color >> 24) & 0xFF)
            let r = UInt8((color >> 16) & 0xFF)
            let g = UInt8((color >> 8) & 0xFF)
            let b = UInt8(color & 0xFF)
            
            // Draw circle (simplified - just draw a filled circle)
            for dy in -radius...radius {
                for dx in -radius...radius {
                    let px = x + dx
                    let py = y + dy
                    
                    if px >= 0 && px < width && py >= 0 && py < height {
                        let distance = sqrt(Double(dx * dx + dy * dy))
                        if distance <= Double(radius) {
                            let pixelOffset = py * bytesPerRow + px * 4
                            
                            // Convert ARGB to BGRA for iOS
                            destination[pixelOffset + 0] = b
                            destination[pixelOffset + 1] = g
                            destination[pixelOffset + 2] = r
                            destination[pixelOffset + 3] = a
                        }
                    }
                }
            }
        }
    }

    private func drawFrame() {
        if let buffer = pixelBuffer {
            if let image = createCGImage(from: buffer) {
                contentLayer.contents = image
                // Remove debug background if we have content
                self.backgroundColor = .clear
            } else {
                NSLog("DCFCanvasView: Failed to create CGImage")
            }
        }
    }
    
    private func createCGImage(from buffer: CVPixelBuffer) -> CGImage? {
        var cgImage: CGImage?
        let status = VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &cgImage)
        if status != noErr {
            NSLog("DCFCanvasView: VTCreateCGImageFromCVPixelBuffer failed: \(status)")
        }
        return cgImage
    }
    
    deinit {
        // Safely remove from registry using the synchronized method
        if let id = canvasId {
            DCFCanvasView.setCanvasView(nil, forId: id)
        }
        if textureId != -1 {
            if let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate,
               let registrar = appDelegate.pluginRegistrant as? FlutterPluginRegistrar {
                registrar.textures().unregisterTexture(textureId)
            }
        }
        stopDisplayLink()
    }
}
