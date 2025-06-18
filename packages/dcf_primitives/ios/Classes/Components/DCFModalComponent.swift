/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

class DCFModalComponent: NSObject, DCFComponent {
    
    // Track presented modals
    static var presentedModals: [String: DCFModalViewController] = [:]
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        print("🚀 DCFModalComponent.createView called with props: \(props.keys.sorted())")
        
        // ✅ Use DCFEscapeView from framework layer
        let escapeView = DCFEscapeView()
        escapeView.backgroundColor = UIColor.clear
        escapeView.frame = CGRect.zero
        escapeView.bounds = CGRect.zero
        escapeView.clipsToBounds = true
        escapeView.translatesAutoresizingMaskIntoConstraints = true
        
        // ✅ Start in escaped mode (children won't be in main UI tree)
        escapeView.isEscaped = true
        
        // Apply initial properties
        let _ = updateView(escapeView, withProps: props)
        
        return escapeView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        print("🔄 DCFModalComponent updateView called with props: \(props)")
        print("🔍 DCFModalComponent updateView - view hash: \(view.hash)")
        
        // Get view ID for tracking
        let viewId = String(view.hash)
        
        // Check if modal should be visible (handle both Bool and Int types)
        var isVisible = false
        if let visible = props["visible"] as? Bool {
            isVisible = visible
            print("🔍 DCFModalComponent: Found visible as Bool: \(isVisible)")
        } else if let visible = props["visible"] as? Int {
            isVisible = visible == 1
            print("🔍 DCFModalComponent: Found visible as Int: \(visible) -> \(isVisible)")
        } else if let visible = props["visible"] as? NSNumber {
            isVisible = visible.boolValue
            print("🔍 DCFModalComponent: Found visible as NSNumber: \(visible) -> \(isVisible)")
        } else {
            print("⚠️ DCFModalComponent: No visible property found or wrong type. Props: \(props)")
        }
        
        print("🔍 DCFModalComponent: Final visible value = \(isVisible)")
        
        guard let escapeView = view as? DCFEscapeView else {
            print("❌ Error: View is not a DCFEscapeView!")
            return false
        }
        
        // ✅ CRITICAL: Force escape state when modal is not visible - DCFEscapeView handles Yoga internally
        if !isVisible {
            escapeView.isEscaped = true
            print("🚁 EscapeView: Modal not visible, forcing escaped state (DCFEscapeView handles Yoga internally)")
        }
        
        // ✅ EscapeView: Handle modal visibility
        if isVisible {
            print("🚀 DCFModalComponent: Attempting to present modal")
            presentModal(from: view, props: props, viewId: viewId)
        } else {
            // ✅ Only programmatically dismiss if we have a modal to dismiss
            if let modalVC = DCFModalComponent.presentedModals[viewId], !modalVC.isBeingDismissed {
                print("🚀 DCFModalComponent: Programmatically dismissing modal")
                dismissModal(from: view, viewId: viewId)
            } else {
                print("🔄 DCFModalComponent: Modal not presented or already being dismissed, ignoring visible=false")
            }
        }
        
        view.applyStyles(props: props)
        return true
    }
    
    // MARK: - DCFComponent Protocol Methods
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        guard let escapeView = view as? DCFEscapeView else {
            print("❌ Error: View is not a DCFEscapeView in applyLayout!")
            return
        }
        
        // ✅ CRITICAL: ALWAYS force ZERO space for the escape view container regardless of layout
        // This ensures that even if Dart sends layout properties, they are completely ignored
        view.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        view.bounds = CGRect.zero
        view.isHidden = true
        view.alpha = 0.0
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = true
        
        // ✅ CRITICAL: Force escape state to ensure zero dimensions - DCFEscapeView handles Yoga internally
        escapeView.isEscaped = true
        
        print("📐 DCFModalComponent.applyLayout - Enforced ABSOLUTE ZERO-SPACE EscapeView")
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        // ✅ CRITICAL: Modal placeholder must report ZERO intrinsic size
        print("� DCFModalComponent.getIntrinsicSize - Returning CGSize.zero")
        return CGSize.zero
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Track node registration for debugging
        print("🌳 DCFModalComponent view registered with shadow tree: \(nodeId)")
        
        // ✅ CRITICAL: Immediately force escape state for modal placeholder - DCFEscapeView handles Yoga
        if let escapeView = view as? DCFEscapeView {
            escapeView.isEscaped = true
            print("🧹 DCFModalComponent: FORCED escape state on node registration: \(nodeId)")
        }
    }
    
    private func presentModal(from view: UIView, props: [String: Any], viewId: String) {
        // Check if modal is already presented
        if DCFModalComponent.presentedModals[viewId] != nil {
            print("ℹ️ DCFModalComponent: Modal already presented for viewId \(viewId)")
            return
        }
        
        guard let escapeView = view as? DCFEscapeView else {
            print("❌ Error: View is not a DCFEscapeView!")
            return
        }
        
        // Create modal content view controller
        let modalVC = DCFModalViewController()
        modalVC.modalProps = props
        modalVC.sourceView = view
        modalVC.viewId = viewId
        
        // ✅ Load modal view and prepare content BEFORE presenting
        modalVC.loadViewIfNeeded()
        
        // ✅ Store reference to presented modal FIRST (before moving children)
        DCFModalComponent.presentedModals[viewId] = modalVC
        
        // ✅ EscapeView: Get ALL children (escaped or not) for modal presentation
        escapeView.isEscaped = false // Temporarily restore to get all children
        let childrenToMove = escapeView.getStoredChildren() + Array(escapeView.subviews) // Get all children
        print("🚁 EscapeView: Found \(childrenToMove.count) children for modal presentation")
        
        if !childrenToMove.isEmpty {
            print("🚀 Moving \(childrenToMove.count) children from EscapeView to modal")
            addChildrenToModalContent(modalVC: modalVC, childViews: childrenToMove)
            escapeView.isEscaped = true // Escape them again from main UI
        } else {
            print("⚠️ No children found in EscapeView - modal will show empty")
        }
        
        // Configure modal presentation style
        if #available(iOS 15.0, *) {
            modalVC.modalPresentationStyle = .pageSheet
            
            // Configure sheet presentation controller with detents
            if let sheet = modalVC.sheetPresentationController {
                configureSheetDetents(sheet: sheet, modalVC: modalVC, props: props)
            }
        } else {
            // Fallback for older iOS versions
            modalVC.modalPresentationStyle = .formSheet
        }
        
        // Configure transition style
        if let transitionStyle = props["transitionStyle"] as? String {
            switch transitionStyle.lowercased() {
            case "coververtical":
                modalVC.modalTransitionStyle = .coverVertical
            case "fliphorizontal":
                modalVC.modalTransitionStyle = .flipHorizontal
            case "crossdissolve":
                modalVC.modalTransitionStyle = .crossDissolve
            case "partialcurl":
                if #available(iOS 3.2, *) {
                    modalVC.modalTransitionStyle = .partialCurl
                }
            default:
                modalVC.modalTransitionStyle = .coverVertical
            }
        }
        
        // Present the modal
        if let topViewController = getTopViewController() {
            topViewController.present(modalVC, animated: true) {
                propagateEvent(on: view, eventName: "onShow", data: [:])
            }
        }
    }
    
    private func dismissModal(from view: UIView, viewId: String) {
        guard let escapeView = view as? DCFEscapeView else {
            print("❌ Error: View is not a DCFEscapeView!")
            return
        }
        
        if let modalVC = DCFModalComponent.presentedModals[viewId] {
            print("🔄 DCFModalComponent: Programmatically dismissing tracked modal")
            
            // ✅ EscapeView: Move children back to escape view for programmatic dismissal
            let modalChildren = modalVC.view.subviews.filter { $0.tag != 999 && $0.tag != 998 }
            
            if !modalChildren.isEmpty {
                print("🚁 EscapeView: Moving \(modalChildren.count) children back to EscapeView and escaping them")
                
                // Store children in escape view
                escapeView.setStoredChildren(modalChildren)
                
                // Remove children from modal
                modalChildren.forEach { child in
                    child.removeFromSuperview()
                }
                
                // ✅ Escape the children (remove from main UI tree)
                escapeView.isEscaped = true
            }
            
            modalVC.dismiss(animated: true) {
                propagateEvent(on: view, eventName: "onDismiss", data: [:])
            }
            // Remove from tracking
            DCFModalComponent.presentedModals.removeValue(forKey: viewId)
        }
    }
    
    private func addChildrenToModalContent(modalVC: DCFModalViewController, childViews: [UIView]) {
        print("📦 Adding \(childViews.count) children to modal content")
        
        // Clear existing children from modal
        modalVC.view.subviews.forEach { $0.removeFromSuperview() }
        
        // Add children to modal content and make them visible
        childViews.forEach { childView in
            modalVC.view.addSubview(childView)
            childView.isHidden = false
            childView.alpha = 1.0
            childView.isUserInteractionEnabled = true
        }
        
        // Trigger layout update
        modalVC.view.setNeedsLayout()
        modalVC.view.layoutIfNeeded()
    }
    
    @available(iOS 15.0, *)
    private func configureSheetDetents(sheet: UISheetPresentationController, modalVC: DCFModalViewController, props: [String: Any]) {
        var detents: [UISheetPresentationController.Detent] = []
        
        if let detentStrings = props["detents"] as? [String] {
            for detentString in detentStrings {
                switch detentString.lowercased() {
                case "small", "compact":
                    detents.append(.medium())
                case "medium", "half":
                    detents.append(.medium())
                case "large", "full":
                    detents.append(.large())
                default:
                    detents.append(.medium())
                }
            }
        }
        
        if detents.isEmpty {
            detents = [.medium(), .large()]
        }
        
        sheet.detents = detents
        sheet.prefersGrabberVisible = props["showDragIndicator"] as? Bool ?? true
        
        // ✅ EXPOSE CORNER RADIUS API: Set corner radius from Dart props
        if let cornerRadius = props["cornerRadius"] as? Double {
            sheet.preferredCornerRadius = CGFloat(cornerRadius)
        } else if let cornerRadius = props["cornerRadius"] as? NSNumber {
            sheet.preferredCornerRadius = CGFloat(cornerRadius.doubleValue)
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topController = window.rootViewController
        while let presentedViewController = topController?.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }
}

// MARK: - DCFModalViewController

class DCFModalViewController: UIViewController {
    var modalProps: [String: Any] = [:]
    weak var sourceView: UIView?
    var viewId: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupModalContent()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if isBeingDismissed {
            print("✅ Modal viewDidDisappear - actually dismissed")
            // Move children back to EscapeView when modal is dismissed
            if let sourceView = sourceView, let escapeView = sourceView as? DCFEscapeView {
                let modalChildren = view.subviews.filter { $0.tag != 999 && $0.tag != 998 }
                
                if !modalChildren.isEmpty {
                    print("🚁 EscapeView: Moving \(modalChildren.count) children back to EscapeView on dismiss")
                    
                    // Store children in escape view and remove from modal
                    escapeView.setStoredChildren(modalChildren)
                    modalChildren.forEach { child in
                        child.removeFromSuperview()
                    }
                    
                    escapeView.isEscaped = true
                }
                
                // Remove from tracking
                DCFModalComponent.presentedModals.removeValue(forKey: viewId)
                propagateEvent(on: sourceView, eventName: "onDismiss", data: [:])
            }
        }
    }
    
    private func setupModalContent() {
        view.backgroundColor = UIColor.systemBackground
        
        // ✅ CRITICAL: Apply corner radius from Dart props - handle all possible data types
        var cornerRadiusApplied = false
        
        if let cornerRadius = modalProps["cornerRadius"] as? Double {
            view.layer.cornerRadius = CGFloat(cornerRadius)
            view.layer.masksToBounds = true
            cornerRadiusApplied = true
            print("🎨 Applied modal corner radius (Double): \(cornerRadius)")
        } else if let cornerRadius = modalProps["cornerRadius"] as? NSNumber {
            view.layer.cornerRadius = CGFloat(cornerRadius.doubleValue)
            view.layer.masksToBounds = true
            cornerRadiusApplied = true
            print("🎨 Applied modal corner radius (NSNumber): \(cornerRadius)")
        } else if let cornerRadius = modalProps["cornerRadius"] as? Float {
            view.layer.cornerRadius = CGFloat(cornerRadius)
            view.layer.masksToBounds = true
            cornerRadiusApplied = true
            print("🎨 Applied modal corner radius (Float): \(cornerRadius)")
        } else if let cornerRadius = modalProps["cornerRadius"] as? Int {
            view.layer.cornerRadius = CGFloat(cornerRadius)
            view.layer.masksToBounds = true
            cornerRadiusApplied = true
            print("🎨 Applied modal corner radius (Int): \(cornerRadius)")
        } else if let cornerRadiusString = modalProps["cornerRadius"] as? String,
                  let cornerRadius = Double(cornerRadiusString) {
            view.layer.cornerRadius = CGFloat(cornerRadius)
            view.layer.masksToBounds = true
            cornerRadiusApplied = true
            print("🎨 Applied modal corner radius (String): \(cornerRadius)")
        }
        
        if !cornerRadiusApplied {
            print("⚠️ Corner radius not found or invalid type in modalProps: \(modalProps.keys.sorted())")
            if let cornerRadiusValue = modalProps["cornerRadius"] {
                print("⚠️ Corner radius value type: \(type(of: cornerRadiusValue)), value: \(cornerRadiusValue)")
            }
        }
        
        // Propagate onOpen event
        if let sourceView = sourceView {
            propagateEvent(on: sourceView, eventName: "onOpen", data: [:])
        }
    }
}

// MARK: - Helper Functions

private func propagateEvent(on view: UIView, eventName: String, data: [String: Any]) {
    // Implementation for event propagation
    print("📡 Propagating event: \(eventName) on view: \(view)")
}
