/*
 * DCF Reanimated Swift Implementation
 * Copyright (c) Dotcorr Studio. and affiliates.
 * Licensed under the MIT license
 */

import UIKit
import dcflight

class DCFAnimationManagerComponent: NSObject, DCFComponent {
    private var registeredGroups: Set<String> = []
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.clear
        
        if let groupId = props["groupId"] as? String {
            let autoStart = props["autoStart"] as? Bool ?? true
            let debugName = props["debugName"] as? String
            
            DCFAnimationEngine.shared.registerAnimationGroup(groupId, autoStart: autoStart, debugName: debugName)
            registeredGroups.insert(groupId)
        }
        
        return containerView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        return true
    }
    
     static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        print("🚇 DCFAnimationManagerComponent.handleTunnelMethod called with method: \(method)")
        
        switch method {
        case "registerGroup":
            print("🚇 Calling handleRegisterGroup")
            return handleRegisterGroup(params)
        case "executeGroupCommand":
            print("🚇 Calling handleExecuteGroupCommand")
            return handleExecuteGroupCommand(params)
        default:
            print("🚇 Unknown method: \(method)")
            return nil
        }
    }
    
    private static func handleRegisterGroup(_ params: [String: Any]) -> Any? {
        guard let groupId = params["groupId"] as? String else { return false }
        
        let autoStart = params["autoStart"] as? Bool ?? true
        let debugName = params["debugName"] as? String
        
        DCFAnimationEngine.shared.registerAnimationGroup(groupId, autoStart: autoStart, debugName: debugName)
        return true
    }
    
    private static func handleExecuteGroupCommand(_ params: [String: Any]) -> Any? {
        guard let groupId = params["groupId"] as? String,
              let command = params["command"] as? [String: Any] else { return false }
        
        DCFAnimationEngine.shared.executeGroupCommand(groupId, command: command)
        return true
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
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
        return CGSize(width: 0, height: 0)
    }
    
    deinit {
        for groupId in registeredGroups {
            DCFAnimationEngine.shared.disposeAnimationGroup(groupId)
        }
    }
}
