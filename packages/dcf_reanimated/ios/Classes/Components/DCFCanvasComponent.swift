/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Flutter
import dcflight

/// Lightweight UIView that displays pixel data received from Dart via tunnel
class DCFCanvasView: UIView {
    var imageLayer: CALayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageLayer = CALayer()
        if let imageLayer = imageLayer {
            layer.addSublayer(imageLayer)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageLayer?.frame = bounds
    }
    
    func updatePixels(data: Data, width: Int, height: Int) {
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            print("⚠️ DCFCanvasView: Failed to create CGImage from pixel data")
            return
        }
        
        imageLayer?.contents = cgImage
    }
}

class DCFCanvasComponent: NSObject, DCFComponent {
    
    // Registry to track canvasId -> viewId mapping
    private static var canvasRegistry: [String: Int] = [:]
    
    override required init() { super.init() }
    
    func createView(props: [String: Any]) -> UIView {
        let view = DCFCanvasView()
        
        // Store canvasId in view for later registration
        if let canvasId = props["canvasId"] as? String {
            objc_setAssociatedObject(view,
                                   UnsafeRawPointer(bitPattern: "canvasId".hashValue)!,
                                   canvasId,
                                   .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // Update canvasId if changed
        if let canvasId = props["canvasId"] as? String {
            objc_setAssociatedObject(view,
                                   UnsafeRawPointer(bitPattern: "canvasId".hashValue)!,
                                   canvasId,
                                   .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return true
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
        let width = (props["width"] as? NSNumber)?.doubleValue ?? 0
        let height = (props["height"] as? NSNumber)?.doubleValue ?? 0
        return CGSize(width: width, height: height)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Store mapping when view is registered
        if let canvasId = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "canvasId".hashValue)!) as? String,
           let viewId = Int(nodeId) {
            DCFCanvasComponent.canvasRegistry[canvasId] = viewId
        }
    }
    
    func prepareForRecycle(_ view: UIView) {
        // Cleanup: remove from registry when view is recycled
        // Find and remove any entries pointing to this view
        if let canvasId = objc_getAssociatedObject(view, UnsafeRawPointer(bitPattern: "canvasId".hashValue)!) as? String {
            DCFCanvasComponent.canvasRegistry.removeValue(forKey: canvasId)
        }
    }

    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        switch method {
        case "updatePixels":
            // Dart sends: canvasId, pixels (Data), width, height
            guard let canvasId = params["canvasId"] as? String,
                  let viewId = canvasRegistry[canvasId],
                  let canvasView = ViewRegistry.shared.getView(id: viewId) as? DCFCanvasView,
                  let pixelsData = params["pixels"] as? FlutterStandardTypedData,
                  let width = params["width"] as? Int,
                  let height = params["height"] as? Int else {
                return false // View not ready or invalid params
            }
            
            canvasView.updatePixels(data: pixelsData.data, width: width, height: height)
            return true
            
        default:
            return nil
        }
    }
}

