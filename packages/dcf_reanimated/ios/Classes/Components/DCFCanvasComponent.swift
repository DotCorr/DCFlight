/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Flutter
import dcflight

/// Pure Canvas view - displays Flutter/Skia textures
/// All rendering (particles, shaders, paths, etc.) happens in Skia-land
/// Native side is just a texture container - no hardcoded primitives
class DCFCanvasView: UIView {
    // Flutter texture display - renders whatever Skia draws
    private var imageView: UIImageView?
    
    // Metadata
    var nodeId: String?
    var canvasId: String?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        
        // Create image view for Flutter/Skia texture display
        imageView = UIImageView()
        imageView?.contentMode = .scaleToFill
        if let imageView = imageView {
            addSubview(imageView)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView?.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Update Flutter/Skia texture
    /// Everything is rendered in Skia-land: particles, shaders, paths, animations, etc.
    /// Native just displays the texture - no hardcoded primitives
    func updateTexture(with imageData: Data, width: Int, height: Int) {
        guard let image = createImage(from: imageData, width: width, height: height) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.imageView?.image = image
        }
    }
    
    private func createImage(from data: Data, width: Int, height: Int) -> UIImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: bytesPerPixel * 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    // --- Native Animation Support ---
    
    private var displayLink: CADisplayLink?
    private var animationManager: AnimationManager?
    
    func startAnimation(config: [String: Any]) {
        stopAnimation()
        
        if let type = config["type"] as? String, type == "confetti" {
            animationManager = ConfettiAnimation(config: config)
            
            displayLink = CADisplayLink(target: self, selector: #selector(animationLoop))
            displayLink?.add(to: .main, forMode: .common)
        }
    }
    
    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        animationManager = nil
    }
    
    @objc private func animationLoop() {
        guard let manager = animationManager else { return }
        
        // Create image context for drawing
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Clear
        context.clear(bounds)
        
        // Update and draw
        manager.updateAndDraw(context: context, size: bounds.size)
        
        // Get image and update view
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        imageView?.image = image
        
        // Auto-stop
        if manager.isFinished {
            stopAnimation()
        }
    }
}

// --- Animation Classes ---

protocol AnimationManager {
    func updateAndDraw(context: CGContext, size: CGSize)
    var isFinished: Bool { get }
}

class ConfettiAnimation: AnimationManager {
    private var particles: [Particle] = []
    
    // Config
    private let particleCount: Int
    private let startVelocity: CGFloat
    private let spread: CGFloat
    private let angle: CGFloat
    private let gravity: CGFloat
    private let drift: CGFloat
    private let decay: CGFloat
    private let colors: [UIColor]
    private let scalar: CGFloat
    
    private var initialized = false
    
    init(config: [String: Any]) {
        self.particleCount = config["particleCount"] as? Int ?? 50
        self.startVelocity = (config["startVelocity"] as? CGFloat) ?? 45.0
        self.spread = (config["spread"] as? CGFloat) ?? 45.0
        self.angle = (config["angle"] as? CGFloat) ?? 90.0
        self.gravity = (config["gravity"] as? CGFloat) ?? 1.0
        self.drift = (config["drift"] as? CGFloat) ?? 0.0
        self.decay = (config["decay"] as? CGFloat) ?? 0.9
        self.scalar = (config["scalar"] as? CGFloat) ?? 1.0
        
        if let colorValues = config["colors"] as? [Int] {
            self.colors = colorValues.map { UIColor(rgb: $0) }
        } else {
            self.colors = [.red, .blue]
        }
        
        // Initialize particles
        for _ in 0..<particleCount {
            particles.append(createParticle())
        }
    }
    
    func updateAndDraw(context: CGContext, size: CGSize) {
        if !initialized {
            let startX = size.width / 2
            let startY = size.height / 2
            for i in 0..<particles.count {
                particles[i].x = startX
                particles[i].y = startY
            }
            initialized = true
        }
        
        var activeParticles = 0
        
        for i in 0..<particles.count {
            // Skip dead particles
            if particles[i].dead { continue }
            
            // Physics
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].vy += gravity
            particles[i].vx *= decay
            particles[i].vy *= decay
            particles[i].x += drift
            
            // Draw
            context.setFillColor(particles[i].color.cgColor)
            context.fillEllipse(in: CGRect(
                x: particles[i].x - particles[i].radius,
                y: particles[i].y - particles[i].radius,
                width: particles[i].radius * 2,
                height: particles[i].radius * 2
            ))
            
            // Check bounds
            if particles[i].y > size.height + 50 {
                particles[i].dead = true
            } else {
                activeParticles += 1
            }
        }
        
        // Auto-stop if all particles are dead (we can't set isActive directly on struct protocol, 
        // so we'll return a status or handle it in the view. 
        // For now, let's assume the view checks a property or we add one to the protocol)
    }
    
    var isFinished: Bool {
        return initialized && particles.allSatisfy { $0.dead }
    }
    
    private func createParticle() -> Particle {
        let randomAngle = (angle - spread / 2 + CGFloat.random(in: 0...1) * spread) * (.pi / 180)
        let speed = startVelocity * (0.5 + CGFloat.random(in: 0...1) * 0.5)
        
        return Particle(
            x: 0, // Set in update
            y: 0,
            vx: cos(randomAngle) * speed,
            vy: -sin(randomAngle) * speed,
            color: colors.randomElement() ?? .red,
            radius: (3 + CGFloat.random(in: 0...1) * 4) * scalar,
            dead: false
        )
    }
}

struct Particle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var color: UIColor
    var radius: CGFloat
    var dead: Bool
}

extension UIColor {
    convenience init(rgb: Int) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: CGFloat((rgb >> 24) & 0xFF) / 255.0
        )
    }
}

class DCFCanvasComponent: NSObject, DCFComponent {
    
    // Track all canvas views by canvasId for tunnel method routing
    private static var canvasViews: [String: DCFCanvasView] = [:]
    
    override required init() { super.init() }
    
    func createView(props: [String: Any]) -> UIView {
        let view = DCFCanvasView()
        configureView(view, with: props)
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let canvasView = view as? DCFCanvasView else { return false }
        configureView(canvasView, with: props)
        return true
    }
    
    private func configureView(_ view: DCFCanvasView, with props: [String: Any]) {
        // Register canvas by ID for tunnel method routing
        if let canvasId = props["canvasId"] as? String {
            view.canvasId = canvasId
            DCFCanvasComponent.canvasViews[canvasId] = view
        }
        
        // Handle Command Pattern
        if let command = props["canvasCommand"] as? [String: Any] {
            if let name = command["name"] as? String {
                if name == "startAnimation" {
                    if let config = command["config"] as? [String: Any] {
                        view.startAnimation(config: config)
                    }
                } else if name == "stopAnimation" {
                    view.stopAnimation()
                }
            }
        }
        
        // Everything else is handled in Skia-land via texture updates
        // No hardcoded native primitives (particles, shaders, etc.)
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
            canvasView.nodeId = nil
            canvasView.stopAnimation() // Ensure animation stops
            
            // Unregister from tracking
            if let canvasId = canvasView.canvasId {
                DCFCanvasComponent.canvasViews.removeValue(forKey: canvasId)
            }
        }
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        // Handle updatePixels tunnel for Flutter/Skia texture rendering
        if method == "updatePixels" {
            guard let canvasId = params["canvasId"] as? String,
                  let canvasView = canvasViews[canvasId],
                  let pixels = params["pixels"] as? FlutterStandardTypedData,
                  let width = params["width"] as? Int,
                  let height = params["height"] as? Int else {
                print("❌ Canvas: Missing required params for updatePixels")
                return false
            }
            
            canvasView.updateTexture(with: pixels.data, width: width, height: height)
            return true
        }
        
        return nil
    }
}

