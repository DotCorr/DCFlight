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

