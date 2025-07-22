/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

/// Component that implements animated view with UI thread animation engine
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
        
        print("🔄 DCFAnimatedViewComponent: Updating view with props: \(props.keys)")
        
        // REQUIRED: Check for native animation controller ID (UI thread animation)
        if let nativeAnimationId = props["nativeAnimationId"] as? String {
            // Register with UI thread animation engine
            DCFAnimationEngine.shared.registerAnimationController(nativeAnimationId, view: animatedView)
            print("🔗 DCFAnimatedViewComponent: Registered view with native animation ID: \(nativeAnimationId)")
            
            // Handle command - send directly to UI thread animation engine
            if let commandData = props["command"] as? [String: Any] {
                DCFAnimationEngine.shared.executeCommand(nativeAnimationId, command: commandData)
                print("⚡ DCFAnimatedViewComponent: Command sent to UI thread engine")
            }
        } else {
            print("⚠️ DCFAnimatedViewComponent: No nativeAnimationId provided - animation will not work")
            print("💡 DCFAnimatedViewComponent: Use useAnimationController() hook to provide nativeAnimationId")
        }
        
        // Handle background color property
        if props.keys.contains("backgroundColor") {
            if let backgroundColor = props["backgroundColor"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: backgroundColor)
                view.backgroundColor = uiColor
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
    

    
    // MARK: - View Registration
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        if let animatedView = view as? AnimatedView {
            // Trigger onViewId event
            propagateEvent(on: animatedView, eventName: "onViewId", data: ["id": nodeId])
        }
    }
    
    // MARK: - DCFComponent Protocol
    
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
}

/// Custom animated view class for UI thread animation only
class AnimatedView: UIView {
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
    
    /// Reset the view to its initial state (used by UI thread animation engine)
    func resetToInitialState() {
        print("🔄 AnimatedView: Resetting to initial state")
        
        // Remove any active animations
        layer.removeAllAnimations()
        
        // Reset transform and opacity
        transform = CGAffineTransform.identity
        alpha = 1.0
    }
}
