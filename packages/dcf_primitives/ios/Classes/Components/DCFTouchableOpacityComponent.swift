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
    
    // CRITICAL FIX: Store strong references to component instances per view
    private static var componentInstances = NSMapTable<UIView, DCFTouchableOpacityComponent>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let touchableView = TouchableView()
        
        // CRITICAL FIX: Create a new component instance and store it strongly
        let componentInstance = DCFTouchableOpacityComponent()
        touchableView.component = componentInstance
        DCFTouchableOpacityComponent.componentInstances.setObject(componentInstance, forKey: touchableView)
        
        print("✅ Created TouchableView with component instance: \(ObjectIdentifier(componentInstance))")
        
        touchableView.isUserInteractionEnabled = true
        
        // Use a custom touch tracking gesture that recognizes immediately
        let touchTrackingGesture = TouchTrackingGestureRecognizer(target: touchableView, action: #selector(TouchableView.handleTouchTracking(_:)))
        touchTrackingGesture.cancelsTouchesInView = false
        touchTrackingGesture.delaysTouchesBegan = false
        touchTrackingGesture.delaysTouchesEnded = false
        touchTrackingGesture.delegate = touchableView
        touchableView.addGestureRecognizer(touchTrackingGesture)
        
        updateView(touchableView, withProps: props)
        touchableView.applyStyles(props: props)
        
        return touchableView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let touchableView = view as? TouchableView else { return false }
        
        // CRITICAL FIX: Restore component reference if it was lost
        if touchableView.component == nil {
            if let existingComponent = DCFTouchableOpacityComponent.componentInstances.object(forKey: touchableView) {
                touchableView.component = existingComponent
                print("⚠️ Restored component reference from map")
            } else {
                let newComponent = DCFTouchableOpacityComponent()
                touchableView.component = newComponent
                DCFTouchableOpacityComponent.componentInstances.setObject(newComponent, forKey: touchableView)
                print("⚠️ Created new component instance in updateView")
            }
        }
        
        if let activeOpacity = props["activeOpacity"] as? CGFloat {
            touchableView.activeOpacity = activeOpacity
        } else {
            touchableView.activeOpacity = 0.2
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
        print("🟡 DCFTouchableOpacity: handleTouchDown - activeOpacity: \(view.activeOpacity)")
        
        UIView.animate(withDuration: 0.1) {
            view.alpha = view.activeOpacity
        }
        
        propagateEvent(on: view, eventName: "onPressIn", data: [
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "fromUser": true
        ])
        
        view.startLongPressTimer()
    }
    
    func handleTouchUp(_ view: TouchableView, inside: Bool) {
        print("🟡 DCFTouchableOpacity: handleTouchUp - inside: \(inside)")
        view.cancelLongPressTimer()
        
        UIView.animate(withDuration: 0.1) {
            view.alpha = 1.0
        }
        
        propagateEvent(on: view, eventName: "onPressOut", data: [
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "fromUser": true
        ])
        
        if inside {
            print("🟡 DCFTouchableOpacity: Firing onPress event")
            propagateEvent(on: view, eventName: "onPress", data: [
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                "fromUser": true
            ])
        }
    }
    
    func handleLongPress(_ view: TouchableView) {
        propagateEvent(on: view, eventName: "onLongPress", data: [
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "fromUser": true
        ])
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
}

/// Custom view class for touchable opacity
class TouchableView: UIView, UIGestureRecognizerDelegate {
    // CRITICAL FIX: Changed from weak to strong (but still optional)
    var component: DCFTouchableOpacityComponent?
    
    var activeOpacity: CGFloat = 0.2
    var longPressDelay: TimeInterval = 0.5
    var longPressTimer: Timer?
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
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
        self.isMultipleTouchEnabled = false
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !isUserInteractionEnabled || isHidden || alpha < 0.01 {
            return super.hitTest(point, with: event)
        }
        
        if !bounds.contains(point) {
            return super.hitTest(point, with: event)
        }
        
        // Check children first
        for subview in subviews.reversed() {
            let convertedPoint = subview.convert(point, from: self)
            if let hitView = subview.hitTest(convertedPoint, with: event) {
                return hitView
            }
        }
        
        return self
    }
    
    @objc func handleTouchTracking(_ gesture: TouchTrackingGestureRecognizer) {
        let location = gesture.location(in: self)
        let inside = bounds.contains(location)
        
        guard let comp = component else {
            print("❌ ERROR: component is nil in handleTouchTracking! View: \(self)")
            return
        }
        
        switch gesture.state {
        case .began:
            print("🔵 TouchTrackingGesture: began")
            comp.handleTouchDown(self)
        case .ended:
            print("🔵 TouchTrackingGesture: ended, inside: \(inside)")
            comp.handleTouchUp(self, inside: inside)
        case .cancelled, .failed:
            print("🔵 TouchTrackingGesture: cancelled/failed")
            comp.handleTouchUp(self, inside: false)
        default:
            break
        }
    }
    
    func startLongPressTimer() {
        cancelLongPressTimer()
        
        longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDelay, repeats: false) { [weak self] _ in
            guard let self = self, let comp = self.component else { return }
            comp.handleLongPress(self)
        }
    }
    
    func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    // Fallback touch handlers (in case gesture recognizer doesn't fire)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("🟢 TouchableView touchesBegan - component exists: \(component != nil)")
        if let comp = component {
            comp.handleTouchDown(self)
        } else {
            print("❌ ERROR: component is nil in touchesBegan!")
        }
        super.touchesBegan(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        if let comp = component {
            if let touch = touches.first {
                let point = touch.location(in: self)
                let inside = bounds.contains(point)
                comp.handleTouchUp(self, inside: inside)
            } else {
                comp.handleTouchUp(self, inside: false)
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        component?.handleTouchUp(self, inside: false)
    }
}

/// Custom gesture recognizer that recognizes touches immediately
class TouchTrackingGestureRecognizer: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.state == .possible {
            self.state = .began
        }
        super.touchesBegan(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.state == .began {
            self.state = .changed
        }
        super.touchesMoved(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.state == .began || self.state == .changed {
            self.state = .ended
        }
        super.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.state == .began || self.state == .changed {
            self.state = .cancelled
        }
        super.touchesCancelled(touches, with: event)
    }
    
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    override func shouldRequireFailure(of otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    override func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}
