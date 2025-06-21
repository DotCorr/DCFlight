/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

/// Component that handles gesture recognition
class DCFGestureDetectorComponent: NSObject, DCFComponent, ComponentMethodHandler {
    // Keep singleton instance to prevent deallocation when gesture targets are registered
    private static let sharedInstance = DCFGestureDetectorComponent()
    
    // Gesture recognizers by view - only keeping what's needed for cleanup
    private static var gestureRecognizers = [UIView: [UIGestureRecognizer]]()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Create a view to capture gestures
        let gestureView = GestureView()
        
        // Force user interaction to be enabled
        gestureView.isUserInteractionEnabled = true
        
        // Apply adaptive default styling - let OS handle light/dark mode
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            // GestureDetector typically has transparent background unless specified
            gestureView.backgroundColor = UIColor.clear
        } else {
            gestureView.backgroundColor = UIColor.clear
        }
        
        // Apply props
        updateView(gestureView, withProps: props)
        
        // Apply StyleSheet properties
        gestureView.applyStyles(props: props)
        
        // Enable debug mode in development
        
        return gestureView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // Apply visibility
        if let enabled = props["enabled"] as? Bool {
            view.isUserInteractionEnabled = enabled
        }
        
        // Configure gestures based on events registered
        configureGestures(view)
        
        // Apply StyleSheet properties
        view.applyStyles(props: props)
        
        return true
    }
    
    // Configure gesture recognizers
    private func configureGestures(_ view: UIView) {
        // Clean up previous gesture recognizers
        if let recognizers = DCFGestureDetectorComponent.gestureRecognizers[view] {
            for recognizer in recognizers {
                view.removeGestureRecognizer(recognizer)
            }
        }
        
        // Create new gesture recognizers array for this view
        var recognizers = [UIGestureRecognizer]()
        
        // Add tap gesture recognizer
        let tapRecognizer = UITapGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapRecognizer)
        recognizers.append(tapRecognizer)
        
        // Add long press gesture recognizer
        let longPressRecognizer = UILongPressGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handleLongPress(_:)))
        view.addGestureRecognizer(longPressRecognizer)
        recognizers.append(longPressRecognizer)
        
        // Add swipe gesture recognizers (left, right, up, down)
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
        
        // Add pan gesture recognizer
        let panRecognizer = UIPanGestureRecognizer(target: DCFGestureDetectorComponent.sharedInstance, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panRecognizer)
        recognizers.append(panRecognizer)
        
        // Store gesture recognizers for cleanup
        DCFGestureDetectorComponent.gestureRecognizers[view] = recognizers
    }
    
    // MARK: - Gesture Handlers
    
    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        if let view = recognizer.view {
            propagateEvent(on: view, eventName: "onTap", data: [:])
        }
    }
    
    @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began, let view = recognizer.view {
            propagateEvent(on: view, eventName: "onLongPress", data: [:])
        }
    }
    
    @objc func handleSwipeLeft(_ recognizer: UISwipeGestureRecognizer) {
        if let view = recognizer.view {
            propagateEvent(on: view, eventName: "onSwipeLeft", data: [:])
        }
    }
    
    @objc func handleSwipeRight(_ recognizer: UISwipeGestureRecognizer) {
        if let view = recognizer.view {
            propagateEvent(on: view, eventName: "onSwipeRight", data: [:])
        }
    }
    
    @objc func handleSwipeUp(_ recognizer: UISwipeGestureRecognizer) {
        if let view = recognizer.view {
            propagateEvent(on: view, eventName: "onSwipeUp", data: [:])
        }
    }
    
    @objc func handleSwipeDown(_ recognizer: UISwipeGestureRecognizer) {
        if let view = recognizer.view {
            propagateEvent(on: view, eventName: "onSwipeDown", data: [:])
        }
    }
    
    @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        
        let translation = recognizer.translation(in: view)
        let velocity = recognizer.velocity(in: view)
        
        var eventType = "onPan"
        var eventData: [String: Any] = [
            "translationX": translation.x,
            "translationY": translation.y,
            "velocityX": velocity.x,
            "velocityY": velocity.y,
            "timestamp": Date().timeIntervalSince1970
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
    
    // MARK: - Event Handling
    // Note: GestureDetector uses global propagateEvent() system
    // No custom event methods needed - all handled by DCFComponentProtocol
    
    // MARK: - Method Handling
    
    func handleMethod(methodName: String, args: [String: Any], view: UIView) -> Bool {
        // Handle custom methods
        switch methodName {
        case "enableGestures":
            view.isUserInteractionEnabled = true
            return true
        case "disableGestures":
            view.isUserInteractionEnabled = false
            return true
        default:
            return false
        }
    }
}

/// Custom view class for gesture detection with debug capabilities
class GestureView: UIView {
    // Debug mode
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
        // Force user interaction to be enabled
        self.isUserInteractionEnabled = true
    }
}
