# Presentable Components Guide

## What Are Presentable Components?

Presentable components (modals, sheets, popups, alerts) hide their children in the main UI and present them in a separate presentation layer.

## Key Principles

1. **Hide children in placeholder view** - Children are hidden in main UI
2. **Present children elsewhere** - Children are shown in modal/sheet/popup
3. **Control visibility with `visible` prop** - Boolean property controls presentation
4. **Use `display: none` when hidden** - Hide placeholder completely
5. **Handle setChildren properly** - Move children between placeholder and presentation

## Modal Component Pattern

### Dart Implementation
```dart
class DCFModal extends StatelessComponent {
  final bool visible;
  final List<DCFComponentNode> children;
  // ... other modal props
  
  @override
  DCFComponentNode render() {
    Map<String, dynamic> props = {
      'visible': visible,
      // ... other props
    };
    
    // CRITICAL: Control display based on visibility
    props['display'] = visible ? 'flex' : 'none';
    
    return DCFElement(
      type: 'Modal',
      props: props,
      children: children, // Children hidden in main UI, shown in modal
    );
  }
}
```

### Native Implementation
```swift
class DCFModalComponent: NSObject, DCFComponent {
    static var presentedModals: [String: UIViewController] = [:]
    
    func createView(props: [String: Any]) -> UIView {
        // Create placeholder view (hidden in main UI)
        let view = UIView()
        view.isHidden = true
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = false
        
        updateView(view, withProps: props)
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        let viewId = String(view.hash)
        let isVisible = props["visible"] as? Bool ?? false
        
        if isVisible {
            presentModal(from: view, props: props, viewId: viewId)
        } else {
            dismissModal(viewId: viewId)
        }
        
        return true
    }
    
    // REQUIRED: Handle children movement
    func setChildren(_ view: UIView, childViews: [UIView], viewId: String) -> Bool {
        // Store children in placeholder but keep them hidden
        view.subviews.forEach { $0.removeFromSuperview() }
        childViews.forEach { childView in
            view.addSubview(childView)
            childView.isHidden = true  // Hidden in main UI
            childView.alpha = 0.0
        }
        
        // If modal is presented, move children to modal and show them
        if let modalVC = DCFModalComponent.presentedModals[viewId] {
            moveChildrenToModal(modalVC: modalVC, childViews: childViews)
        }
        
        return true
    }
    
    private func presentModal(from view: UIView, props: [String: Any], viewId: String) {
        // Don't present if already presented
        guard DCFModalComponent.presentedModals[viewId] == nil else { return }
        
        let modalVC = UIViewController()
        modalVC.view.backgroundColor = UIColor.systemBackground
        
        // Move children from placeholder to modal
        let existingChildren = view.subviews
        moveChildrenToModal(modalVC: modalVC, childViews: existingChildren)
        
        // Store reference
        DCFModalComponent.presentedModals[viewId] = modalVC
        
        // Present modal
        if let topVC = getTopViewController() {
            topVC.present(modalVC, animated: true) {
                propagateEvent(on: view, eventName: "onShow", data: [:])
            }
        }
    }
    
    private func dismissModal(viewId: String) {
        guard let modalVC = DCFModalComponent.presentedModals[viewId] else { return }
        
        modalVC.dismiss(animated: true) {
            // Move children back to placeholder after dismissal
            let modalChildren = modalVC.view.subviews
            // Handle children movement back to placeholder
            
            DCFModalComponent.presentedModals.removeValue(forKey: viewId)
            propagateEvent(on: view, eventName: "onDismiss", data: [:])
        }
    }
    
    private func moveChildrenToModal(modalVC: UIViewController, childViews: [UIView]) {
        childViews.forEach { child in
            child.removeFromSuperview()
            modalVC.view.addSubview(child)
            child.isHidden = false  // Visible in modal
            child.alpha = 1.0
            
            // Position child to fill modal
            child.frame = modalVC.view.bounds
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return nil }
        
        var topController = window.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        return topController
    }
}
```

## Sheet Component Pattern

### Dart Implementation
```dart
class DCFSheet extends StatelessComponent {
  final bool visible;
  final List<String>? detents;  // ["small", "medium", "large"]
  final bool showDragIndicator;
  final List<DCFComponentNode> children;
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'Sheet',
      props: {
        'visible': visible,
        'detents': detents,
        'showDragIndicator': showDragIndicator,
        'display': visible ? 'flex' : 'none',
      },
      children: children,
    );
  }
}
```

### Native Sheet Implementation
```swift
class DCFSheetComponent: NSObject, DCFComponent {
    static var presentedSheets: [String: UIViewController] = [:]
    
    func createView(props: [String: Any]) -> UIView {
        let view = UIView()
        view.isHidden = true
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        let viewId = String(view.hash)
        let isVisible = props["visible"] as? Bool ?? false
        
        if isVisible {
            presentSheet(from: view, props: props, viewId: viewId)
        } else {
            dismissSheet(viewId: viewId)
        }
        
        return true
    }
    
    private func presentSheet(from view: UIView, props: [String: Any], viewId: String) {
        guard DCFSheetComponent.presentedSheets[viewId] == nil else { return }
        
        let sheetVC = UIViewController()
        
        // Configure sheet presentation (iOS 15+)
        if #available(iOS 15.0, *) {
            sheetVC.modalPresentationStyle = .pageSheet
            
            if let sheet = sheetVC.sheetPresentationController {
                // Configure detents
                var detents: [UISheetPresentationController.Detent] = []
                if let detentArray = props["detents"] as? [String] {
                    for detentString in detentArray {
                        switch detentString.lowercased() {
                        case "small":
                            if #available(iOS 16.0, *) {
                                detents.append(.custom(identifier: .init("small")) { context in
                                    return context.maximumDetentValue * 0.3
                                })
                            }
                        case "medium":
                            detents.append(.medium())
                        case "large":
                            detents.append(.large())
                        default:
                            detents.append(.medium())
                        }
                    }
                } else {
                    detents = [.medium(), .large()]
                }
                
                sheet.detents = detents
                sheet.prefersGrabberVisible = props["showDragIndicator"] as? Bool ?? true
            }
        }
        
        DCFSheetComponent.presentedSheets[viewId] = sheetVC
        
        if let topVC = getTopViewController() {
            topVC.present(sheetVC, animated: true) {
                propagateEvent(on: view, eventName: "onShow", data: [:])
            }
        }
    }
    
    private func dismissSheet(viewId: String) {
        guard let sheetVC = DCFSheetComponent.presentedSheets[viewId] else { return }
        
        sheetVC.dismiss(animated: true) {
            DCFSheetComponent.presentedSheets.removeValue(forKey: viewId)
        }
    }
}
```

## Popup Component Pattern

### Dart Implementation
```dart
class DCFPopup extends StatelessComponent {
  final bool visible;
  final String? anchorPosition;  // "top", "bottom", "left", "right"
  final double? offsetX;
  final double? offsetY;
  final List<DCFComponentNode> children;
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'Popup',
      props: {
        'visible': visible,
        'anchorPosition': anchorPosition,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'display': visible ? 'flex' : 'none',
      },
      children: children,
    );
  }
}
```

### Native Popup Implementation
```swift
class DCFPopupComponent: NSObject, DCFComponent {
    static var presentedPopups: [String: UIView] = [:]
    
    func createView(props: [String: Any]) -> UIView {
        let view = UIView()
        view.isHidden = true
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        let viewId = String(view.hash)
        let isVisible = props["visible"] as? Bool ?? false
        
        if isVisible {
            showPopup(from: view, props: props, viewId: viewId)
        } else {
            hidePopup(viewId: viewId)
        }
        
        return true
    }
    
    private func showPopup(from view: UIView, props: [String: Any], viewId: String) {
        guard DCFPopupComponent.presentedPopups[viewId] == nil else { return }
        
        let popupView = UIView()
        popupView.backgroundColor = UIColor.systemBackground
        popupView.layer.cornerRadius = 8
        popupView.layer.shadowOpacity = 0.3
        popupView.layer.shadowRadius = 10
        
        // Add to window
        guard let window = UIApplication.shared.windows.first else { return }
        window.addSubview(popupView)
        
        // Position popup relative to anchor view
        positionPopup(popupView, relativeTo: view, props: props)
        
        DCFPopupComponent.presentedPopups[viewId] = popupView
        
        // Animate in
        popupView.alpha = 0
        popupView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3) {
            popupView.alpha = 1
            popupView.transform = CGAffineTransform.identity
        }
        
        propagateEvent(on: view, eventName: "onShow", data: [:])
    }
    
    private func hidePopup(viewId: String) {
        guard let popupView = DCFPopupComponent.presentedPopups[viewId] else { return }
        
        UIView.animate(withDuration: 0.2, animations: {
            popupView.alpha = 0
            popupView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            popupView.removeFromSuperview()
            DCFPopupComponent.presentedPopups.removeValue(forKey: viewId)
        }
    }
    
    private func positionPopup(_ popupView: UIView, relativeTo anchorView: UIView, props: [String: Any]) {
        let anchorPosition = props["anchorPosition"] as? String ?? "bottom"
        let offsetX = props["offsetX"] as? CGFloat ?? 0
        let offsetY = props["offsetY"] as? CGFloat ?? 0
        
        // Convert anchor view frame to window coordinates
        guard let window = UIApplication.shared.windows.first else { return }
        let anchorFrame = anchorView.superview?.convert(anchorView.frame, to: window) ?? anchorView.frame
        
        let popupSize = CGSize(width: 200, height: 100) // Default size
        
        var popupOrigin: CGPoint
        
        switch anchorPosition {
        case "top":
            popupOrigin = CGPoint(
                x: anchorFrame.midX - popupSize.width / 2 + offsetX,
                y: anchorFrame.minY - popupSize.height - 8 + offsetY
            )
        case "bottom":
            popupOrigin = CGPoint(
                x: anchorFrame.midX - popupSize.width / 2 + offsetX,
                y: anchorFrame.maxY + 8 + offsetY
            )
        case "left":
            popupOrigin = CGPoint(
                x: anchorFrame.minX - popupSize.width - 8 + offsetX,
                y: anchorFrame.midY - popupSize.height / 2 + offsetY
            )
        case "right":
            popupOrigin = CGPoint(
                x: anchorFrame.maxX + 8 + offsetX,
                y: anchorFrame.midY - popupSize.height / 2 + offsetY
            )
        default:
            popupOrigin = CGPoint(
                x: anchorFrame.midX - popupSize.width / 2 + offsetX,
                y: anchorFrame.maxY + 8 + offsetY
            )
        }
        
        popupView.frame = CGRect(origin: popupOrigin, size: popupSize)
    }
}
```

## Alert Component Pattern

### Dart Implementation
```dart
class DCFAlert extends StatelessComponent {
  final bool visible;
  final String? title;
  final String? message;
  final List<DCFAlertAction> actions;
  
  @override
  DCFComponentNode render() {
    return DCFElement(
      type: 'Alert',
      props: {
        'visible': visible,
        'title': title,
        'message': message,
        'actions': actions.map((action) => action.toMap()).toList(),
        'display': visible ? 'flex' : 'none',
      },
      children: const [], // Alerts don't typically have custom children
    );
  }
}

class DCFAlertAction {
  final String title;
  final String style; // "default", "cancel", "destructive"
  final Function()? onPress;
  
  DCFAlertAction({
    required this.title,
    this.style = "default",
    this.onPress,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'style': style,
    };
  }
}
```

### Native Alert Implementation
```swift
class DCFAlertComponent: NSObject, DCFComponent {
    static var presentedAlerts: [String: UIAlertController] = [:]
    
    func createView(props: [String: Any]) -> UIView {
        let view = UIView()
        view.isHidden = true
        return view
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        let viewId = String(view.hash)
        let isVisible = props["visible"] as? Bool ?? false
        
        if isVisible {
            showAlert(from: view, props: props, viewId: viewId)
        } else {
            dismissAlert(viewId: viewId)
        }
        
        return true
    }
    
    private func showAlert(from view: UIView, props: [String: Any], viewId: String) {
        guard DCFAlertComponent.presentedAlerts[viewId] == nil else { return }
        
        let title = props["title"] as? String
        let message = props["message"] as? String
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // Add actions
        if let actions = props["actions"] as? [[String: Any]] {
            for actionData in actions {
                let actionTitle = actionData["title"] as? String ?? "OK"
                let actionStyle = actionData["style"] as? String ?? "default"
                
                var uiActionStyle: UIAlertAction.Style = .default
                switch actionStyle {
                case "cancel":
                    uiActionStyle = .cancel
                case "destructive":
                    uiActionStyle = .destructive
                default:
                    uiActionStyle = .default
                }
                
                let action = UIAlertAction(title: actionTitle, style: uiActionStyle) { _ in
                    propagateEvent(on: view, eventName: "onActionPress", data: [
                        "actionTitle": actionTitle,
                        "actionStyle": actionStyle
                    ])
                }
                
                alertController.addAction(action)
            }
        } else {
            // Default OK action
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                propagateEvent(on: view, eventName: "onActionPress", data: [
                    "actionTitle": "OK",
                    "actionStyle": "default"
                ])
            }
            alertController.addAction(okAction)
        }
        
        DCFAlertComponent.presentedAlerts[viewId] = alertController
        
        if let topVC = getTopViewController() {
            topVC.present(alertController, animated: true) {
                propagateEvent(on: view, eventName: "onShow", data: [:])
            }
        }
    }
    
    private func dismissAlert(viewId: String) {
        guard let alertController = DCFAlertComponent.presentedAlerts[viewId] else { return }
        
        alertController.dismiss(animated: true) {
            DCFAlertComponent.presentedAlerts.removeValue(forKey: viewId)
        }
    }
}
```

## Best Practices for Presentable Components

### DO ✅
- Hide placeholder view with `isHidden = true`
- Set `display: none` when not visible
- Move children between placeholder and presentation layers
- Use static tracking dictionaries for presented components
- Handle proper cleanup on dismissal
- Propagate show/dismiss events

### DON'T ❌
- Show children in main UI for presentable components
- Forget to handle setChildren method
- Present multiple instances of same component
- Skip event propagation for lifecycle events
- Ignore proper cleanup on dismissal

---

**Presentable components are a core DCFlight pattern for overlays, modals, sheets, and popups.**
