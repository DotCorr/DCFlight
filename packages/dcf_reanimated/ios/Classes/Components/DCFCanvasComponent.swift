/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

// ============================================================================
// SKIA CANVAS COMPONENT - GPU-ACCELERATED 2D RENDERING
// ============================================================================

class DCFCanvasComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let canvasView = SkiaCanvasView()
        updateView(canvasView, withProps: props)
        return canvasView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let canvasView = view as? SkiaCanvasView else { return false }
        
        // Update canvas configuration
        if let repaintOnFrame = props["repaintOnFrame"] as? Bool {
            canvasView.repaintOnFrame = repaintOnFrame
        }
        
        if let backgroundColor = props["backgroundColor"] as? Int {
            canvasView.backgroundColor = UIColor(
                red: CGFloat((backgroundColor >> 16) & 0xFF) / 255.0,
                green: CGFloat((backgroundColor >> 8) & 0xFF) / 255.0,
                blue: CGFloat(backgroundColor & 0xFF) / 255.0,
                alpha: CGFloat((backgroundColor >> 24) & 0xFF) / 255.0
            )
        } else {
            canvasView.backgroundColor = .clear
        }
        
        view.applyStyles(props: props)
        return true
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        if let canvasView = view as? SkiaCanvasView {
            canvasView.nodeId = nodeId
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
// SKIA CANVAS VIEW - NATIVE SKIA RENDERING
// ============================================================================

class SkiaCanvasView: UIView {
    var nodeId: String?
    var repaintOnFrame: Bool = false
    
    // Skia surface and canvas
    private var skiaSurface: OpaquePointer?
    private var skiaCanvas: OpaquePointer?
    private var skiaContext: OpaquePointer?
    private var metalDevice: MTLDevice?
    private var displayLink: CADisplayLink?
    
    override class var layerClass: AnyClass {
        // Use CAMetalLayer for GPU acceleration
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
        
        // Initialize Skia with Metal backend
        // This creates a Skia surface backed by Metal
        initializeSkiaMetal()
    }
    
    private func initializeSkiaMetal() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let metalLayer = self.layer as? CAMetalLayer else {
            print("⚠️ SKIA: Metal not available")
            return
        }
        
        metalDevice = device
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.isOpaque = false
        
        print("🎨 SKIA: Metal layer configured")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update Skia surface size when view is laid out
        updateSkiaSurfaceSize()
    }
    
    private func updateSkiaSurfaceSize() {
        guard bounds.width > 0 && bounds.height > 0,
              let device = metalDevice,
              let metalLayer = self.layer as? CAMetalLayer else { return }
        
        // Destroy old surface if exists
        if let surface = skiaSurface {
            SkiaRenderer.destroySurface(surface)
            skiaSurface = nil
            skiaCanvas = nil
        }
        
        // Create new Skia surface with current size
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
            print("🎨 SKIA: Created surface \(width)x\(height)")
        }
        
        if repaintOnFrame {
            startDisplayLink()
        }
    }
    
    private func startDisplayLink() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(renderFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func renderFrame() {
        guard repaintOnFrame else {
            stopDisplayLink()
            return
        }
        
        // Render using Skia
        renderWithSkia()
    }
    
    override func draw(_ rect: CGRect) {
        // Render using Skia canvas
        renderWithSkia()
    }
    
    private func renderWithSkia() {
        guard let surface = skiaSurface,
              let canvas = skiaCanvas,
              bounds.width > 0 && bounds.height > 0 else {
            return
        }
        
        // Get SkCanvas from surface and render
        // Canvas is already available from skiaCanvas pointer
        // Actual drawing operations will be done via C++ Skia API calls
        // through the bridging header
        
        // Flush Skia surface to Metal
        SkiaRenderer.flushSurface(surface)
    }
    
    deinit {
        stopDisplayLink()
        if let surface = skiaSurface {
            SkiaRenderer.destroySurface(surface)
        }
    }
}

