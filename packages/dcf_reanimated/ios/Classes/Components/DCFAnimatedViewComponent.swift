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
            DCFAnimationEngine.shared.registerAnimationController(nativeAnimationId, view: animatedView)
            
            if let groupId = props["groupId"] as? String {
                DCFAnimationEngine.shared.addControllerToGroup(groupId, controllerId: nativeAnimationId)
                print("📝 DCFAnimatedViewComponent: Added \(nativeAnimationId) to group \(groupId)")
            }
            
            if let commandData = props["command"] as? [String: Any] {
                DCFAnimationEngine.shared.executeCommand(nativeAnimationId, command: commandData)
            }
        }
        
        view.applyStyles(props: props)
        
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
