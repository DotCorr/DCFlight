/*
 * DCF Reanimated Swift Implementation
 * Copyright (c) Dotcorr Studio. and affiliates.
 * Licensed under the MIT license
 */

import UIKit
import dcflight

class DCFAnimatedViewComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let animatedView = AnimatedView()
        
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
        
        updateView(animatedView, withProps: props)
        animatedView.applyStyles(props: props)
        
        return animatedView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let animatedView = view as? AnimatedView else { return false }
        
        if let nativeAnimationId = props["nativeAnimationId"] as? String {
            print("🎯 Registering animation controller: \(nativeAnimationId)")
            DCFAnimationEngine.shared.registerAnimationController(nativeAnimationId, view: animatedView)
            
            if let groupId = props["groupId"] as? String {
                DCFAnimationEngine.shared.addControllerToGroup(groupId, controllerId: nativeAnimationId)
            }
        }
        
        view.applyStyles(props: props)
        return true
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        print("🚇 DCFAnimatedViewComponent.handleTunnelMethod called with method: \(method)")
        print("🚇 Params: \(params)")
        
        switch method {
        case "registerController":
            return handleRegisterController(params)
        case "executeIndividualCommand":
            return handleExecuteIndividualCommand(params)
        case "startAnimation":
            return handleStartAnimation(params)
        default:
            print("🚇 Unknown method: \(method)")
            return nil
        }
    }
    
    private static func handleRegisterController(_ params: [String: Any]) -> Any? {
        guard let controllerId = params["controllerId"] as? String else {
            print("❌ registerController: Missing controllerId")
            return false
        }
        
        print("🎯 handleRegisterController: \(controllerId)")
        
        let groupId = params["groupId"] as? String
        
        if let groupId = groupId {
            DCFAnimationEngine.shared.addControllerToGroup(groupId, controllerId: controllerId)
            print("🎯 Added controller \(controllerId) to group \(groupId)")
        }
        
        return true
    }
    
    private static func handleExecuteIndividualCommand(_ params: [String: Any]) -> Any? {
        guard let controllerId = params["controllerId"] as? String,
              let command = params["command"] as? [String: Any] else {
            print("❌ executeIndividualCommand: Missing controllerId or command")
            return false
        }
        
        print("🎯 handleExecuteIndividualCommand: \(controllerId) with command: \(command)")
        
        // Check if controller exists
        if !DCFAnimationEngine.shared.hasController(controllerId) {
            print("❌ Controller \(controllerId) not found in engine")
            return false
        }
        
        DCFAnimationEngine.shared.executeCommand(controllerId, command: command)
        return true
    }
    
    private static func handleStartAnimation(_ params: [String: Any]) -> Any? {
        guard let controllerId = params["controllerId"] as? String,
              let config = params["config"] as? [String: Any] else {
            print("❌ startAnimation: Missing controllerId or config")
            return false
        }
        
        print("🎯 handleStartAnimation: \(controllerId)")
        print("🎯 Animation config: \(config)")
        
        // ✅ CRITICAL FIX: Check if controller exists before trying to animate
        if !DCFAnimationEngine.shared.hasController(controllerId) {
            print("❌ Controller \(controllerId) not registered yet - cannot start animation")
            return false
        }
        
        // ✅ CRITICAL FIX: Ensure the config has the correct structure
        var animationCommand = config
        
        // The config should already have 'type': 'animate' from Dart, but let's make sure
        if animationCommand["type"] == nil {
            animationCommand["type"] = "animate"
        }
        
        print("🎯 Executing animation command: \(animationCommand)")
        DCFAnimationEngine.shared.executeCommand(controllerId, command: animationCommand)
        return true
    }
    
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
