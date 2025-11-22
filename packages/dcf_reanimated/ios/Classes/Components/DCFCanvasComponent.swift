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
        return DCFCanvasView()
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let canvasView = view as? DCFCanvasView else { return false }
        canvasView.update(props: props)
        return true
    }
    
    // Handle tunnel methods from Dart
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        if method == "updateTexture" {
            guard let canvasId = params["canvasId"] as? String,
                  let pixels = params["pixels"] as? FlutterStandardTypedData,
                  let width = params["width"] as? Int,
                  let height = params["height"] as? Int else {
                return nil
            }
            
            if let view = DCFCanvasView.canvasViews[canvasId] {
                view.updateTexture(pixels: pixels.data, width: width, height: height)
                return true
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

class DCFCanvasView: UIView, FlutterTexture {
    // Static registry to track active canvas views by ID
    static var canvasViews: [String: DCFCanvasView] = [:]
    
    private var canvasId: String?
    private var textureId: Int64 = -1
    private var pixelBuffer: CVPixelBuffer?
    private var displayLink: CADisplayLink?
    private var repaintOnFrame: Bool = false
    private var onPaintCallback: FlutterCallbackInformation?
    
    // Layer to display the pixel buffer
    private var contentLayer: CALayer = CALayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        // DEBUG: Set red background to verify view is in hierarchy
        self.backgroundColor = UIColor.red.withAlphaComponent(0.3)
        NSLog("DCFCanvasView: init frame: \(frame)")
        setupLayer()
        registerTexture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.backgroundColor = UIColor.red.withAlphaComponent(0.3)
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
            if canvasId != id {
                // Unregister old ID if changed
                if let oldId = canvasId {
                    DCFCanvasView.canvasViews.removeValue(forKey: oldId)
                }
                canvasId = id
                DCFCanvasView.canvasViews[id] = self
            }
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
            let destination = baseAddress
            
            pixels.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
                if let sourceAddress = rawBuffer.baseAddress {
                    for y in 0..<height {
                        let srcRow = sourceAddress.advanced(by: y * width * 4)
                        let dstRow = destination.advanced(by: y * bytesPerRow)
                        memcpy(dstRow, srcRow, width * 4)
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
        drawFrame()
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
        if let id = canvasId {
            DCFCanvasView.canvasViews.removeValue(forKey: id)
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
