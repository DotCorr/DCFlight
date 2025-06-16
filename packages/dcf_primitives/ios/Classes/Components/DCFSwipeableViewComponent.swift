/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

// 🚀 SWIPEABLE VIEW COMPONENT - Low-level animatable view that responds to gestures
class DCFSwipeableViewComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFSwipeableViewComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let swipeableView = DCFSwipeableView()
        
        // Apply adaptive theming
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                swipeableView.backgroundColor = UIColor.systemBackground
            } else {
                swipeableView.backgroundColor = UIColor.white
            }
        } else {
            swipeableView.backgroundColor = UIColor.clear
        }
        
        updateView(swipeableView, withProps: props)
        swipeableView.applyStyles(props: props)
        
        return swipeableView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let swipeableView = view as? DCFSwipeableView else { return false }
        
        // Configure swipe properties
        swipeableView.isSwipeEnabled = props["enabled"] as? Bool ?? true
        swipeableView.swipeThreshold = props["swipeThreshold"] as? CGFloat ?? 50.0
        swipeableView.returnAnimationDuration = props["returnAnimationDuration"] as? TimeInterval ?? 0.3
        swipeableView.dragAnimationDuration = props["dragAnimationDuration"] as? TimeInterval ?? 0.1
        
        // Configure swipe directions
        if let enabledDirections = props["enabledDirections"] as? [String] {
            swipeableView.enabledDirections = Set(enabledDirections.compactMap { DCFSwipeDirection.from(string: $0) })
        }
        
        // Configure constraints and limits
        if let maxSwipeDistance = props["maxSwipeDistance"] as? CGFloat {
            swipeableView.maxSwipeDistance = maxSwipeDistance
        }
        
        if let returnToCenter = props["returnToCenter"] as? Bool {
            swipeableView.returnToCenter = returnToCenter
        }
        
        // Configure elastic behavior
        if let elasticBounce = props["elasticBounce"] as? Bool {
            swipeableView.elasticBounce = elasticBounce
        }
        
        swipeableView.applyStyles(props: props)
        return true
    }
}

// MARK: - Swipe Direction Enum

enum DCFSwipeDirection: CaseIterable {
    case left, right, up, down
    
    static func from(string: String) -> DCFSwipeDirection? {
        switch string.lowercased() {
        case "left":
            return .left
        case "right":
            return .right
        case "up", "top":
            return .up
        case "down", "bottom":
            return .down
        default:
            return nil
        }
    }
    
    var stringValue: String {
        switch self {
        case .left: return "left"
        case .right: return "right"
        case .up: return "up"
        case .down: return "down"
        }
    }
}

// MARK: - Swipeable View Implementation

class DCFSwipeableView: UIView {
    
    // MARK: - Properties
    
    var isSwipeEnabled: Bool = true
    var swipeThreshold: CGFloat = 50.0
    var maxSwipeDistance: CGFloat = 200.0
    var returnToCenter: Bool = true
    var elasticBounce: Bool = true
    var returnAnimationDuration: TimeInterval = 0.3
    var dragAnimationDuration: TimeInterval = 0.1
    
    var enabledDirections: Set<DCFSwipeDirection> = Set(DCFSwipeDirection.allCases)
    
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var initialCenter: CGPoint = .zero
    private var lastTranslation: CGPoint = .zero
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestureRecognizers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestureRecognizers()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        initialCenter = center
    }
    
    private func setupGestureRecognizers() {
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer.maximumNumberOfTouches = 1
        addGestureRecognizer(panGestureRecognizer)
    }
    
    // MARK: - Gesture Handling
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard isSwipeEnabled else { return }
        
        let translation = gesture.translation(in: superview)
        let velocity = gesture.velocity(in: superview)
        
        switch gesture.state {
        case .began:
            initialCenter = center
            lastTranslation = .zero
            
            propagateEvent(on: self, eventName: "onSwipeStart", data: [
                "translation": ["x": translation.x, "y": translation.y],
                "velocity": ["x": velocity.x, "y": velocity.y]
            ])
            
        case .changed:
            let deltaTranslation = CGPoint(
                x: translation.x - lastTranslation.x,
                y: translation.y - lastTranslation.y
            )
            
            let newTranslation = applyDirectionConstraints(translation)
            let constrainedTranslation = applyDistanceConstraints(newTranslation)
            
            // Apply translation with elastic effect if needed
            let finalTranslation = applyElasticEffect(constrainedTranslation)
            center = CGPoint(
                x: initialCenter.x + finalTranslation.x,
                y: initialCenter.y + finalTranslation.y
            )
            
            lastTranslation = translation
            
            // Determine swipe direction
            let direction = determineSwipeDirection(translation)
            
            propagateEvent(on: self, eventName: "onSwipeMove", data: [
                "translation": ["x": finalTranslation.x, "y": finalTranslation.y],
                "velocity": ["x": velocity.x, "y": velocity.y],
                "direction": direction?.stringValue ?? "none",
                "delta": ["x": deltaTranslation.x, "y": deltaTranslation.y]
            ])
            
        case .ended, .cancelled:
            let finalTranslation = applyDirectionConstraints(translation)
            let direction = determineSwipeDirection(finalTranslation)
            let distance = sqrt(finalTranslation.x * finalTranslation.x + finalTranslation.y * finalTranslation.y)
            
            let shouldTriggerSwipe = distance >= swipeThreshold
            
            if shouldTriggerSwipe, let direction = direction {
                // Trigger swipe completion
                propagateEvent(on: self, eventName: "onSwipeComplete", data: [
                    "direction": direction.stringValue,
                    "distance": distance,
                    "velocity": ["x": velocity.x, "y": velocity.y],
                    "translation": ["x": finalTranslation.x, "y": finalTranslation.y]
                ])
                
                // Animate to final position or return to center based on configuration
                if returnToCenter {
                    animateToCenter()
                } else {
                    animateToSwipePosition(direction: direction, distance: distance)
                }
            } else {
                // Return to center
                animateToCenter()
                
                propagateEvent(on: self, eventName: "onSwipeCancel", data: [
                    "translation": ["x": finalTranslation.x, "y": finalTranslation.y],
                    "velocity": ["x": velocity.x, "y": velocity.y]
                ])
            }
            
        default:
            break
        }
    }
    
    // MARK: - Constraint Methods
    
    private func applyDirectionConstraints(_ translation: CGPoint) -> CGPoint {
        var constrainedTranslation = translation
        
        if !enabledDirections.contains(.left) && translation.x < 0 {
            constrainedTranslation.x = 0
        }
        if !enabledDirections.contains(.right) && translation.x > 0 {
            constrainedTranslation.x = 0
        }
        if !enabledDirections.contains(.up) && translation.y < 0 {
            constrainedTranslation.y = 0
        }
        if !enabledDirections.contains(.down) && translation.y > 0 {
            constrainedTranslation.y = 0
        }
        
        return constrainedTranslation
    }
    
    private func applyDistanceConstraints(_ translation: CGPoint) -> CGPoint {
        let distance = sqrt(translation.x * translation.x + translation.y * translation.y)
        
        if distance <= maxSwipeDistance {
            return translation
        }
        
        let ratio = maxSwipeDistance / distance
        return CGPoint(x: translation.x * ratio, y: translation.y * ratio)
    }
    
    private func applyElasticEffect(_ translation: CGPoint) -> CGPoint {
        guard elasticBounce else { return translation }
        
        let distance = sqrt(translation.x * translation.x + translation.y * translation.y)
        
        if distance > maxSwipeDistance * 0.8 {
            // Apply elastic resistance as we approach the limit
            let resistance = 0.5 + (0.5 * (maxSwipeDistance - distance) / (maxSwipeDistance * 0.2))
            return CGPoint(
                x: translation.x * resistance,
                y: translation.y * resistance
            )
        }
        
        return translation
    }
    
    private func determineSwipeDirection(_ translation: CGPoint) -> DCFSwipeDirection? {
        let absX = abs(translation.x)
        let absY = abs(translation.y)
        
        if absX > absY {
            return translation.x > 0 ? .right : .left
        } else if absY > absX {
            return translation.y > 0 ? .down : .up
        }
        
        return nil
    }
    
    // MARK: - Animation Methods
    
    private func animateToCenter() {
        UIView.animate(
            withDuration: returnAnimationDuration,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut],
            animations: {
                self.center = self.initialCenter
            },
            completion: { _ in
                propagateEvent(on: self, eventName: "onReturnToCenter", data: [:])
            }
        )
    }
    
    private func animateToSwipePosition(direction: DCFSwipeDirection, distance: CGFloat) {
        let targetPosition: CGPoint
        
        switch direction {
        case .left:
            targetPosition = CGPoint(x: initialCenter.x - maxSwipeDistance, y: initialCenter.y)
        case .right:
            targetPosition = CGPoint(x: initialCenter.x + maxSwipeDistance, y: initialCenter.y)
        case .up:
            targetPosition = CGPoint(x: initialCenter.x, y: initialCenter.y - maxSwipeDistance)
        case .down:
            targetPosition = CGPoint(x: initialCenter.x, y: initialCenter.y + maxSwipeDistance)
        }
        
        UIView.animate(
            withDuration: dragAnimationDuration,
            delay: 0,
            options: [.curveEaseOut],
            animations: {
                self.center = targetPosition
            },
            completion: { _ in
                propagateEvent(on: self, eventName: "onSwipeAnimationComplete", data: [
                    "direction": direction.stringValue,
                    "finalPosition": ["x": targetPosition.x, "y": targetPosition.y]
                ])
            }
        )
    }
    
    // MARK: - Public Methods
    
    func resetPosition(animated: Bool = true) {
        if animated {
            animateToCenter()
        } else {
            center = initialCenter
        }
    }
    
    func setPosition(_ position: CGPoint, animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: dragAnimationDuration) {
                self.center = position
            }
        } else {
            center = position
        }
    }
}
