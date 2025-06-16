/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

/// Component that implements animated text
class DCFAnimatedTextComponent: NSObject, DCFComponent, ComponentMethodHandler {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Create animated label
        let animatedLabel = AnimatedLabel()
        
        // Set up adaptive text color
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                animatedLabel.textColor = UIColor.label
            } else {
                animatedLabel.textColor = UIColor.black
            }
        } else {
            animatedLabel.textColor = UIColor.black
        }
        
        // Apply props
        updateView(animatedLabel, withProps: props)
        
        // Apply StyleSheet properties
        animatedLabel.applyStyles(props: props)
        
        return animatedLabel
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let animatedLabel = view as? AnimatedLabel else { 
            print("❌ DCFAnimatedTextComponent: Failed to cast view to AnimatedLabel")
            return false 
        }
        
        print("🔄 DCFAnimatedTextComponent: Updating view with props: \(props.keys)")
        
        // Apply text properties
        if let content = props["content"] as? String {
            animatedLabel.text = content
            print("📝 DCFAnimatedTextComponent: Set text content to: \(content)")
        }
        
        // Handle font properties only if they are provided (for incremental updates)
        let hasAnyFontProp = props["fontSize"] != nil || props["fontWeight"] != nil || 
                            props["fontFamily"] != nil || props["isFontAsset"] != nil
        
        if hasAnyFontProp {
            // Get font size (use current font size as fallback if not specified)
            let fontSize = props["fontSize"] as? CGFloat ?? animatedLabel.font?.pointSize ?? UIFont.systemFontSize
            
            // Determine font weight using centralized utility
            var fontWeight = UIFont.Weight.regular
            if let fontWeightString = props["fontWeight"] as? String {
                fontWeight = fontWeightFromString(fontWeightString)
            }
            
            // Check if font is from an asset (with isFontAsset flag)
            let isFontAsset = props["isFontAsset"] as? Bool ?? false
            
            // Set font family if specified
            if let fontFamily = props["fontFamily"] as? String {
                if isFontAsset {
                    // Use font from asset
                    if let fontCached = DCFTextComponent.fontCache[fontFamily] {
                        animatedLabel.font = fontCached
                    } else if let customFont = UIFont(name: fontFamily, size: fontSize) {
                        DCFTextComponent.fontCache[fontFamily] = customFont
                        animatedLabel.font = customFont
                    } else {
                        animatedLabel.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
                    }
                } else {
                    // Use system font with family
                    animatedLabel.font = UIFont(name: fontFamily, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
                }
            } else {
                // Use system font
                animatedLabel.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
            }
            print("🎨 DCFAnimatedTextComponent: Updated font properties")
        }
        
        // Handle color property - this is the key fix for incremental updates
        if props.keys.contains("color") {
            if let color = props["color"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: color)
                animatedLabel.textColor = uiColor
                print("🎨 DCFAnimatedTextComponent: Set text color to: \(color) -> \(uiColor)")
            } else {
                print("⚠️ DCFAnimatedTextComponent: Color prop present but invalid value: \(props["color"] ?? "nil")")
            }
        }
        
        // Handle adaptive color only if explicitly provided or if no color is set at all
        if props.keys.contains("adaptive") && !props.keys.contains("color") {
            let isAdaptive = props["adaptive"] as? Bool ?? true
            if isAdaptive {
                if #available(iOS 13.0, *) {
                    animatedLabel.textColor = UIColor.label
                } else {
                    animatedLabel.textColor = UIColor.black
                }
                print("🎨 DCFAnimatedTextComponent: Applied adaptive color")
            }
        }
        
        // Set text alignment if specified
        if let textAlign = props["textAlign"] as? String {
            switch textAlign.lowercased() {
            case "center":
                animatedLabel.textAlignment = .center
            case "right":
                animatedLabel.textAlignment = .right
            case "justify":
                animatedLabel.textAlignment = .justified
            default:
                animatedLabel.textAlignment = .left
            }
            print("📐 DCFAnimatedTextComponent: Set text alignment to: \(textAlign)")
        }
        
        // Set number of lines if specified
        if let numberOfLines = props["numberOfLines"] as? Int {
            animatedLabel.numberOfLines = numberOfLines
            print("📄 DCFAnimatedTextComponent: Set number of lines to: \(numberOfLines)")
        }
        
        // Apply animation properties
        if let duration = props["animationDuration"] as? Int {
            animatedLabel.animationDuration = TimeInterval(duration) / 1000.0
            print("⏱️ DCFAnimatedTextComponent: Set animation duration to: \(duration)ms")
        }
        
        if let curve = props["animationCurve"] as? String {
            animatedLabel.animationCurve = getCurve(from: curve)
            print("📈 DCFAnimatedTextComponent: Set animation curve to: \(curve)")
        }
        
        if let delay = props["animationDelay"] as? Int {
            animatedLabel.animationDelay = TimeInterval(delay) / 1000.0
            print("⏸️ DCFAnimatedTextComponent: Set animation delay to: \(delay)ms")
        }
        
        if let animRepeat = props["animationRepeat"] as? Bool {
            animatedLabel.animationRepeat = animRepeat
            print("🔄 DCFAnimatedTextComponent: Set animation repeat to: \(animRepeat)")
        }
        
        // Store target values for animation
        if let toScale = props["toScale"] as? CGFloat {
            animatedLabel.targetScale = toScale
            print("📏 DCFAnimatedTextComponent: Set target scale to: \(toScale)")
        }
        
        if let toOpacity = props["toOpacity"] as? CGFloat {
            animatedLabel.targetOpacity = toOpacity
            print("👻 DCFAnimatedTextComponent: Set target opacity to: \(toOpacity)")
        }
        
        if let toTranslateX = props["toTranslateX"] as? CGFloat {
            animatedLabel.targetTranslationX = toTranslateX
            print("➡️ DCFAnimatedTextComponent: Set target translation X to: \(toTranslateX)")
        }
        
        if let toTranslateY = props["toTranslateY"] as? CGFloat {
            animatedLabel.targetTranslationY = toTranslateY
            print("⬇️ DCFAnimatedTextComponent: Set target translation Y to: \(toTranslateY)")
        }
        
        // Automatically start animation after layout
        animatedLabel.needsAnimation = true
        
        // Apply StyleSheet properties
        animatedLabel.applyStyles(props: props)
        
        print("✅ DCFAnimatedTextComponent: Successfully updated view")
        return true
    }
    
    // MARK: - Animation Helpers
    
    private func getCurve(from name: String) -> UIView.AnimationOptions {
        switch name.lowercased() {
        case "linear":
            return .curveLinear
        case "easein":
            return .curveEaseIn
        case "easeout":
            return .curveEaseOut
        case "easeinout":
            return .curveEaseInOut
        default:
            return .curveEaseInOut
        }
    }
    
    // MARK: - Method Handling
    
    func handleMethod(methodName: String, args: [String: Any], view: UIView) -> Bool {
        guard let animatedLabel = view as? AnimatedLabel else { return false }
        
        switch methodName {
        case "setText":
            if let text = args["text"] as? String {
                let duration = args["duration"] as? TimeInterval ?? animatedLabel.animationDuration
                let curve = args["curve"] as? String
                
                // Animate text change
                animatedLabel.setText(text, duration: duration, curve: curve.map { getCurve(from: $0) })
                return true
            }
            
        case "animate":
            // Set animation properties from method args
            if let duration = args["duration"] as? Int {
                animatedLabel.animationDuration = TimeInterval(duration) / 1000.0
            }
            
            if let curve = args["curve"] as? String {
                animatedLabel.animationCurve = getCurve(from: curve)
            }
            
            if let toScale = args["toScale"] as? CGFloat {
                animatedLabel.targetScale = toScale
            }
            
            if let toOpacity = args["toOpacity"] as? CGFloat {
                animatedLabel.targetOpacity = toOpacity
            }
            
            if let toTranslateX = args["toTranslateX"] as? CGFloat {
                animatedLabel.targetTranslationX = toTranslateX
            }
            
            if let toTranslateY = args["toTranslateY"] as? CGFloat {
                animatedLabel.targetTranslationY = toTranslateY
            }
            
            // Start animation
            animatedLabel.animate()
            return true
            
        default:
            return false
        }
        
        return false
    }
    
    // MARK: - View Registration
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        if let animatedLabel = view as? AnimatedLabel {
            // Trigger onViewId event
            propagateEvent(on: animatedLabel, eventName: "onViewId", data: ["id": nodeId])
        }
    }
    
    // MARK: - Event Handling
    // Note: AnimatedText uses global propagateEvent() system
    // No custom event methods needed - all handled by DCFComponentProtocol
}

/// Custom animated label class
class AnimatedLabel: UILabel {
    // Animation properties
    var animationDuration: TimeInterval = 0.3
    var animationDelay: TimeInterval = 0.0
    var animationCurve: UIView.AnimationOptions = .curveEaseInOut
    var animationRepeat: Bool = false
    
    // Target values
    var targetScale: CGFloat?
    var targetOpacity: CGFloat?
    var targetTranslationX: CGFloat?
    var targetTranslationY: CGFloat?
    
    // Initial values
    private var initialTransform = CGAffineTransform.identity
    private var initialAlpha: CGFloat = 1.0
    
    // Flag for animation on layout
    var needsAnimation = false
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLabel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLabel()
    }
    
    private func setupLabel() {
        // Ensure proper text wrapping
        numberOfLines = 0
        lineBreakMode = .byWordWrapping
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Trigger animation after layout if needed
        if needsAnimation {
            needsAnimation = false
            // Small delay to ensure layout is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.animate()
            }
        }
    }
    
    // Animate text change
    func setText(_ newText: String, duration: TimeInterval, curve: UIView.AnimationOptions? = nil) {
        // Store initial state
        let currentText = text
        
        // Trigger animation start event through associated object
        if let viewId = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "viewId".hashValue)!) as? String,
           let callback = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!) as? (String, String, [String: Any]) -> Void {
            callback(viewId, "onAnimationStart", [:])
        }
        
        // Fade out with current text
        UIView.animate(withDuration: duration / 2, delay: 0, options: curve ?? animationCurve, animations: { [weak self] in
            self?.alpha = 0
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            
            // Update text while invisible
            self.text = newText
            
            // Fade back in with new text
            UIView.animate(withDuration: duration / 2, delay: 0, options: curve ?? self.animationCurve, animations: {
                self.alpha = 1
            }, completion: { [weak self] finished in
                guard let self = self, finished else { return }
                
                // Trigger animation end event through associated object
                if let viewId = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "viewId".hashValue)!) as? String,
                   let callback = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!) as? (String, String, [String: Any]) -> Void {
                    callback(viewId, "onAnimationEnd", [:])
                }
            })
        })
    }
    
    // Animate the label with current properties
    func animate() {
        // Store initial state
        initialTransform = transform
        initialAlpha = alpha
        
        // Trigger animation start event through associated object
        if let viewId = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "viewId".hashValue)!) as? String,
           let callback = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!) as? (String, String, [String: Any]) -> Void {
            callback(viewId, "onAnimationStart", [:])
        }
        
        // Start animation
        UIView.animate(withDuration: animationDuration, delay: animationDelay, options: animationCurve, animations: { [weak self] in
            guard let self = self else { return }
            
            // Apply scale transform
            if let scale = self.targetScale {
                let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
                self.transform = self.transform.concatenating(scaleTransform)
            }
            
            // Apply translation transform
            if let translateX = self.targetTranslationX, let translateY = self.targetTranslationY {
                let translationTransform = CGAffineTransform(translationX: translateX, y: translateY)
                self.transform = self.transform.concatenating(translationTransform)
            } else if let translateX = self.targetTranslationX {
                let translationTransform = CGAffineTransform(translationX: translateX, y: 0)
                self.transform = self.transform.concatenating(translationTransform)
            } else if let translateY = self.targetTranslationY {
                let translationTransform = CGAffineTransform(translationX: 0, y: translateY)
                self.transform = self.transform.concatenating(translationTransform)
            }
            
            // Apply opacity
            if let opacity = self.targetOpacity {
                self.alpha = opacity
            }
            
        }, completion: { [weak self] finished in
            guard let self = self, finished else { return }
            
            // Trigger animation end event through associated object
            if let viewId = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "viewId".hashValue)!) as? String,
               let callback = objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: "eventCallback".hashValue)!) as? (String, String, [String: Any]) -> Void {
                callback(viewId, "onAnimationEnd", [:])
            }
            
            // Handle repeat if needed
            if self.animationRepeat {
                self.reset()
                self.animate()
            }
        })
    }
    
    // Reset the label to its initial state
    func reset() {
        layer.removeAllAnimations()
        transform = initialTransform
        alpha = initialAlpha
    }
}
