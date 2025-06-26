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
    
    // FRAMEWORK FIX: Modal presentation queue to handle sequential operations
    static var modalOperationQueue: DispatchQueue = DispatchQueue(label: "DCFModalOperationQueue", qos: .userInitiated)
    static var pendingOperations: [(operation: ModalOperation, viewId: String, completion: (() -> Void)?)] = []
    static var isProcessingOperations = false
    
    enum ModalOperation {
        case present(view: UIView, props: [String: Any])
        case dismiss(view: UIView)
    }
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        
        // Create a simple placeholder view
        let view = UIView()
        
        // Set the view as hidden but don't override its geometry
        view.isHidden = true
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = false
        
        let _ = updateView(view, withProps: props)
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        
        // Get view ID for tracking
        let viewId = String(view.hash)
        
        // Check if modal should be visible (handle both Bool and Int types)
        var isVisible = false
        if let visible = props["visible"] as? Bool {
            isVisible = visible
        } else if let visible = props["visible"] as? Int {
            isVisible = visible == 1
        } else if let visible = props["visible"] as? NSNumber {
            isVisible = visible.boolValue
        } else {
        }
        
        
        // ✅ FRAMEWORK FIX: Queue modal operations to prevent conflicts
        if isVisible {
            DCFModalComponent.queueModalOperation(.present(view: view, props: props), viewId: viewId)
        } else {
            // Only programmatically dismiss if we have a modal to dismiss
            if let modalVC = DCFModalComponent.presentedModals[viewId], !modalVC.isBeingDismissed {
                DCFModalComponent.queueModalOperation(.dismiss(view: view), viewId: viewId)
            } else {
            }
        }
        
        view.applyStyles(props: props)
        return true
    }
    
    // MARK: - DCFComponent Protocol Methods
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        // Apply the layout calculated by Yoga
        // When display="none", Yoga will calculate zero dimensions
        view.frame = CGRect(
            x: CGFloat(layout.left),
            y: CGFloat(layout.top),
            width: CGFloat(layout.width),
            height: CGFloat(layout.height)
        )
        
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        // Return a minimal intrinsic size
        // The actual space allocation will be controlled by the display property
        return CGSize(width: 1, height: 1)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        // Track node registration for debugging
    }
    
    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
        
        // 🚨 CRITICAL DEBUG: Print stack trace to see WHO is calling setChildren
        Thread.callStackSymbols.forEach { symbol in
            if symbol.contains("DCF") || symbol.contains("Modal") {
            }
        }
        
        // Store children in placeholder but keep them hidden from main UI
        view.subviews.forEach { $0.removeFromSuperview() }
        childViews.forEach { childView in
            view.addSubview(childView)
            // Hide children in placeholder view (they'll be shown when moved to modal)
            childView.isHidden = true
            childView.alpha = 0.0
        }
        
        
        // If modal is currently presented, move children to modal content and make them visible
        if let modalVC = DCFModalComponent.presentedModals[viewId] {
            addChildrenToModalContent(modalVC: modalVC, childViews: childViews)
        } else {
        }
        
        return true
    }
    
    private func addChildrenToModalContent(modalVC: DCFModalViewController, childViews: [UIView]) {
        // Clear existing children from modal content
        modalVC.view.subviews.forEach { subview in
            // Don't remove system views, only our content
            if subview.tag != 999 && subview.tag != 998 { // Preserve title and container
                subview.removeFromSuperview()
            }
        }
        
        // ✅ FIX 2: Force view layout to get accurate bounds before sizing children
        modalVC.view.setNeedsLayout()
        modalVC.view.layoutIfNeeded()
        
        // ✅ GIVE ABSTRACTION LAYER FULL CONTROL: No explicit margins/padding, full width/height
        let modalFrame = modalVC.view.bounds
        _ = modalFrame.width
        _ = modalFrame.height
        
        
        // ✅ ABSTRACTION LAYER CONTROL: Use the full modal bounds, no automatic safe area adjustments
        // Let the Dart abstraction layer handle safe areas, padding, and margins as it sees fit
        let contentFrame = modalFrame
        
        // ✅ AUTO-FILL: Single child fills the entire modal space, let abstraction layer handle layout
        if childViews.count == 1, let childView = childViews.first {
            
            // Remove from any previous parent
            childView.removeFromSuperview()
            
            // ✅ KEY: Disable Auto Layout - use manual frame positioning
            childView.translatesAutoresizingMaskIntoConstraints = true
            
            // Add to modal view
            modalVC.view.addSubview(childView)
            
            // ✅ MAKE VISIBLE: Child should be visible in modal (opposite of placeholder)
            childView.isHidden = false
            childView.alpha = 1.0
            
            // ✅ FULL FRAME: Give child the entire content area
            childView.frame = contentFrame
            
            
            // ✅ Force layout update to ensure Yoga gets the correct size
            childView.setNeedsLayout()
            childView.layoutIfNeeded()
            
        } else if childViews.count > 1 {
            // Multiple children: stack vertically but use full width
            
            var currentY: CGFloat = contentFrame.minY // Start at content area top
            
            for (index, childView) in childViews.enumerated() {
                
                // Remove from any previous parent
                childView.removeFromSuperview()
                
                // ✅ KEY: Disable Auto Layout
                childView.translatesAutoresizingMaskIntoConstraints = true
                
                // Add to modal view
                modalVC.view.addSubview(childView)
                
                // ✅ MAKE VISIBLE: Child should be visible in modal
                childView.isHidden = false
                childView.alpha = 1.0
                
                // Use child's existing height or default
                var childHeight: CGFloat = childView.frame.height > 0 ? childView.frame.height : 44
                let intrinsicSize = childView.intrinsicContentSize
                if intrinsicSize.height > 0 {
                    childHeight = intrinsicSize.height
                }
                
                // ✅ FULL WIDTH POSITIONING: Let abstraction layer handle internal spacing
                let childFrame = CGRect(
                    x: contentFrame.minX, // Respect content area
                    y: currentY,
                    width: contentFrame.width, // Full content width
                    height: childHeight
                )
                
                childView.frame = childFrame
                
                // Force layout update for this child
                childView.setNeedsLayout()
                childView.layoutIfNeeded()
                
                // No extra spacing - let abstraction layer control it
                currentY += childHeight
            }
        }
        
    }
    // MARK: - Modal Operation Queue System (replaces old presentModal method)
    
    @available(iOS 15.0, *)
    private func configureSheetDetents(sheet: UISheetPresentationController, modalVC: UIViewController, props: [String: Any]) {
        var detents: [UISheetPresentationController.Detent] = []
        
        // ✅ FIX 1: Apply corner radius to sheet presentation controller
        var cornerRadius: CGFloat = 16.0 // Default value
        if let radius = props["cornerRadius"] as? CGFloat {
            cornerRadius = radius
        } else if let radius = props["cornerRadius"] as? Double {
            cornerRadius = CGFloat(radius)
        } else if let radius = props["cornerRadius"] as? Int {
            cornerRadius = CGFloat(radius)
        } else if let radius = props["cornerRadius"] as? NSNumber {
            cornerRadius = CGFloat(radius.doubleValue)
        } else {
        }
        
        // Apply corner radius to the sheet
        if #available(iOS 16.0, *) {
            sheet.preferredCornerRadius = cornerRadius
        }
        
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

        if let radius = props["cornerRadius"] as? CGFloat {
            cornerRadius = radius
        } else if let radius = props["cornerRadius"] as? Double {
            cornerRadius = CGFloat(radius)
        } else if let radius = props["cornerRadius"] as? Int {
            cornerRadius = CGFloat(radius)
        } else if let radius = props["cornerRadius"] as? NSNumber {
            cornerRadius = CGFloat(radius.doubleValue)
        } else {
        }
        
        sheet.preferredCornerRadius = cornerRadius
        
        // Configure dismissal behavior - use the modal view controller, not the sheet
        if let isDismissible = props["isDismissible"] as? Bool {
            modalVC.isModalInPresentation = !isDismissible
        }
        
        // Configure background interaction
        if props["allowsBackgroundDismiss"] as? Bool == false {
            modalVC.isModalInPresentation = true
        }
        
        // ✅ CRITICAL FIX: Set delegate to handle drag dismissal properly
        if let dcfModalVC = modalVC as? DCFModalViewController {
            sheet.delegate = dcfModalVC
        }
    }
    
    // NOTE: The old dismissModalWithoutMovingChildren and dismissModal methods have been
    // removed as all modal operations now go through the queue system in processQueuedOperation
    
    // MARK: - Modal Operation Queue System
    
    /// Queue a modal operation to be processed sequentially
    static func queueModalOperation(_ operation: ModalOperation, viewId: String, completion: (() -> Void)? = nil) {
        modalOperationQueue.async {
            pendingOperations.append((operation: operation, viewId: viewId, completion: completion))
            
            if !isProcessingOperations {
                processNextModalOperation()
            }
        }
    }
    
    /// Process the next modal operation in the queue
    static func processNextModalOperation() {
        guard !isProcessingOperations, !pendingOperations.isEmpty else { return }
        
        isProcessingOperations = true
        let nextOperation = pendingOperations.removeFirst()
        
        DispatchQueue.main.async {
            switch nextOperation.operation {
            case .present(let view, let props):
                self.performModalPresentation(from: view, props: props, viewId: nextOperation.viewId) {
                    nextOperation.completion?()
                    self.isProcessingOperations = false
                    // Process next operation after a brief delay to ensure proper sequencing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.processNextModalOperation()
                    }
                }
                
            case .dismiss(let view):
                self.performModalDismissal(from: view, viewId: nextOperation.viewId) {
                    nextOperation.completion?()
                    self.isProcessingOperations = false
                    // Process next operation after a brief delay to ensure proper sequencing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.processNextModalOperation()
                    }
                }
            }
        }
    }
    
    /// Perform the actual modal presentation (extracted from presentModal)
    static func performModalPresentation(from view: UIView, props: [String: Any], viewId: String, completion: @escaping () -> Void) {
        // Check if modal is already presented
        if DCFModalComponent.presentedModals[viewId] != nil {
            completion()
            return
        }
        
        // Create modal content view controller
        let modalVC = DCFModalViewController()
        modalVC.modalProps = props
        modalVC.sourceView = view
        modalVC.viewId = viewId
        
        // ✅ FIX 1: Load modal view and prepare content BEFORE presenting
        modalVC.loadViewIfNeeded()
        
        // ✅ CRITICAL FIX: Look for children in placeholder view for reopen scenario
        let existingChildren = view.subviews
        
        // 🚨 CRITICAL DEBUG: Let's check all known placeholders for this viewId
        
        // Check if we have any stored children anywhere
        var totalChildrenFound = 0
        for (id, modal) in DCFModalComponent.presentedModals {
            let modalChildren = modal.view.subviews.filter { $0.tag != 999 && $0.tag != 998 }
            if !modalChildren.isEmpty {
                totalChildrenFound += modalChildren.count
            }
        }
        
        if !existingChildren.isEmpty {
            // Create a copy of the children array before modifying
            let childrenCopy = Array(existingChildren)
            let component = DCFModalComponent()
            component.addChildrenToModalContent(modalVC: modalVC, childViews: childrenCopy)
        } else {
        }
        
        // Store reference to presented modal BEFORE presentation
        DCFModalComponent.presentedModals[viewId] = modalVC
        
        // Configure modal presentation style
        if #available(iOS 15.0, *) {
            modalVC.modalPresentationStyle = .pageSheet
            
            // Configure sheet presentation controller with detents
            if let sheet = modalVC.sheetPresentationController {
                let component = DCFModalComponent()
                component.configureSheetDetents(sheet: sheet, modalVC: modalVC, props: props)
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
            
            topViewController.present(modalVC, animated: true) {
                propagateEvent(on: view, eventName: "onShow", data: [:])
                completion()
            }
        } else {
            // Remove from tracking if presentation failed
            DCFModalComponent.presentedModals.removeValue(forKey: viewId)
            completion()
        }
    }
    
    /// Perform the actual modal dismissal (extracted from dismissModal)
    static func performModalDismissal(from view: UIView, viewId: String, completion: @escaping () -> Void) {
        if let modalVC = DCFModalComponent.presentedModals[viewId] {
            
            // ✅ SMOOTH UX FIX: Keep children in modal during dismissal animation
            // Don't move children here - let them stay visible during the close animation
            // The children will be moved in the dismissal completion block
            
            modalVC.dismiss(animated: true) {
                
                // ✅ NOW move children back to placeholder AFTER modal is fully dismissed
                let modalChildren = modalVC.view.subviews.filter { $0.tag != 999 && $0.tag != 998 }
                if !modalChildren.isEmpty {
                    modalChildren.forEach { child in
                        child.removeFromSuperview()
                        view.addSubview(child)
                        // Hide children when moved back to placeholder (main UI)
                        child.isHidden = true
                        child.alpha = 0.0
                    }
                }
                
                propagateEvent(on: view, eventName: "onDismiss", data: [:])
                completion()
            }
            
            // Remove from tracking
            DCFModalComponent.presentedModals.removeValue(forKey: viewId)
        } else if let topViewController = getTopViewController(),
                  topViewController.presentedViewController != nil {
            topViewController.dismiss(animated: true) {
                propagateEvent(on: view, eventName: "onDismiss", data: [:])
                completion()
            }
        } else {
            completion()
        }
    }
    
    /// Get the top view controller (made static for queue operations)
    static func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topController = window.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        return topController
    }
}

// MARK: - Modal View Controller

class DCFModalViewController: UIViewController, UISheetPresentationControllerDelegate {
    var modalProps: [String: Any] = [:]
    weak var sourceView: UIView?
    var viewId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupModalContent()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // ✅ FIX 2: Ensure children are properly sized when modal bounds change
        let contentChildren = view.subviews.filter { $0.tag != 999 && $0.tag != 998 }
        
        if !contentChildren.isEmpty {
            
            // Calculate the available content area - give abstraction layer full control
            let contentFrame = view.bounds
            
            // Update child frames to match new modal size
            if contentChildren.count == 1, let childView = contentChildren.first {
                // Single child fills entire content area
                childView.frame = contentFrame
                
                // Force Yoga layout update
                childView.setNeedsLayout()
                childView.layoutIfNeeded()
            } else {
                // Multiple children: recalculate positions
                var currentY: CGFloat = contentFrame.minY
                
                for (index, childView) in contentChildren.enumerated() {
                    let childHeight = childView.frame.height
                    
                    let childFrame = CGRect(
                        x: contentFrame.minX,
                        y: currentY,
                        width: contentFrame.width,
                        height: childHeight
                    )
                    
                    childView.frame = childFrame
                    
                    // Force Yoga layout update
                    childView.setNeedsLayout()
                    childView.layoutIfNeeded()
                    
                    currentY += childHeight
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // ✅ CRITICAL FIX: Only move children if modal is ACTUALLY being dismissed, not just hiding
        // isBeingDismissed is only true when the modal is truly being removed, not during drag gestures
        if isBeingDismissed {
            // Don't move children here - let presentationControllerDidDismiss handle it
            // This prevents duplicate child movement
        } else {
        }
    }
    
    // MARK: - UISheetPresentationControllerDelegate
    
    @available(iOS 13.5, *)
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        // ✅ Allow the user to start dragging to dismiss
        return true
    }
    
    @available(iOS 13.5, *)
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        // ✅ This is called when the user STARTS the dismiss gesture (dragging down)
        // Do NOT move children here - user might change their mind
        
        // ✅ ENSURE children stay visible during drag gesture
        ensureChildrenStayVisible()
    }
    
    @available(iOS 13.5, *)
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // ✅ This is called when the modal is ACTUALLY dismissed (user completed the gesture)
        
        // Move children back to placeholder view only when actually dismissed
        if let sourceView = sourceView {
            let modalChildren = view.subviews.filter { $0.tag != 999 && $0.tag != 998 }
            
            
            if !modalChildren.isEmpty {
                
                // ✅ CRITICAL FIX: Don't clear existing children from placeholder!
                // Other modals might have their children stored there
                // Just add back children from this dismissed modal
                modalChildren.forEach { child in
                    child.removeFromSuperview()
                    sourceView.addSubview(child)
                    // ✅ CRITICAL: Hide children when moved back to placeholder (main UI)
                    child.isHidden = true
                    child.alpha = 0.0
                }
                
            } else {
            }
            
            propagateEvent(on: sourceView, eventName: "onDismiss", data: [:])
        } else {
        }
        
        // Remove from tracking
        if let viewId = viewId {
            DCFModalComponent.presentedModals.removeValue(forKey: viewId)
        }
    }
    
    @available(iOS 13.5, *)
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        // ✅ This is called when user tries to dismiss but it's prevented
    }
    
    // ✅ Helper method to ensure children stay visible during drag gestures
    private func ensureChildrenStayVisible() {
        // Make sure all children are still in the modal view and visible
        let modalChildren = view.subviews.filter { $0.tag != 999 && $0.tag != 998 }
        
        
        // If no children in modal but we expect them, try to restore from tracking
        if modalChildren.isEmpty, let viewId = viewId, let sourceView = sourceView {
            let placeholderChildren = sourceView.subviews
            
            if !placeholderChildren.isEmpty {
                
                // Move children back to modal during drag recovery
                placeholderChildren.forEach { child in
                    child.removeFromSuperview()
                    view.addSubview(child)
                }
                
                // Re-apply layout to restored children
                if let modalVC = DCFModalComponent.presentedModals[viewId] as? DCFModalViewController {
                    // Re-trigger the children positioning
                    DispatchQueue.main.async {
                        // Trigger layout update for restored children
                        self.view.setNeedsLayout()
                        self.view.layoutIfNeeded()
                    }
                }
            }
        } else {
            // Children exist, just ensure they're visible
            for child in modalChildren {
                child.isHidden = false
                child.alpha = 1.0
                
                // Ensure child is still properly positioned
                if child.superview != view {
                    child.removeFromSuperview()
                    view.addSubview(child)
                }
            }
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Debug view hierarchy to find problematic overlays
        DispatchQueue.main.async {
            self.debugViewHierarchy()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // ✅ Only handle final cleanup if actually dismissed
        if isBeingDismissed {
        } else {
            
            // ✅ IMPORTANT: If modal reappears after drag, ensure children are still there
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !self.isBeingDismissed && self.view.window != nil {
                    self.ensureChildrenStayVisible()
                }
            }
        }
    }
    
    private func debugViewHierarchy() {
        debugPrintViewHierarchy(view: self.view, level: 0)
        
        // Look for problematic shadow or overlay views
        findAndFixProblematicViews(in: self.view)
    }
    
    private func debugPrintViewHierarchy(view: UIView, level: Int) {
        let indent = String(repeating: "  ", count: level)
        
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
                
                // Try disabling user interaction on problematic views
                if subview.isUserInteractionEnabled {
                    subview.isUserInteractionEnabled = false
                }
            }
            
            findAndFixProblematicViews(in: subview)
        }
    }
    
    private func setupModalContent() {
        view.backgroundColor = UIColor.systemBackground
        
        // Configure corner radius for the modal view
        var cornerRadius: CGFloat = 16.0 // Default value
        if let radius = modalProps["cornerRadius"] as? CGFloat {
            cornerRadius = radius
        } else if let radius = modalProps["cornerRadius"] as? Double {
            cornerRadius = CGFloat(radius)
        } else if let radius = modalProps["cornerRadius"] as? Int {
            cornerRadius = CGFloat(radius)
        } else if let radius = modalProps["cornerRadius"] as? NSNumber {
            cornerRadius = CGFloat(radius.doubleValue)
        } else {
        }
        
        // ✅ FIX: Apply corner radius to both the view and sheet (if applicable)
        view.layer.cornerRadius = cornerRadius
        view.layer.masksToBounds = true
        
        // ✅ For sheet presentations on iOS 16+, the preferredCornerRadius should already be set
        // in configureSheetDetents, but let's ensure it's applied here too as a fallback
        if #available(iOS 16.0, *), let sheet = sheetPresentationController {
            sheet.preferredCornerRadius = cornerRadius
        }
        
        // ✅ REMOVED: No automatic title rendering - let abstraction layer handle titles
        // The title prop is still available in modalProps for the abstraction layer to use
        // but we don't force any specific title rendering or safe area constraints
        
        // Propagate onOpen event
        if let sourceView = sourceView {
            propagateEvent(on: sourceView, eventName: "onOpen", data: [:])
        }
    }
}
