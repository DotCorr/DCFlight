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
        
        // Create a basic container view - this will be the portal host
        let view = UIView()
        view.backgroundColor = UIColor.clear
        
        // Apply initial properties
        let _ = updateView(view, withProps: props)
        
        return view
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
        if isVisible {
            print("🚀 DCFModalComponent: Attempting to present modal")
            presentModal(from: view, props: props, viewId: viewId)
        } else {
            print("🚀 DCFModalComponent: Attempting to dismiss modal")
            dismissModal(from: view, viewId: viewId)
        }
        
        view.applyStyles(props: props)
        return true
    }
    
    // MARK: - DCFComponent Protocol Methods
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        // Modal components handle their own layout through modal presentation
        // Apply basic layout to the container if needed
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        // Modal components don't have intrinsic size since they're presented
        return CGSize.zero
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Track node registration for debugging
        print("🌳 DCFModalComponent view registered with shadow tree: \(nodeId)")
    }
    
    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
        print("🚀 DCFModalComponent.setChildren called with \(childViews.count) children for viewId: \(viewId)")
        print("🚀 DCFModalComponent.setChildren - view hash: \(view.hash)")
        print("🚀 DCFModalComponent.setChildren - children types: \(childViews.map { type(of: $0) })")
        
        // Always store children in the placeholder view first
        view.subviews.forEach { $0.removeFromSuperview() }
        childViews.forEach { childView in
            view.addSubview(childView)
        }
        
        // If modal is currently presented, move children to the modal content
        if let modalVC = DCFModalComponent.presentedModals[viewId] {
            print("✅ Modal is presented, moving children to modal content view")
            // Move children from placeholder to modal (they will be moved back on dismiss)
            addChildrenToModalContent(modalVC: modalVC, childViews: Array(view.subviews))
        } else {
            print("⚠️ Modal not currently presented for viewId \(viewId), children stored in placeholder view")
        }
        
        return true
    }
    
    private func addChildrenToModalContent(modalVC: DCFModalViewController, childViews: [UIView]) {
        // Clear existing children from modal content
        modalVC.view.subviews.forEach { subview in
            // Don't remove system views, only our content
            if subview.tag != 999 && subview.tag != 998 { // Preserve title and container
                print("🗑️ Removing existing subview from modal: \(type(of: subview))")
                subview.removeFromSuperview()
            }
        }
        
        // ✅ GIVE ABSTRACTION LAYER FULL CONTROL: No explicit margins/padding, full width/height
        let modalFrame = modalVC.view.bounds
        let availableWidth = modalFrame.width
        let availableHeight = modalFrame.height
        
        print("📏 Modal FULL sizing - available: \(availableWidth)x\(availableHeight)")
        
        // ✅ AUTO-FILL: Single child fills the entire modal space, let abstraction layer handle layout
        if childViews.count == 1, let childView = childViews.first {
            print("🎯 Single child: giving it FULL modal space for abstraction layer control")
            
            // Remove from any previous parent
            childView.removeFromSuperview()
            
            // ✅ KEY: Disable Auto Layout - use manual frame positioning 
            childView.translatesAutoresizingMaskIntoConstraints = true
            
            // Add to modal view
            modalVC.view.addSubview(childView)
            
            // ✅ FULL FRAME: Give child the entire modal space (0 margins/padding)
            childView.frame = CGRect(
                x: 0,
                y: 0, 
                width: availableWidth,
                height: availableHeight
            )
            
            print("📐 Child given FULL modal frame: \(childView.frame)")
            
        } else if childViews.count > 1 {
            // Multiple children: stack vertically but use full width
            print("📚 Multiple children: stacking with full width, letting abstraction layer control spacing")
            
            var currentY: CGFloat = 0 // Start at top, no margins
            
            for (index, childView) in childViews.enumerated() {
                print("🔄 Adding child \(index) with full width: \(type(of: childView))")
                
                // Remove from any previous parent
                childView.removeFromSuperview()
                
                // ✅ KEY: Disable Auto Layout
                childView.translatesAutoresizingMaskIntoConstraints = true
                
                // Add to modal view
                modalVC.view.addSubview(childView)
                
                // Use child's existing height or default
                var childHeight: CGFloat = childView.frame.height > 0 ? childView.frame.height : 44
                let intrinsicSize = childView.intrinsicContentSize
                if intrinsicSize.height > 0 {
                    childHeight = intrinsicSize.height
                }
                
                // ✅ FULL WIDTH POSITIONING: Let abstraction layer handle internal spacing
                let childFrame = CGRect(
                    x: 0, // No left margin
                    y: currentY,
                    width: availableWidth, // Full width
                    height: childHeight
                )
                
                childView.frame = childFrame
                print("📐 Child \(index) frame: \(childFrame)")
                
                // No extra spacing - let abstraction layer control it
                currentY += childHeight
            }
        }
        
        print("✅ Modal content positioned with FULL space control given to abstraction layer")
    }
    
    // MARK: - Modal Presentation
    
    private func presentModal(from view: UIView, props: [String: Any], viewId: String) {
        // Check if modal is already presented
        if DCFModalComponent.presentedModals[viewId] != nil {
            print("ℹ️ DCFModalComponent: Modal already presented for viewId \(viewId)")
            return
        }
        
        // Create modal content view controller
        let modalVC = DCFModalViewController()
        modalVC.modalProps = props
        modalVC.sourceView = view
        modalVC.viewId = viewId
        
        // ✅ FIX 1: Load modal view and prepare content BEFORE presenting
        modalVC.loadViewIfNeeded()
        
        // Pre-populate modal content to avoid white screen
        let existingChildren = view.subviews
        if !existingChildren.isEmpty {
            print("🚀 Pre-populating modal with \(existingChildren.count) existing children from placeholder view")
            self.addChildrenToModalContent(modalVC: modalVC, childViews: existingChildren)
            
            // ✅ FIX: Clear children from placeholder view after moving to modal
            // This prevents children from appearing in both places
            view.subviews.forEach { $0.removeFromSuperview() }
        } else {
            print("⚠️ No existing children found in placeholder view for modal")
        }
        
        // Store reference to presented modal BEFORE presentation
        DCFModalComponent.presentedModals[viewId] = modalVC
        
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
        
        // Configure status bar appearance capture
        if let capturesStatusBar = props["capturesStatusBarAppearance"] as? Bool {
            modalVC.modalPresentationCapturesStatusBarAppearance = capturesStatusBar
        }
        
        // Configure presentation context
        if let definesPresentationContext = props["definesPresentationContext"] as? Bool {
            modalVC.definesPresentationContext = definesPresentationContext
        }
        
        // Configure transition context
        if let providesTransitionContext = props["providesTransitionContext"] as? Bool {
            modalVC.providesPresentationContextTransitionStyle = providesTransitionContext
        }
        
        // Present the modal
        if let topViewController = getTopViewController() {
            print("🚀 DCFModalComponent: Presenting modal from \(String(describing: topViewController))")
            
            topViewController.present(modalVC, animated: true) {
                print("✅ DCFModalComponent: Modal presented successfully")
                
                // Propagate onShow event
                propagateEvent(on: view, eventName: "onShow", data: [:])
            }
        } else {
            print("❌ DCFModalComponent: Could not find view controller to present from")
            // Remove from tracking if presentation failed
            DCFModalComponent.presentedModals.removeValue(forKey: viewId)
        }
    }
    
    @available(iOS 15.0, *)
    private func configureSheetDetents(sheet: UISheetPresentationController, modalVC: UIViewController, props: [String: Any]) {
        var detents: [UISheetPresentationController.Detent] = []
        
        // Parse detents from props
        if let detentArray = props["detents"] as? [String] {
            for detentString in detentArray {
                switch detentString.lowercased() {
                case "small", "compact":
                    if #available(iOS 16.0, *) {
                        detents.append(.custom(identifier: .init("small")) { context in
                            return context.maximumDetentValue * 0.3
                        })
                    } else {
                        detents.append(.medium())
                    }
                case "medium", "half":
                    detents.append(.medium())
                case "large", "full":
                    detents.append(.large())
                default:
                    detents.append(.medium())
                }
            }
        } else {
            // Default detents
            detents = [.medium(), .large()]
        }
        
        sheet.detents = detents
        
        // Configure selected detent index
        if #available(iOS 16.0, *) {
            if let selectedDetentIndex = props["selectedDetentIndex"] as? Int,
               selectedDetentIndex < detents.count {
                sheet.selectedDetentIdentifier = detents[selectedDetentIndex].identifier
            }
        }
        
        // Configure other sheet properties
        sheet.prefersGrabberVisible = props["showDragIndicator"] as? Bool ?? true
        sheet.preferredCornerRadius = props["cornerRadius"] as? CGFloat ?? 16.0
        
        // Configure dismissal behavior - use the modal view controller, not the sheet
        if let isDismissible = props["isDismissible"] as? Bool {
            modalVC.isModalInPresentation = !isDismissible
        }
        
        // Configure background interaction
        if props["allowsBackgroundDismiss"] as? Bool == false {
            modalVC.isModalInPresentation = true
        }
    }
    
    private func dismissModal(from view: UIView, viewId: String) {
        if let modalVC = DCFModalComponent.presentedModals[viewId] {
            print("🔄 DCFModalComponent: Dismissing tracked modal")
            
            // ✅ FIX: Save children back to placeholder before dismissing
            let modalChildren = modalVC.view.subviews.filter { $0.tag != 999 && $0.tag != 998 }
            
            if !modalChildren.isEmpty {
                print("💾 Preserving \(modalChildren.count) children in placeholder view before dismissal")
                
                // Clear existing children from placeholder
                view.subviews.forEach { $0.removeFromSuperview() }
                
                // Move children back to placeholder view
                modalChildren.forEach { child in
                    child.removeFromSuperview()
                    view.addSubview(child)
                }
            }
            
            modalVC.dismiss(animated: true) {
                propagateEvent(on: view, eventName: "onDismiss", data: [:])
            }
            // Remove from tracking
            DCFModalComponent.presentedModals.removeValue(forKey: viewId)
        } else if let topViewController = getTopViewController(),
                  topViewController.presentedViewController != nil {
            print("🔄 DCFModalComponent: Dismissing any presented modal")
            topViewController.dismiss(animated: true) {
                propagateEvent(on: view, eventName: "onDismiss", data: [:])
            }
        } else {
            print("ℹ️ DCFModalComponent: No modal to dismiss")
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { 
            print("❌ DCFModalComponent: Could not find window scene")
            return nil 
        }
        
        var topController = window.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        print("🎯 DCFModalComponent: Using top view controller: \(String(describing: topController))")
        return topController
    }
}

// MARK: - Modal View Controller

class DCFModalViewController: UIViewController {
    var modalProps: [String: Any] = [:]
    weak var sourceView: UIView?
    var viewId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupModalContent()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Only propagate dismiss event if modal is being dismissed, not just rotating
        if isBeingDismissed {
            // ✅ FIX: Save children back to placeholder view before dismissing
            if let sourceView = sourceView {
                // Collect all children from modal (excluding title and system views)
                let modalChildren = view.subviews.filter { $0.tag != 999 && $0.tag != 998 }
                
                if !modalChildren.isEmpty {
                    print("💾 Saving \(modalChildren.count) children back to placeholder view before modal dismissal")
                    
                    // Clear existing children from placeholder
                    sourceView.subviews.forEach { $0.removeFromSuperview() }
                    
                    // Move children back to placeholder view
                    modalChildren.forEach { child in
                        child.removeFromSuperview()
                        sourceView.addSubview(child)
                    }
                }
                
                propagateEvent(on: sourceView, eventName: "onDismiss", data: [:])
            }
            
            // Remove from tracking when dismissed
            if let viewId = viewId {
                DCFModalComponent.presentedModals.removeValue(forKey: viewId)
            }
        }
    }
    
    // ✅ FIX: Debug and fix shadow view overlay issue
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Debug view hierarchy to find problematic overlays
        DispatchQueue.main.async {
            self.debugViewHierarchy()
        }
    }
    
    private func debugViewHierarchy() {
        print("🔍 DCFModalViewController view hierarchy:")
        debugPrintViewHierarchy(view: self.view, level: 0)
        
        // Look for problematic shadow or overlay views
        findAndFixProblematicViews(in: self.view)
    }
    
    private func debugPrintViewHierarchy(view: UIView, level: Int) {
        let indent = String(repeating: "  ", count: level)
        print("\(indent)- \(type(of: view)) (frame: \(view.frame), userInteractionEnabled: \(view.isUserInteractionEnabled))")
        
        for subview in view.subviews {
            debugPrintViewHierarchy(view: subview, level: level + 1)
        }
    }
    
    private func findAndFixProblematicViews(in view: UIView) {
        // Look for shadow views or transparent overlays that might intercept touches
        for subview in view.subviews {
            let className = String(describing: type(of: subview))
            
            // Check for known problematic view types like _UIRoundedRectShadowView
            if className.contains("Shadow") || className.contains("Rounded") || className.contains("Overlay") || className.contains("_UI") {
                print("🚨 Found potential problematic view: \(className)")
                print("   Frame: \(subview.frame)")
                print("   UserInteractionEnabled: \(subview.isUserInteractionEnabled)")
                print("   Background: \(String(describing: subview.backgroundColor))")
                
                // Try disabling user interaction on problematic views
                if subview.isUserInteractionEnabled {
                    print("   🔧 Disabling user interaction on overlay view: \(className)")
                    subview.isUserInteractionEnabled = false
                }
            }
            
            findAndFixProblematicViews(in: subview)
        }
    }
    
    private func setupModalContent() {
        view.backgroundColor = UIColor.systemBackground
        
        // ✅ REMOVED: No automatic title rendering - let abstraction layer handle titles
        // The title prop is still available in modalProps for the abstraction layer to use
        // but we don't force any specific title rendering or safe area constraints
        
        // Propagate onOpen event
        if let sourceView = sourceView {
            propagateEvent(on: sourceView, eventName: "onOpen", data: [:])
        }
    }
}
