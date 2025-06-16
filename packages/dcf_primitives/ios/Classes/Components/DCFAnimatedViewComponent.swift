/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

/// Component that implements animated view
class DCFAnimatedViewComponent: NSObject, DCFComponent, ComponentMethodHandler {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Create animated view
        let animatedView = AnimatedView()
        
        // Set up adaptive background color
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                animatedView.backgroundColor = UIColor.systemBackground
            } else {
                animatedView.backgroundColor = UIColor.white
            }
        } else {
            animatedView.backgroundColor = UIColor.clear
        }
        
        // Apply props
        updateView(animatedView, withProps: props)
        
        // Apply StyleSheet properties
        animatedView.applyStyles(props: props)
        
        return animatedView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let animatedView = view as? AnimatedView else { return false }
        
        // Apply animation properties
        if let duration = props["animationDuration"] as? Int {
            animatedView.animationDuration = TimeInterval(duration) / 1000.0
        }
        
        if let curve = props["animationCurve"] as? String {
            animatedView.animationCurve = getCurve(from: curve)
        }
        
        if let delay = props["animationDelay"] as? Int {
            animatedView.animationDelay = TimeInterval(delay) / 1000.0
        }
        
        if let animRepeat = props["animationRepeat"] as? Bool {
            animatedView.animationRepeat = animRepeat
        }
        
        // Store target values for animation
        if let toScale = props["toScale"] as? CGFloat {
            animatedView.targetScale = toScale
        }
        
        if let toOpacity = props["toOpacity"] as? CGFloat {
            animatedView.targetOpacity = toOpacity
        }
        
        if let toTranslateX = props["toTranslateX"] as? CGFloat {
            animatedView.targetTranslationX = toTranslateX
        }
        
        if let toTranslateY = props["toTranslateY"] as? CGFloat {
            animatedView.targetTranslationY = toTranslateY
        }
        
        if let toRotate = props["toRotate"] as? CGFloat {
            animatedView.targetRotation = toRotate
        }
        
        // Handle background color property - key fix for incremental updates
        if props.keys.contains("backgroundColor") {
            if let backgroundColor = props["backgroundColor"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: backgroundColor)
                view.backgroundColor = uiColor
                print("🎨 DCFAnimatedViewComponent: Set background color to: \(backgroundColor) -> \(uiColor)")
            } else {
                print("⚠️ DCFAnimatedViewComponent: backgroundColor prop present but invalid value: \(props["backgroundColor"] ?? "nil")")
            }
        }
        
        // Handle adaptive color only if explicitly provided and no backgroundColor is set
        if props.keys.contains("adaptive") && !props.keys.contains("backgroundColor") {
            let isAdaptive = props["adaptive"] as? Bool ?? true
            if isAdaptive {
                if #available(iOS 13.0, *) {
                    view.backgroundColor = UIColor.systemBackground
                } else {
                    view.backgroundColor = UIColor.white
                }
                print("🎨 DCFAnimatedViewComponent: Applied adaptive background color")
            }
        }
        
        // Apply StyleSheet properties (handles borderRadius and other properties)
        view.applyStyles(props: props)
        
        // Automatically start animation after layout
        animatedView.needsAnimation = true
        
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
        guard let animatedView = view as? AnimatedView else { return false }
        
        switch methodName {
        case "animate":
            // Set animation properties from method args
            if let duration = args["duration"] as? Int {
                animatedView.animationDuration = TimeInterval(duration) / 1000.0
            }
            
            if let curve = args["curve"] as? String {
                animatedView.animationCurve = getCurve(from: curve)
            }
            
            if let toScale = args["toScale"] as? CGFloat {
                animatedView.targetScale = toScale
            }
            
            if let toOpacity = args["toOpacity"] as? CGFloat {
                animatedView.targetOpacity = toOpacity
            }
            
            if let toTranslateX = args["toTranslateX"] as? CGFloat {
                animatedView.targetTranslationX = toTranslateX
            }
            
            if let toTranslateY = args["toTranslateY"] as? CGFloat {
                animatedView.targetTranslationY = toTranslateY
            }
            
            if let toRotate = args["toRotate"] as? CGFloat {
                animatedView.targetRotation = toRotate
            }
            
            // Start animation
            animatedView.animate()
            return true
            
        case "reset":
            animatedView.reset()
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - View Registration
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        if let animatedView = view as? AnimatedView {
            // Trigger onViewId event
            propagateEvent(on: animatedView, eventName: "onViewId", data: ["id": nodeId])
        }
    }
    
    // MARK: - Event Handling
    // Note: AnimatedView uses global propagateEvent() system
    // No custom event methods needed - all handled by DCFComponentProtocol
}


/// Custom animated view class
class AnimatedView: UIView {
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
    var targetRotation: CGFloat?
    
    // Initial values
    private var initialTransform = CGAffineTransform.identity
    private var initialAlpha: CGFloat = 1.0
    
    // Flag for animation on layout
    var needsAnimation = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        clipsToBounds = true
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
    
    // Animate the view with current properties
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
            
            // Apply rotation transform
            if let rotation = self.targetRotation {
                let rotationInRadians = rotation * .pi / 180
                let rotationTransform = CGAffineTransform(rotationAngle: rotationInRadians)
                self.transform = self.transform.concatenating(rotationTransform)
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
    
    // Reset the view to its initial state
    func reset() {
        layer.removeAllAnimations()
        transform = initialTransform
        alpha = initialAlpha
    }
}
