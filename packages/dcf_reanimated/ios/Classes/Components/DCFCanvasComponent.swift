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
    
    func updateTexture(with data: Data, width: Int, height: Int) {
        // Restore generic texture support
        let provider = CGDataProvider(data: data as CFData)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        if let provider = provider,
           let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) {
            // If we have an image view, update it. 
            // If we are in "Confetti Mode" (GPU), we might overlay this or ignore it depending on requirements.
            // But the user said "must be a canvas... for us to control the flutter texture".
            // So we MUST render this.
            
            // Ensure we have a layer or view to display this.
            // We can use the layer's contents directly for performance.
            layer.contents = cgImage
        }
    }

    // --- Animation Control ---
    
    // --- Generic Command System ---
    
    private var emitterLayer: CAEmitterLayer?
    
    /// Execute a GPU-accelerated command
    func handleCommand(_ command: [String: Any]) {
        guard let type = command["type"] as? String else { return }
        
        switch type {
        case "confetti":
            runConfetti(config: command)
        case "clear":
            stopAnimation()
        // Future extensions:
        // case "drawShape": drawShape(command)
        // case "animate": animateItem(command)
        default:
            print("Unknown command type: \(type)")
        }
    }
    
    private func runConfetti(config: [String: Any]) {
        // Stop any existing animation
        stopAnimation()
        
        // Extract config
        let scalar = config["scalar"] as? CGFloat ?? 1.0
        let spread = config["spread"] as? CGFloat ?? 60.0
        let startVelocity = config["startVelocity"] as? CGFloat ?? 45.0
        let colors = (config["colors"] as? [String])?.compactMap { UIColor(hex: $0) } ?? [.red, .green, .blue]
        
        // Create Emitter Layer
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        emitter.emitterShape = .point
        emitter.emitterSize = CGSize(width: 10, height: 10)
        
        // Create Cells
        var cells: [CAEmitterCell] = []
        
        for color in colors {
            let cell = CAEmitterCell()
            cell.contents = createCircleImage(radius: 5 * scalar)?.cgImage
            cell.birthRate = 10 // Particles per second per color
            cell.lifetime = 5.0
            cell.velocity = startVelocity * 5 // Adjust for Core Animation scale
            cell.velocityRange = startVelocity * 2
            cell.emissionLongitude = .pi * 1.5 // Upwards (270 degrees)
            cell.emissionRange = spread * (.pi / 180)
            cell.yAcceleration = 200 * scalar // Gravity
            cell.scale = 1.0
            cell.scaleRange = 0.5
            cell.color = color.cgColor
            
            cells.append(cell)
        }
        
        emitter.emitterCells = cells
        layer.addSublayer(emitter)
        self.emitterLayer = emitter
        
        // Auto-stop after a burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            emitter.birthRate = 0
        }
    }
    
    func stopAnimation() {
        emitterLayer?.removeFromSuperlayer()
        emitterLayer = nil
    }
    
    // Helper to create a circle image for the particle
    private func createCircleImage(radius: CGFloat) -> UIImage? {
        let size = CGSize(width: radius * 2, height: radius * 2)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.setFillColor(UIColor.white.cgColor) // Color is tinted by emitter
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

// Extension for Hex Color
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        
        guard length == 6 || length == 8 else { return nil }
        
        if length == 6 {
            let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        } else {
            let r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(rgb & 0x000000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        }
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
        // Handle Command Pattern
        if let command = props["canvasCommand"] as? [String: Any] {
            // Pass the entire command object to the view
            // The view decides what to do based on "type"
            view.handleCommand(command)
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

