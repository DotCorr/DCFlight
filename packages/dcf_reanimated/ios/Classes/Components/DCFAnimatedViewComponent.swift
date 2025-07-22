/*
 * DCFAnimatedViewComponent.swift - SINGLE UI Thread Animation System
 */

import UIKit
import dcflight

/// Component that ONLY uses UI Thread Animation Engine
class DCFAnimatedViewComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
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
        
        // 🚀 ONLY UI Thread Animation System
        if let nativeAnimationId = props["nativeAnimationId"] as? String {
            // Register with UI thread animation engine
            DCFAnimationEngine.shared.registerAnimationController(nativeAnimationId, view: animatedView)
            print("🔗 UI Thread Animation: Registered \(nativeAnimationId)")
            
            // Handle command via UI thread engine
            if let commandData = props["command"] as? [String: Any] {
                DCFAnimationEngine.shared.executeCommand(nativeAnimationId, command: commandData)
                print("⚡ UI Thread Animation: Command executed")
            }
        } else {
            print("⚠️ DCFAnimatedView: No nativeAnimationId - use useAnimationController() hook!")
        }
        
        // Handle styling
        if props.keys.contains("backgroundColor") {
            if let backgroundColor = props["backgroundColor"] as? String {
                view.backgroundColor = ColorUtilities.color(fromHexString: backgroundColor)
            }
        }
        
        // Apply StyleSheet properties
        view.applyStyles(props: props)
        
        return true
    }
    
    // Standard DCFComponent methods
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        if let animatedView = view as? AnimatedView {
            propagateEvent(on: animatedView, eventName: "onViewId", data: ["id": nodeId])
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
}

/// Simple AnimatedView class - NO animation logic (handled by DCFAnimationEngine)
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
    
    /// Reset method for DCFAnimationEngine
    func resetToInitialState() {
        print("🔄 AnimatedView: Resetting to initial state")
        layer.removeAllAnimations()
        transform = CGAffineTransform.identity
        alpha = 1.0
    }
}