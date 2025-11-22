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
        let canvasView = SkiaCanvasView()
        updateView(canvasView, withProps: props)
        return canvasView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let canvasView = view as? SkiaCanvasView else { 
            return false 
        }
        
        // Update canvas configuration
        if let repaintOnFrame = props["repaintOnFrame"] as? Bool {
            canvasView.repaintOnFrame = repaintOnFrame
        }
        
        if let hasOnPaint = props["onPaint"] as? Bool {
            canvasView.hasOnPaint = hasOnPaint
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
        
        // Parse shapes from props
        if let shapes = props["shapes"] as? [[String: Any]] {
            canvasView.shapes = shapes
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

// Particle structure for Swift
struct Particle {
    var x: Double
    var y: Double
    var vx: Double  // velocity x
    var vy: Double  // velocity y
    var size: Double
    var color: UInt32  // ARGB
}

class SkiaCanvasView: UIView {
    var nodeId: String?
    var repaintOnFrame: Bool = false
    var hasOnPaint: Bool = false  // Whether onPaint callback is provided
    var shapes: [[String: Any]] = []  // Shapes to render
    
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
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update Skia surface size when view is laid out
        updateSkiaSurfaceSize()
        
        // If repaintOnFrame is false, render once when we get valid bounds
        if !repaintOnFrame && bounds.width > 0 && bounds.height > 0 && !hasDrawnInitial {
            hasDrawnInitial = true
            DispatchQueue.main.async { [weak self] in
                self?.renderWithSkia()
            }
        }
    }
    
    private func updateSkiaSurfaceSize() {
        guard bounds.width > 0 && bounds.height > 0,
              let device = metalDevice,
              let metalLayer = self.layer as? CAMetalLayer else {
            return
        }
        
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
        
        skiaSurface = SkiaRenderer.createSkiaSurface(
            Unmanaged.passUnretained(device).toOpaque(),
            layer: Unmanaged.passUnretained(metalLayer).toOpaque(),
            width: width,
            height: height
        )
        
        // Canvas will be available after prepareSurfaceForRender is called
        // Don't try to get it here as surface is created lazily
        
        if repaintOnFrame {
            // Only start display link if not already running
            if displayLink == nil {
                startDisplayLink()
            }
            // Don't render immediately - let display link handle it
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
            return 
        }
        
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
        
        // Only render if we have valid surface and view is visible
        guard skiaSurface != nil,
              !isHidden,
              alpha > 0,
              superview != nil else {
            return
        }
        
        renderWithSkia()
    }
    
    override func draw(_ rect: CGRect) {
        // Render using Skia canvas
        // Only render if we have a valid surface
        if skiaSurface != nil && skiaCanvas != nil {
            renderWithSkia()
        }
    }
    
    private func renderWithSkia() {
        // Prevent concurrent rendering calls
        guard !isRendering else { 
            return 
        }
        isRendering = true
        defer { isRendering = false }
        
        guard let surface = skiaSurface,
              bounds.width > 0 && bounds.height > 0 else {
            return
        }
        
        // Prepare surface for rendering (gets new drawable)
        SkiaRenderer.prepareSurface(forRender: surface)
        
        // Get canvas after preparing surface
        guard let canvas = SkiaRenderer.getCanvasFromSurface(surface) else {
            return
        }
        
        let surfaceWidth = Float(bounds.width * contentScaleFactor)
        let surfaceHeight = Float(bounds.height * contentScaleFactor)
        
        // Render shapes
        if !shapes.isEmpty {
            renderShapes(canvas: canvas)
        } else if hasOnPaint {
            // onPaint callback will be called via method channel when implemented
            // For now, draw a test circle to show the canvas is working
            SkiaRenderer.drawTestCircle(
                canvas,
                width: surfaceWidth,
                height: surfaceHeight
            )
        } else {
            // Draw test circle to verify Canvas is working (centered)
            SkiaRenderer.drawTestCircle(
                canvas,
                width: surfaceWidth,
                height: surfaceHeight
            )
        }
        
        // Flush Skia surface to Metal
        SkiaRenderer.flushSurface(surface)
        
        // For CAMetalLayer, we don't use setNeedsDisplay() as it causes infinite loops
        // The display link or manual rendering handles updates
    }
    
    // MARK: - Shape Rendering
    
    private func renderShapes(canvas: UnsafeMutableRawPointer) {
        renderShapesRecursive(canvas: canvas, shapes: shapes)
    }
    
    private func renderShapesRecursive(canvas: UnsafeMutableRawPointer, shapes: [[String: Any]]) {
        for shape in shapes {
            guard let type = shape["_type"] as? String else { continue }
            
            if type == "SkiaGroup" {
                // Handle Group - apply transformations, clipping, and render children
                renderGroup(canvas: canvas, group: shape)
            } else {
                // Render regular shape
                renderShape(canvas: canvas, shape: shape)
            }
        }
    }
    
    private func renderGroup(canvas: UnsafeMutableRawPointer, group: [String: Any]) {
        // Save canvas state
        SkiaRenderer.saveCanvas(canvas)
        
        // Apply transformations
        if let transform = group["transform"] as? [[String: Any]] {
            for t in transform {
                if let translateX = t["translateX"] as? Double {
                    SkiaRenderer.translateCanvas(canvas, dx: Float(translateX), dy: 0)
                }
                if let translateY = t["translateY"] as? Double {
                    SkiaRenderer.translateCanvas(canvas, dx: 0, dy: Float(translateY))
                }
                if let translate = t["translate"] as? [Double], translate.count >= 2 {
                    SkiaRenderer.translateCanvas(canvas, dx: Float(translate[0]), dy: Float(translate[1]))
                }
                if let rotate = t["rotate"] as? Double {
                    SkiaRenderer.rotateCanvas(canvas, degrees: Float(rotate))
                }
                if let scaleX = t["scaleX"] as? Double {
                    SkiaRenderer.scaleCanvas(canvas, sx: Float(scaleX), sy: 1.0)
                }
                if let scaleY = t["scaleY"] as? Double {
                    SkiaRenderer.scaleCanvas(canvas, sx: 1.0, sy: Float(scaleY))
                }
                if let scale = t["scale"] as? [Double], scale.count >= 2 {
                    SkiaRenderer.scaleCanvas(canvas, sx: Float(scale[0]), sy: Float(scale[1]))
                }
                if let skewX = t["skewX"] as? Double {
                    SkiaRenderer.skewCanvas(canvas, sx: Float(skewX), sy: 0)
                }
                if let skewY = t["skewY"] as? Double {
                    SkiaRenderer.skewCanvas(canvas, sx: 0, sy: Float(skewY))
                }
            }
        }
        
        // Apply clipping
        if let clip = group["clip"] as? [String: Any] {
            if let x = clip["x"] as? Double,
               let y = clip["y"] as? Double,
               let width = clip["width"] as? Double,
               let height = clip["height"] as? Double {
                if let r = clip["r"] as? Double {
                    SkiaRenderer.clipRRect(canvas, x: Float(x), y: Float(y), width: Float(width), height: Float(height), r: Float(r))
                } else {
                    SkiaRenderer.clipRect(canvas, x: Float(x), y: Float(y), width: Float(width), height: Float(height))
                }
            } else if let pathString = clip["pathString"] as? String {
                SkiaRenderer.clipPath(canvas, pathString: pathString)
            }
        }
        
        // Render children
        if let children = group["_children"] as? [[String: Any]] {
            renderShapesRecursive(canvas: canvas, shapes: children)
        }
        
        // Restore canvas state
        SkiaRenderer.restoreCanvas(canvas)
    }
    
    private func renderShape(canvas: UnsafeMutableRawPointer, shape: [String: Any]) {
        guard let type = shape["_type"] as? String else { return }
        
        // Create paint for this shape
        let paint = SkiaRenderer.createPaint()
        defer { SkiaRenderer.destroyPaint(paint) }
        
        // Apply paint properties
        if let color = parseShapeColor(shape["color"]) {
            SkiaRenderer.setPaintColor(paint, color: color)
        }
        
        if let opacity = shape["opacity"] as? Double {
            SkiaRenderer.setPaintOpacity(paint, opacity: Float(opacity))
        }
        
        if let style = shape["style"] as? String {
            let styleInt = style == "stroke" ? 1 : 0
            SkiaRenderer.setPaintStyle(paint, style: Int32(styleInt))
        }
        
        if let strokeWidth = shape["strokeWidth"] as? Double {
            SkiaRenderer.setPaintStrokeWidth(paint, width: Float(strokeWidth))
        }
        
        if let blendMode = shape["blendMode"] as? String {
            let blendModeInt = parseBlendMode(blendMode)
            SkiaRenderer.setPaintBlendMode(paint, blendMode: Int32(blendModeInt))
        }
        
        // Apply shader if present
        if let shader = shape["_shader"] as? [String: Any] {
            if let shaderPtr = createShader(from: shader) {
                SkiaRenderer.setPaintShader(paint, shader: shaderPtr)
                defer { SkiaRenderer.destroyShader(shaderPtr) }
            }
        }
        
        // Render based on type
        switch type {
            case "SkiaRect":
                if let x = shape["x"] as? Double,
                   let y = shape["y"] as? Double,
                   let width = shape["width"] as? Double,
                   let height = shape["height"] as? Double {
                    SkiaRenderer.drawRect(
                        canvas,
                        x: Float(x),
                        y: Float(y),
                        width: Float(width),
                        height: Float(height),
                        paint: paint
                    )
                }
                
            case "SkiaRoundedRect":
                if let x = shape["x"] as? Double,
                   let y = shape["y"] as? Double,
                   let width = shape["width"] as? Double,
                   let height = shape["height"] as? Double {
                    let r = Float(shape["r"] as? Double ?? shape["rx"] as? Double ?? 0)
                    SkiaRenderer.drawRoundedRect(
                        canvas,
                        x: Float(x),
                        y: Float(y),
                        width: Float(width),
                        height: Float(height),
                        r: r,
                        paint: paint
                    )
                }
                
            case "SkiaCircle":
                if let cx = shape["cx"] as? Double,
                   let cy = shape["cy"] as? Double,
                   let r = shape["r"] as? Double {
                    SkiaRenderer.drawCircle(
                        canvas,
                        cx: Float(cx),
                        cy: Float(cy),
                        r: Float(r),
                        paint: paint
                    )
                }
                
            case "SkiaOval":
                if let x = shape["x"] as? Double,
                   let y = shape["y"] as? Double,
                   let width = shape["width"] as? Double,
                   let height = shape["height"] as? Double {
                    SkiaRenderer.drawOval(
                        canvas,
                        x: Float(x),
                        y: Float(y),
                        width: Float(width),
                        height: Float(height),
                        paint: paint
                    )
                }
                
            case "SkiaLine":
                if let x1 = shape["x1"] as? Double,
                   let y1 = shape["y1"] as? Double,
                   let x2 = shape["x2"] as? Double,
                   let y2 = shape["y2"] as? Double {
                    SkiaRenderer.drawLine(
                        canvas,
                        x1: Float(x1),
                        y1: Float(y1),
                        x2: Float(x2),
                        y2: Float(y2),
                        paint: paint
                    )
                }
                
            case "SkiaPath":
                if let pathString = shape["pathString"] as? String {
                    SkiaRenderer.drawPath(
                        canvas,
                        pathString: pathString,
                        paint: paint
                    )
                }
                
            case "SkiaFill":
                // Fill entire canvas
                let surfaceWidth = Float(bounds.width * contentScaleFactor)
                let surfaceHeight = Float(bounds.height * contentScaleFactor)
                SkiaRenderer.drawRect(
                    canvas,
                    x: 0,
                    y: 0,
                    width: surfaceWidth,
                    height: surfaceHeight,
                    paint: paint
                )
                
            case "SkiaImage":
                if let imageSource = shape["image"] as? String {
                    // Load image (simplified - would need proper image loading)
                    // For now, this is a placeholder
                    // In production, you'd load from asset, network, or file system
                }
                
            case "SkiaText":
                if let text = shape["text"] as? String,
                   let x = shape["x"] as? Double,
                   let y = shape["y"] as? Double {
                    let fontSize = Float(shape["fontSize"] as? Double ?? 16)
                    let fontFamily = shape["fontFamily"] as? String
                    let fontWeight = shape["fontWeight"] as? Int ?? 4 // Normal
                    let fontStyle = shape["fontStyle"] as? Int ?? 0 // Normal
                    
                    if let font = SkiaRenderer.createFont(fontFamily ?? "System", size: fontSize, weight: Int32(fontWeight), style: Int32(fontStyle)) {
                        defer { SkiaRenderer.destroyFont(font) }
                        SkiaRenderer.drawText(canvas, text: text, x: Float(x), y: Float(y), font: font, paint: paint)
                    }
                }
                
            default:
                break
        }
        
        // Apply path effects if present
        if let pathEffect = shape["_pathEffect"] as? [String: Any] {
            if let pathEffectPtr = createPathEffect(from: pathEffect) {
                SkiaRenderer.setPaintPathEffect(paint, pathEffect: pathEffectPtr)
                defer { SkiaRenderer.destroyPathEffect(pathEffectPtr) }
            }
        }
        
        // Apply color filters if present
        if let colorFilter = shape["_colorFilter"] as? [String: Any] {
            if let filterPtr = createColorFilter(from: colorFilter) {
                SkiaRenderer.setPaintColorFilter(paint, filter: filterPtr)
                defer { SkiaRenderer.destroyColorFilter(filterPtr) }
            }
        }
        
        // Apply image filters if present
        if let filters = shape["_filters"] as? [[String: Any]] {
            for filterData in filters {
                if let filterPtr = createImageFilter(from: filterData) {
                    SkiaRenderer.setPaintImageFilter(paint, filter: filterPtr)
                    defer { SkiaRenderer.destroyImageFilter(filterPtr) }
                }
            }
        }
        
        // Apply backdrop filters if present
        if let backdropFilters = shape["_backdropFilters"] as? [[String: Any]] {
            // Backdrop filters require layer rendering
            // This would be implemented with canvas layers
        }
    }
    
    private func createColorFilter(from filterData: [String: Any]) -> UnsafeMutableRawPointer? {
        guard let type = filterData["_type"] as? String else { return nil }
        
        switch type {
        case "SkiaColorMatrix":
            if let matrix = filterData["matrix"] as? [Double], matrix.count == 20 {
                var floatMatrix = matrix.map { Float($0) }
                return floatMatrix.withUnsafeMutableBufferPointer { buffer in
                    guard let baseAddress = buffer.baseAddress else { return nil }
                    return SkiaRenderer.createColorFilterMatrix(baseAddress)
                }
            }
            
        case "SkiaBlendColor":
            if let color = parseShapeColor(filterData["color"]),
               let mode = filterData["mode"] as? String {
                let blendModeInt = parseBlendMode(mode)
                return SkiaRenderer.createColorFilterBlend(color, mode: Int32(blendModeInt))
            }
            
        default:
            break
        }
        
        return nil
    }
    
    private func createPathEffect(from effectData: [String: Any]) -> UnsafeMutableRawPointer? {
        guard let type = effectData["_type"] as? String else { return nil }
        
        switch type {
        case "SkiaDiscretePathEffect":
            if let length = effectData["length"] as? Double,
               let deviation = effectData["deviation"] as? Double {
                let seed = Float(effectData["seed"] as? Double ?? 0)
                return SkiaRenderer.createDiscretePathEffect(Float(length), deviation: Float(deviation), seed: seed)
            }
            
        case "SkiaDashPathEffect":
            if let intervals = effectData["intervals"] as? [Double] {
                var floatIntervals = intervals.map { Float($0) }
                let phase = Float(effectData["phase"] as? Double ?? 0)
                return floatIntervals.withUnsafeMutableBufferPointer { buffer in
                    guard let baseAddress = buffer.baseAddress else { return nil }
                    return SkiaRenderer.createDashPathEffect(baseAddress, count: Int32(intervals.count), phase: phase)
                }
            }
            
        case "SkiaCornerPathEffect":
            if let r = effectData["r"] as? Double {
                return SkiaRenderer.createCornerPathEffect(Float(r))
            }
            
        default:
            break
        }
        
        return nil
    }
    
    private func createImageFilter(from filterData: [String: Any]) -> UnsafeMutableRawPointer? {
        guard let type = filterData["_type"] as? String else { return nil }
        
        switch type {
        case "SkiaBlur":
            if let blur = filterData["blur"] as? Double {
                let mode: Int32 = 0 // clamp
                return SkiaRenderer.createBlurFilter(Float(blur), blurY: Float(blur), mode: mode)
            }
            
        case "SkiaColorMatrix":
            if let matrix = filterData["matrix"] as? [Double], matrix.count == 20 {
                var floatMatrix = matrix.map { Float($0) }
                return floatMatrix.withUnsafeMutableBufferPointer { buffer in
                    guard let baseAddress = buffer.baseAddress else { return nil }
                    return SkiaRenderer.createColorMatrixFilter(baseAddress)
                }
            }
            
        case "SkiaDropShadow":
            if let dx = filterData["dx"] as? Double,
               let dy = filterData["dy"] as? Double,
               let blur = filterData["blur"] as? Double,
               let color = parseShapeColor(filterData["color"]) {
                return SkiaRenderer.createDropShadowFilter(Float(dx), dy: Float(dy), blurX: Float(blur), blurY: Float(blur), color: color)
            }
            
        case "SkiaOffset":
            if let x = filterData["x"] as? Double,
               let y = filterData["y"] as? Double {
                return SkiaRenderer.createOffsetFilter(Float(x), y: Float(y))
            }
            
        case "SkiaMorphology":
            if let radius = filterData["radius"] as? Double,
               let opType = filterData["operator"] as? String {
                let op: Int32 = opType == "erode" ? 0 : 1
                return SkiaRenderer.createMorphologyFilter(op, radiusX: Float(radius), radiusY: Float(radius))
            }
            
        default:
            break
        }
        
        return nil
    }
    
    private func createShader(from shaderData: [String: Any]) -> UnsafeMutableRawPointer? {
        guard let type = shaderData["_type"] as? String else { return nil }
        
        switch type {
        case "SkiaLinearGradient":
            if let x0 = shaderData["x0"] as? Double,
               let y0 = shaderData["y0"] as? Double,
               let x1 = shaderData["x1"] as? Double,
               let y1 = shaderData["y1"] as? Double,
               let colors = shaderData["colors"] as? [Any] {
                let stops = shaderData["stops"] as? [Double]
                let nsColors = NSArray(array: colors)
                let nsStops = stops != nil ? NSArray(array: stops!) : NSArray()
                return SkiaRenderer.createLinearGradient(
                    Float(x0),
                    y0: Float(y0),
                    x1: Float(x1),
                    y1: Float(y1),
                    colors: Array(nsColors),
                    stops: Array(nsStops)
                )
            }
            
        case "SkiaRadialGradient":
            if let cx = shaderData["cx"] as? Double,
               let cy = shaderData["cy"] as? Double,
               let r = shaderData["r"] as? Double,
               let colors = shaderData["colors"] as? [Any] {
                let stops = shaderData["stops"] as? [Double]
                let nsColors = NSArray(array: colors)
                let nsStops = stops != nil ? NSArray(array: stops!) : NSArray()
                return SkiaRenderer.createRadialGradient(
                    Float(cx),
                    cy: Float(cy),
                    r: Float(r),
                    colors: Array(nsColors),
                    stops: Array(nsStops)
                )
            }
            
        case "SkiaConicGradient":
            if let cx = shaderData["cx"] as? Double,
               let cy = shaderData["cy"] as? Double,
               let colors = shaderData["colors"] as? [Any] {
                let startAngle = (shaderData["startAngle"] as? Double) ?? 0
                let stops = shaderData["stops"] as? [Double]
                let nsColors = NSArray(array: colors)
                let nsStops = stops != nil ? NSArray(array: stops!) : NSArray()
                return SkiaRenderer.createConicGradient(
                    Float(cx),
                    cy: Float(cy),
                    startAngle: Float(startAngle),
                    colors: Array(nsColors),
                    stops: Array(nsStops)
                )
            }
            
        default:
            break
        }
        
        return nil
    }
    
    private func parseBlendMode(_ mode: String) -> Int {
        switch mode {
        case "clear": return 0
        case "src": return 1
        case "dst": return 2
        case "srcOver": return 3
        case "dstOver": return 4
        case "srcIn": return 5
        case "dstIn": return 6
        case "srcOut": return 7
        case "dstOut": return 8
        case "srcATop": return 9
        case "dstATop": return 10
        case "xor": return 11
        case "plus": return 12
        case "modulate": return 13
        case "screen": return 14
        case "overlay": return 15
        case "darken": return 16
        case "lighten": return 17
        case "colorDodge": return 18
        case "colorBurn": return 19
        case "hardLight": return 20
        case "softLight": return 21
        case "difference": return 22
        case "exclusion": return 23
        case "multiply": return 24
        case "hue": return 25
        case "saturation": return 26
        case "color": return 27
        case "luminosity": return 28
        default: return 3 // srcOver
        }
    }
    
    private func parseShapeColor(_ color: Any?) -> UInt32? {
        guard let color = color else { return nil }
        
        if let colorInt = color as? Int {
            return UInt32(bitPattern: Int32(colorInt))
        }
        
        if let colorStr = color as? String {
            return parseColorString(colorStr)
        }
        
        return nil
    }
    
    private func parseColorString(_ hex: String) -> UInt32 {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        // Convert RGB to ARGB (with full alpha)
        let r = UInt32((rgb >> 16) & 0xFF)
        let g = UInt32((rgb >> 8) & 0xFF)
        let b = UInt32(rgb & 0xFF)
        return (0xFF << 24) | (r << 16) | (g << 8) | b
    }
    
    private func loadImage(from source: String) -> UnsafeMutableRawPointer? {
        // Try loading from asset bundle first
        if let assetPath = Bundle.main.path(forResource: source, ofType: nil) {
            return SkiaRenderer.loadImage(fromPath: assetPath)
        }
        
        // Try loading from file system
        if FileManager.default.fileExists(atPath: source) {
            return SkiaRenderer.loadImage(fromPath: source)
        }
        
        // Try loading from network (synchronous for now - in production would use async)
        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            if let url = URL(string: source),
               let data = try? Data(contentsOf: url) {
                return SkiaRenderer.loadImage(from: data)
            }
        }
        
        // Try loading from data URI
        if source.hasPrefix("data:image/") {
            let components = source.components(separatedBy: ",")
            if components.count == 2,
               let data = Data(base64Encoded: components[1], options: .ignoreUnknownCharacters) {
                return SkiaRenderer.loadImage(from: data)
            }
        }
        
        return nil
    }
    
    deinit {
        stopDisplayLink()
        if let surface = skiaSurface {
            SkiaRenderer.destroySurface(surface)
        }
    }
}

