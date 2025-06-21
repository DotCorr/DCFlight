/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

/// Component that handles touchable opacity functionality
class DCFTouchableOpacityComponent: NSObject, DCFComponent {
    // Keep singleton instance to prevent deallocation when touch targets are registered
    private static let sharedInstance = DCFTouchableOpacityComponent()
    
    // Static storage for touch event handlers
    private static var touchEventHandlers = [UIView: (String, (String, String, [String: Any]) -> Void)]()
    
    // Store strong reference to self when views are registered
    private static var registeredViews = [UIView: DCFTouchableOpacityComponent]()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Create view to handle touches
        let touchableView = TouchableView()
        touchableView.component = self
        
        // Force user interaction to be enabled
        touchableView.isUserInteractionEnabled = true
        
        // Apply adaptive default styling - let OS handle light/dark mode
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            // TouchableOpacity typically has transparent background unless specified
            touchableView.backgroundColor = UIColor.clear
        } else {
            touchableView.backgroundColor = UIColor.clear
        }
        
        // Apply props
        updateView(touchableView, withProps: props)
        
        // Apply StyleSheet properties
        touchableView.applyStyles(props: props)
        
        // Enable debug mode in development
        
        return touchableView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let touchableView = view as? TouchableView else { return false }
        
        // Set active opacity
        if let activeOpacity = props["activeOpacity"] as? CGFloat {
            touchableView.activeOpacity = activeOpacity
            
            // Store as associated object for direct access in handlers
            objc_setAssociatedObject(
                view,
                UnsafeRawPointer(bitPattern: "activeOpacity".hashValue)!,
                activeOpacity,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        } else {
            touchableView.activeOpacity = 0.2 // Default
        }
        
        // Set disabled state
        if let disabled = props["disabled"] as? Bool {
            touchableView.isUserInteractionEnabled = !disabled
            // Apply disabled visual state if needed
            touchableView.alpha = disabled ? 0.5 : 1.0
        }
        
        // Set long press delay
        if let longPressDelay = props["longPressDelay"] as? Int {
            touchableView.longPressDelay = TimeInterval(longPressDelay) / 1000.0
        }
        
        // Handle command prop - new declarative-imperative pattern
        if let commandData = props["command"] as? [String: Any] {
            handleCommand(commandData, on: touchableView)
        }
        
        // Apply StyleSheet properties
        touchableView.applyStyles(props: props)
        
        return true
    }
    
    // MARK: - Event Handling
    
    func handleTouchDown(_ view: TouchableView) {
        // Animate to pressed state
        UIView.animate(withDuration: 0.1) {
            view.alpha = view.activeOpacity
        }
        
        // Trigger onPressIn event using global system
        propagateEvent(on: view, eventName: "onPressIn", data: [
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Set up long press timer
        view.startLongPressTimer()
    }
    
    func handleTouchUp(_ view: TouchableView, inside: Bool) {
        // Cancel long press timer
        view.cancelLongPressTimer()
        
        // Animate back to normal state
        UIView.animate(withDuration: 0.1) {
            view.alpha = 1.0
        }
        
        // Trigger onPressOut event
        propagateEvent(on: view, eventName: "onPressOut", data: [
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Trigger onPress event if touch ended inside the view
        if inside {
            propagateEvent(on: view, eventName: "onPress", data: [
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }
    
    func handleLongPress(_ view: TouchableView) {
        // Trigger long press event
        propagateEvent(on: view, eventName: "onLongPress", data: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Command Handling (New Declarative-Imperative Pattern)
    
    private func handleCommand(_ commandData: [String: Any], on touchableView: TouchableView) {
        guard let commandType = commandData["type"] as? String else { return }
        
        switch commandType {
        case "setOpacity":
            if let opacity = commandData["opacity"] as? Double {
                let opacityValue = CGFloat(opacity)
                if let duration = commandData["duration"] as? Double {
                    UIView.animate(withDuration: duration) {
                        touchableView.alpha = opacityValue
                    }
                } else {
                    touchableView.alpha = opacityValue
                }
            }
            
        case "setHighlighted":
            if let highlighted = commandData["highlighted"] as? Bool {
                if highlighted {
                    touchableView.alpha = touchableView.activeOpacity
                } else {
                    touchableView.alpha = 1.0
                }
            }
            
        case "performPress":
            // Simulate a press event
            self.handleTouchDown(touchableView)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.handleTouchUp(touchableView, inside: true)
            }
            
        case "animateToState":
            if let opacity = commandData["opacity"] as? Double {
                let duration = commandData["duration"] as? Double ?? 0.2
                let curve = commandData["curve"] as? String ?? "easeInOut"
                
                let animationCurve = getCurve(from: curve)
                UIView.animate(withDuration: duration, delay: 0, options: animationCurve, animations: {
                    touchableView.alpha = CGFloat(opacity)
                })
            }
            
        default:
            break
        }
    }
    
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
    
    // MARK: - Event Handling
    // Note: TouchableOpacity uses global propagateEvent() system
    // No custom event methods needed - all handled by DCFComponentProtocol
}

/// Custom view class for touchable opacity
class TouchableView: UIView {
    // Reference to component
    weak var component: DCFTouchableOpacityComponent?
    
    // Active opacity when pressed
    var activeOpacity: CGFloat = 0.2
    
    // Long press properties
    var longPressDelay: TimeInterval = 0.5
    var longPressTimer: Timer?
    
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
    
    // Start long press timer
    func startLongPressTimer() {
        cancelLongPressTimer()
        
        longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.component?.handleLongPress(self)
        }
    }
    
    // Cancel long press timer
    func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        component?.handleTouchDown(self)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        // Check if touch is inside view
        if let touch = touches.first {
            let point = touch.location(in: self)
            let inside = bounds.contains(point)
            component?.handleTouchUp(self, inside: inside)
        } else {
            component?.handleTouchUp(self, inside: false)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        component?.handleTouchUp(self, inside: false)
    }
}
