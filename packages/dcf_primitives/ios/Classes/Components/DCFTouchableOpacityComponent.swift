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
    private static let sharedInstance = DCFTouchableOpacityComponent()
    
    private static var touchEventHandlers = [UIView: (String, (String, String, [String: Any]) -> Void)]()
    
    private static var registeredViews = [UIView: DCFTouchableOpacityComponent]()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let touchableView = TouchableView()
        touchableView.component = self
        
        touchableView.isUserInteractionEnabled = true
        
        updateView(touchableView, withProps: props)
        
        touchableView.applyStyles(props: props)
        
        
        return touchableView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let touchableView = view as? TouchableView else { return false }
        
        if let activeOpacity = props["activeOpacity"] as? CGFloat {
            touchableView.activeOpacity = activeOpacity
            
            objc_setAssociatedObject(
                view,
                UnsafeRawPointer(bitPattern: "activeOpacity".hashValue)!,
                activeOpacity,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        } else {
            touchableView.activeOpacity = 0.2 // Default
        }
        
        if let disabled = props["disabled"] as? Bool {
            touchableView.isUserInteractionEnabled = !disabled
            touchableView.alpha = disabled ? 0.5 : 1.0
        }
        
        if let longPressDelay = props["longPressDelay"] as? Int {
            touchableView.longPressDelay = TimeInterval(longPressDelay) / 1000.0
        }
        
        touchableView.applyStyles(props: props)
        
        return true
    }
    
    
    func handleTouchDown(_ view: TouchableView) {
        UIView.animate(withDuration: 0.1) {
            view.alpha = view.activeOpacity
        }
        
        propagateEvent(on: view, eventName: "onPressIn", data: [
            "timestamp": Date().timeIntervalSince1970
        ])
        
        view.startLongPressTimer()
    }
    
    func handleTouchUp(_ view: TouchableView, inside: Bool) {
        view.cancelLongPressTimer()
        
        UIView.animate(withDuration: 0.1) {
            view.alpha = 1.0
        }
        
        propagateEvent(on: view, eventName: "onPressOut", data: [
            "timestamp": Date().timeIntervalSince1970
        ])
        
        if inside {
            propagateEvent(on: view, eventName: "onPress", data: [
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }
    
    func handleLongPress(_ view: TouchableView) {
        propagateEvent(on: view, eventName: "onLongPress", data: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        // TouchableOpacity is a container, delegate to child if exists
        if let child = view.subviews.first {
            let size = child.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            return CGSize(width: max(1, size.width), height: max(1, size.height))
        }
        return CGSize.zero
    }
}

/// Custom view class for touchable opacity
class TouchableView: UIView {
    weak var component: DCFTouchableOpacityComponent?
    
    var activeOpacity: CGFloat = 0.2
    
    var longPressDelay: TimeInterval = 0.5
    var longPressTimer: Timer?
    
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
    
    func startLongPressTimer() {
        cancelLongPressTimer()
        
        longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.component?.handleLongPress(self)
        }
    }
    
    func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        component?.handleTouchDown(self)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
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
