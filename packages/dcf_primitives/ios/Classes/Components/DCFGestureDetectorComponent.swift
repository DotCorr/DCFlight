/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

/// Component that handles gesture recognition
class DCFGestureDetectorComponent: NSObject, DCFComponent, UIGestureRecognizerDelegate {
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
        
        // Double tap gesture
        let doubleTapRecognizer = UITapGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handleDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapRecognizer)
        recognizers.append(doubleTapRecognizer)
        
        // Make single tap require double tap to fail (prevents conflicts)
        tapRecognizer.require(toFail: doubleTapRecognizer)
        
        // Pinch/scale gesture
        let pinchRecognizer = UIPinchGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchRecognizer)
        recognizers.append(pinchRecognizer)
        
        // Rotation gesture
        let rotationRecognizer = UIRotationGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handleRotation(_:)))
        view.addGestureRecognizer(rotationRecognizer)
        recognizers.append(rotationRecognizer)
        
        // Allow simultaneous gestures
        pinchRecognizer.delegate = DCFGestureDetectorComponent.sharedInstance
        rotationRecognizer.delegate = DCFGestureDetectorComponent.sharedInstance
        panRecognizer.delegate = DCFGestureDetectorComponent.sharedInstance
        
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
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
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
    
    @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if let view = recognizer.view {
            let location = recognizer.location(in: view)
            propagateEvent(on: view, eventName: "onDoubleTap", data: [
                "x": location.x,
                "y": location.y,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                "fromUser": true
            ])
        }
    }
    
    @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let view = recognizer.view else { return }
        
        let location = recognizer.location(in: view)
        let scale = recognizer.scale
        let velocity = recognizer.velocity
        
        var eventType = "onPinch"
        var eventData: [String: Any] = [
            "x": location.x,
            "y": location.y,
            "scale": scale,
            "velocity": velocity,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "fromUser": true
        ]
        
        switch recognizer.state {
        case .began:
            eventType = "onPinchStart"
        case .changed:
            eventType = "onPinchUpdate"
        case .ended, .cancelled:
            eventType = "onPinchEnd"
        default:
            return
        }
        
        propagateEvent(on: view, eventName: eventType, data: eventData)
    }
    
    @objc func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        guard let view = recognizer.view else { return }
        
        let location = recognizer.location(in: view)
        let rotation = recognizer.rotation // in radians
        let velocity = recognizer.velocity // radians per second
        
        var eventType = "onRotation"
        var eventData: [String: Any] = [
            "x": location.x,
            "y": location.y,
            "rotation": rotation,
            "velocity": velocity,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "fromUser": true
        ]
        
        switch recognizer.state {
        case .began:
            eventType = "onRotationStart"
        case .changed:
            eventType = "onRotationUpdate"
        case .ended, .cancelled:
            eventType = "onRotationEnd"
        default:
            return
        }
        
        propagateEvent(on: view, eventName: eventType, data: eventData)
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
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
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pinch and rotation to work simultaneously
        if (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer) ||
           (gestureRecognizer is UIRotationGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer) {
            return true
        }
        return false
    }
}

class GestureView: UIView {
    
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
