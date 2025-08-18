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
            print("🎬 DCFAnimationManagerComponent: Registered group \(groupId)")
        }
        
        return containerView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
    print("🔧 DCFAnimationManagerComponent.updateView called with props: \(props.keys)")
    
    if let groupId = props["groupId"] as? String,
       let commandData = props["command"] as? [String: Any] {
        
        let commandType = commandData["type"] as? String ?? ""
        print("🎮 Received command: \(commandType)")
        
        if commandType == "dispose" {
            // Handle disposal command
            DCFAnimationEngine.shared.disposeAnimationGroup(groupId)
            registeredGroups.remove(groupId)
            print("🗑️ DCFAnimationManagerComponent: Disposed group \(groupId) via command")
        } else {
            DCFAnimationEngine.shared.executeGroupCommand(groupId, command: commandData)
            print("🎮 DCFAnimationManagerComponent: Executed command \(commandType) on group \(groupId)")
        }
    }
    
    return true
}
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeIdre yo: String) {
        // Nothing needed here
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
            print("🗑️ DCFAnimationManagerComponent: Disposed group \(groupId) on deinit")
        }
    }
}

