/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight
// SkiaRenderer is available automatically in the same module

// ============================================================================
// SKIA CANVAS COMPONENT - GPU-ACCELERATED 2D RENDERING
// ============================================================================

class DCFCanvasComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        print("🎨 SKIA Canvas: Creating Canvas view with props: \(props)")
        let canvasView = SkiaCanvasView()
        updateView(canvasView, withProps: props)
        return canvasView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let canvasView = view as? SkiaCanvasView else { 
            print("⚠️ SKIA Canvas: View is not SkiaCanvasView")
            return false 
        }
        
        print("🎨 SKIA Canvas: Updating view with props: \(props)")
        print("🎨 SKIA Canvas: View bounds: \(view.bounds), frame: \(view.frame)")
        
        // Update canvas configuration
        if let repaintOnFrame = props["repaintOnFrame"] as? Bool {
            canvasView.repaintOnFrame = repaintOnFrame
            print("🎨 SKIA Canvas: repaintOnFrame=\(repaintOnFrame)")
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
        
        // Ensure view is visible and trigger layout
        view.isHidden = false
        view.setNeedsLayout()
        
        return true
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        if let canvasView = view as? SkiaCanvasView {
            canvasView.nodeId = nodeId
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
        print("🎨 SKIA Canvas: Applied layout - frame: \(frame)")
        
        // Force layout update to trigger layoutSubviews
        if let canvasView = view as? SkiaCanvasView {
            canvasView.setNeedsLayout()
            canvasView.layoutIfNeeded()
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
// SKIA CANVAS VIEW - NATIVE SKIA RENDERING
// ============================================================================

class SkiaCanvasView: UIView {
    var nodeId: String?
    var repaintOnFrame: Bool = false
    
    // Skia surface and canvas
    private var skiaSurface: UnsafeMutableRawPointer?
    private var skiaCanvas: UnsafeMutableRawPointer?
    private var skiaContext: UnsafeMutableRawPointer?
    private var metalDevice: MTLDevice?
    private var displayLink: CADisplayLink?
    private var hasDrawnInitial = false
    private var lastSurfaceSize: CGSize = .zero
    private var isRendering = false
    
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
        
        print("🎨 SKIA Canvas: layoutSubviews called - bounds: \(bounds), frame: \(frame)")
        
        // Update Skia surface size when view is laid out
        updateSkiaSurfaceSize()
        
        // If repaintOnFrame is false, render once when we get valid bounds
        if !repaintOnFrame && bounds.width > 0 && bounds.height > 0 && !hasDrawnInitial {
            hasDrawnInitial = true
            print("🎨 SKIA Canvas: Rendering initial frame")
            DispatchQueue.main.async { [weak self] in
                self?.renderWithSkia()
            }
        }
    }
    
    private func updateSkiaSurfaceSize() {
        guard bounds.width > 0 && bounds.height > 0,
              let device = metalDevice,
              let metalLayer = self.layer as? CAMetalLayer else {
            print("⚠️ SKIA Canvas: Cannot update surface - bounds: \(bounds), device: \(metalDevice != nil), layer: \(type(of: self.layer))")
            return
        }
        
        print("🎨 SKIA Canvas: Updating surface size - bounds: \(bounds)")
        
        // Update Metal layer drawable size
        metalLayer.drawableSize = CGSize(
            width: bounds.width * contentScaleFactor,
            height: bounds.height * contentScaleFactor
        )
        
        // Check if size actually changed to prevent infinite loops
        let currentSize = CGSize(width: bounds.width, height: bounds.height)
        if lastSurfaceSize == currentSize && skiaSurface != nil {
            // Size hasn't changed and surface exists, don't recreate
            return
        }
        
        lastSurfaceSize = currentSize
        
        // Destroy old surface if exists
        let hadSurface = skiaSurface != nil
        if let surface = skiaSurface {
            SkiaRenderer.destroySurface(surface)
            skiaSurface = nil
            skiaCanvas = nil
            hasDrawnInitial = false // Reset flag when surface is destroyed
        }
        
        // Create new Skia surface with current size
        let width = Int32(bounds.width * contentScaleFactor)
        let height = Int32(bounds.height * contentScaleFactor)
        
        print("🎨 SKIA Canvas: Creating surface \(width)x\(height)")
        skiaSurface = SkiaRenderer.createSkiaSurface(
            Unmanaged.passUnretained(device).toOpaque(),
            layer: Unmanaged.passUnretained(metalLayer).toOpaque(),
            width: width,
            height: height
        )
        
        if skiaSurface != nil {
            print("✅ SKIA Canvas: Surface created successfully")
        } else {
            print("❌ SKIA Canvas: Failed to create surface")
        }
        
        // Canvas will be available after prepareSurfaceForRender is called
        // Don't try to get it here as surface is created lazily
        
        if repaintOnFrame {
            startDisplayLink()
            // Also render immediately when surface is created
            if !hadSurface {
                DispatchQueue.main.async { [weak self] in
                    self?.renderWithSkia()
                }
            }
        } else {
            // Draw once when surface is created (not repainting on frame)
            // Only draw if this is a new surface (not a resize of existing)
            if !hadSurface && !hasDrawnInitial {
                hasDrawnInitial = true
                // Use a small delay to ensure surface is fully ready
                DispatchQueue.main.async { [weak self] in
                    self?.renderWithSkia()
                }
            }
        }
    }
    
    private func startDisplayLink() {
        guard displayLink == nil else { 
            print("🎨 SKIA Canvas: Display link already running")
            return 
        }
        
        print("🎨 SKIA Canvas: Starting display link for repaintOnFrame")
        displayLink = CADisplayLink(target: self, selector: #selector(renderFrame))
        displayLink?.add(to: .main, forMode: .common)
        print("✅ SKIA Canvas: Display link started")
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func renderFrame() {
        guard repaintOnFrame else {
            print("🎨 SKIA Canvas: repaintOnFrame=false, stopping display link")
            stopDisplayLink()
            return
        }
        
        // Only render if we have valid surface
        guard skiaSurface != nil else {
            print("⚠️ SKIA Canvas: No surface in renderFrame")
            return
        }
        
        // Render using Skia
        renderWithSkia()
    }
    
    override func draw(_ rect: CGRect) {
        // Render using Skia canvas
        // Only render if we have a valid surface
        if skiaSurface != nil && skiaCanvas != nil {
            renderWithSkia()
        } else {
            print("⚠️ SKIA Canvas: Surface not ready in draw(_:)")
        }
    }
    
    private func renderWithSkia() {
        // Prevent concurrent rendering calls
        guard !isRendering else { 
            print("⚠️ SKIA Canvas: Already rendering, skipping")
            return 
        }
        isRendering = true
        defer { isRendering = false }
        
        guard let surface = skiaSurface,
              bounds.width > 0 && bounds.height > 0 else {
            if bounds.width == 0 || bounds.height == 0 {
                print("⚠️ SKIA Canvas: Bounds are zero: \(bounds)")
            } else {
                print("⚠️ SKIA Canvas: Surface is nil")
            }
            return
        }
        
        print("🎨 SKIA Canvas: Rendering - bounds: \(bounds)")
        
        // Prepare surface for rendering (gets new drawable)
        SkiaRenderer.prepareSurface(forRender: surface)
        
        // Get canvas after preparing surface
        guard let canvas = SkiaRenderer.getCanvasFromSurface(surface) else {
            print("⚠️ SKIA Canvas: Failed to get canvas after preparing surface")
            return
        }
        
        print("🎨 SKIA Canvas: Drawing test circle")
        
        // Draw test circle to verify Canvas is working
        // TODO: Replace with actual onPaint callback execution
        SkiaRenderer.drawTestCircle(
            canvas,
            width: Float(bounds.width),
            height: Float(bounds.height)
        )
        
        // Flush Skia surface to Metal
        SkiaRenderer.flushSurface(surface)
        
        print("✅ SKIA Canvas: Render completed and flushed")
        
        // For CAMetalLayer, we don't use setNeedsDisplay() as it causes infinite loops
        // The display link or manual rendering handles updates
    }
    
    deinit {
        stopDisplayLink()
        if let surface = skiaSurface {
            SkiaRenderer.destroySurface(surface)
        }
    }
}

