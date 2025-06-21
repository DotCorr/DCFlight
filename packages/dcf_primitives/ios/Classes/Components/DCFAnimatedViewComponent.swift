/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

/// Component that implements animated view
class DCFAnimatedViewComponent: NSObject, DCFComponent {
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
        
        // Handle command prop - new declarative-imperative pattern
        if let commandData = props["command"] as? [String: Any] {
            handleCommand(commandData, on: animatedView)
        }
        
        // Handle background color property - key fix for incremental updates
        if props.keys.contains("backgroundColor") {
            if let backgroundColor = props["backgroundColor"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: backgroundColor)
                view.backgroundColor = uiColor
            } else {
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
    
    // MARK: - Command Handling (New Declarative-Imperative Pattern)
    
    private func handleCommand(_ commandData: [String: Any], on animatedView: AnimatedView) {
        guard let commandType = commandData["type"] as? String else { return }
        
        switch commandType {
        case "animate":
            // ✅ FIX: Clear previous targets to avoid accumulation
            animatedView.targetScale = nil
            animatedView.targetOpacity = nil
            animatedView.targetTranslationX = nil
            animatedView.targetTranslationY = nil
            animatedView.targetRotation = nil
            
            // ✅ FIX: Handle duration properly - Dart sends as Int (milliseconds) 
            if let duration = commandData["duration"] as? Int {
                animatedView.animationDuration = TimeInterval(duration) / 1000.0 // Convert ms to seconds
            } else if let duration = commandData["duration"] as? Double {
                animatedView.animationDuration = duration / 1000.0 // Convert ms to seconds
            }
            
            if let curve = commandData["curve"] as? String {
                animatedView.animationCurve = getCurve(from: curve)
            }
            
            // ✅ FIX: Handle delay properly - Dart sends as Int (milliseconds)
            if let delay = commandData["delay"] as? Int {
                animatedView.animationDelay = TimeInterval(delay) / 1000.0 // Convert ms to seconds
            } else if let delay = commandData["delay"] as? Double {
                animatedView.animationDelay = delay / 1000.0 // Convert ms to seconds
            }
            
            if let repeatAnimation = commandData["repeat"] as? Bool {
                animatedView.animationRepeat = repeatAnimation
            }
            
            if let toScale = commandData["toScale"] as? Double {
                animatedView.targetScale = CGFloat(toScale)
            } else if let toScale = commandData["toScale"] as? NSNumber {
                animatedView.targetScale = CGFloat(toScale.doubleValue)
            }
            
            if let toOpacity = commandData["toOpacity"] as? Double {
                animatedView.targetOpacity = CGFloat(toOpacity)
            } else if let toOpacity = commandData["toOpacity"] as? NSNumber {
                animatedView.targetOpacity = CGFloat(toOpacity.doubleValue)
            }
            
            if let toTranslateX = commandData["toTranslateX"] as? Double {
                animatedView.targetTranslationX = CGFloat(toTranslateX)
            } else if let toTranslateX = commandData["toTranslateX"] as? NSNumber {
                animatedView.targetTranslationX = CGFloat(toTranslateX.doubleValue)
            }
            
            if let toTranslateY = commandData["toTranslateY"] as? Double {
                animatedView.targetTranslationY = CGFloat(toTranslateY)
            } else if let toTranslateY = commandData["toTranslateY"] as? NSNumber {
                animatedView.targetTranslationY = CGFloat(toTranslateY.doubleValue)
            }
            
            // ✅ FIX: Rotation is already in radians from Dart, don't convert again
            if let toRotation = commandData["toRotation"] as? Double {
                animatedView.targetRotation = CGFloat(toRotation) // Keep as radians
            } else if let toRotation = commandData["toRotation"] as? NSNumber {
                animatedView.targetRotation = CGFloat(toRotation.doubleValue) // Keep as radians
            }
            
            // Start animation immediately
            animatedView.animate()
            
        case "reset":
            animatedView.reset()
            
        case "pause":
            animatedView.layer.removeAllAnimations()
            
        case "resume":
            // Re-trigger animation with current properties
            animatedView.animate()
            
        default:
            break
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
            
            // ✅ FIX: Reset to identity and build fresh transform (no accumulation)
            var combinedTransform = CGAffineTransform.identity
            
            // Apply scale transform
            if let scale = self.targetScale {
                combinedTransform = combinedTransform.scaledBy(x: scale, y: scale)
            }
            
            // Apply translation transform
            if let translateX = self.targetTranslationX, let translateY = self.targetTranslationY {
                combinedTransform = combinedTransform.translatedBy(x: translateX, y: translateY)
            } else if let translateX = self.targetTranslationX {
                combinedTransform = combinedTransform.translatedBy(x: translateX, y: 0)
            } else if let translateY = self.targetTranslationY {
                combinedTransform = combinedTransform.translatedBy(x: 0, y: translateY)
            }
            
            // ✅ FIX: Apply rotation properly - value is already in radians
            if let rotation = self.targetRotation {
                combinedTransform = combinedTransform.rotated(by: rotation)
            }
            
            // Apply the combined transform
            self.transform = combinedTransform
            
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
        
        // ✅ FIX: Clear target values to prevent accumulation
        targetScale = nil
        targetOpacity = nil
        targetTranslationX = nil
        targetTranslationY = nil
        targetRotation = nil
    }
}
