/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

/// Component that handles gesture recognition
class DCFGestureDetectorComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFGestureDetectorComponent()
    
    private static var gestureRecognizers = [UIView: [UIGestureRecognizer]]()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let gestureView = GestureView()
        
        gestureView.isUserInteractionEnabled = true
        
        updateView(gestureView, withProps: props)
        
        gestureView.applyStyles(props: props)
        
        
        return gestureView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        if let enabled = props["enabled"] as? Bool {
            view.isUserInteractionEnabled = enabled
        }
        
        configureGestures(view)
        
        view.applyStyles(props: props)
        
        return true
    }
    
    private func configureGestures(_ view: UIView) {
        if let recognizers = DCFGestureDetectorComponent.gestureRecognizers[view] {
            for recognizer in recognizers {
                view.removeGestureRecognizer(recognizer)
            }
        }
        
        var recognizers = [UIGestureRecognizer]()
        
        let tapRecognizer = UITapGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapRecognizer)
        recognizers.append(tapRecognizer)
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handleLongPress(_:)))
        view.addGestureRecognizer(longPressRecognizer)
        recognizers.append(longPressRecognizer)
        
        let swipeLeftRecognizer = UISwipeGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handleSwipeLeft(_:)))
        swipeLeftRecognizer.direction = .left
        view.addGestureRecognizer(swipeLeftRecognizer)
        recognizers.append(swipeLeftRecognizer)
        
        let swipeRightRecognizer = UISwipeGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handleSwipeRight(_:)))
        swipeRightRecognizer.direction = .right
        view.addGestureRecognizer(swipeRightRecognizer)
        recognizers.append(swipeRightRecognizer)
        
        let swipeUpRecognizer = UISwipeGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handleSwipeUp(_:)))
        swipeUpRecognizer.direction = .up
        view.addGestureRecognizer(swipeUpRecognizer)
        recognizers.append(swipeUpRecognizer)
        
        let swipeDownRecognizer = UISwipeGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handleSwipeDown(_:)))
        swipeDownRecognizer.direction = .down
        view.addGestureRecognizer(swipeDownRecognizer)
        recognizers.append(swipeDownRecognizer)
        
        let panRecognizer = UIPanGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panRecognizer)
        recognizers.append(panRecognizer)
        
        DCFGestureDetectorComponent.gestureRecognizers[view] = recognizers
    }
    
    
    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        if let view = recognizer.view {
            let location = recognizer.location(in: view)
            propagateEvent(on: view, eventName: "onTap", data: [
                "x": location.x,
                "y": location.y,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                "fromUser": true
            ])
        }
    }
    
    @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began, let view = recognizer.view {
            let location = recognizer.location(in: view)
            propagateEvent(on: view, eventName: "onLongPress", data: [
                "x": location.x,
                "y": location.y,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                "fromUser": true
            ])
        }
    }
    
    @objc func handleSwipeLeft(_ recognizer: UISwipeGestureRecognizer) {
        if let view = recognizer.view {
            let location = recognizer.location(in: view)
            // UISwipeGestureRecognizer doesn't provide velocity, use a default value
            propagateEvent(on: view, eventName: "onSwipeLeft", data: [
                "direction": "left",
                "velocity": 0.0,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                "fromUser": true
            ])
        }
    }
    
    @objc func handleSwipeRight(_ recognizer: UISwipeGestureRecognizer) {
        if let view = recognizer.view {
            let location = recognizer.location(in: view)
            // UISwipeGestureRecognizer doesn't provide velocity, use a default value
            propagateEvent(on: view, eventName: "onSwipeRight", data: [
                "direction": "right",
                "velocity": 0.0,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                "fromUser": true
            ])
        }
    }
    
    @objc func handleSwipeUp(_ recognizer: UISwipeGestureRecognizer) {
        if let view = recognizer.view {
            let location = recognizer.location(in: view)
            // UISwipeGestureRecognizer doesn't provide velocity, use a default value
            propagateEvent(on: view, eventName: "onSwipeUp", data: [
                "direction": "up",
                "velocity": 0.0,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                "fromUser": true
            ])
        }
    }
    
    @objc func handleSwipeDown(_ recognizer: UISwipeGestureRecognizer) {
        if let view = recognizer.view {
            let location = recognizer.location(in: view)
            // UISwipeGestureRecognizer doesn't provide velocity, use a default value
            propagateEvent(on: view, eventName: "onSwipeDown", data: [
                "direction": "down",
                "velocity": 0.0,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                "fromUser": true
            ])
        }
    }
    
    @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        
        let translation = recognizer.translation(in: view)
        let velocity = recognizer.velocity(in: view)
        
        var eventType = "onPan"
        let location = recognizer.location(in: view)
        var eventData: [String: Any] = [
            "x": location.x,
            "y": location.y,
            "translationX": translation.x,
            "translationY": translation.y,
            "velocityX": velocity.x,
            "velocityY": velocity.y,
            "timestamp": Date().timeIntervalSince1970,
            "fromUser": true
        ]
        
        switch recognizer.state {
        case .began:
            eventType = "onPanStart"
        case .changed:
            eventType = "onPanUpdate"
        case .ended, .cancelled:
            eventType = "onPanEnd"
        default:
            return
        }
        
        propagateEvent(on: view, eventName: eventType, data: eventData)
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        // GestureDetector is a container, delegate to child if exists
        if let child = view.subviews.first {
            let size = child.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            return CGSize(width: max(1, size.width), height: max(1, size.height))
        }
        return CGSize.zero
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }

    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        objc_setAssociatedObject(view,
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!,
                               nodeId,
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

/// Custom view class for gesture detection with debug capabilities
class GestureView: UIView {
    var _debugMode = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        self.isUserInteractionEnabled = true
    }
}
