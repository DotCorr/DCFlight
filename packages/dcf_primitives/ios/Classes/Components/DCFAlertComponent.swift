/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

private struct AssociatedKeys {
    static var sourceView = "sourceView"
}

class DCFAlertComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFAlertComponent()
    private static var presentedAlerts = NSMapTable<UIView, UIAlertController>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let containerView = UIView()
        
        updateView(containerView, withProps: props)
        containerView.applyStyles(props: props)
        
        return containerView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        let visible = props["visible"] as? Bool ?? false
        
        if visible {
            if DCFAlertComponent.presentedAlerts.object(forKey: view) == nil {
                presentAlert(from: view, props: props)
            }
        } else {
            if let existingAlert = DCFAlertComponent.presentedAlerts.object(forKey: view) {
                existingAlert.dismiss(animated: true) {
                    DCFAlertComponent.presentedAlerts.removeObject(forKey: view)
                }
            }
        }
        
        view.applyStyles(props: props)
        return true
    }
    
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
    }
    
    
    
    private func presentAlert(from view: UIView, props: [String: Any]) {
        var title: String?
        var message: String?
        
        if let alertContent = props["alertContent"] as? [String: Any] {
            title = alertContent["title"] as? String
            message = alertContent["message"] as? String
        }
        
        if title == nil {
            title = props["title"] as? String
        }
        if message == nil {
            message = props["message"] as? String
        }
        
        let alertStyle = parseAlertStyle(props["style"] as? String)
        let dismissible = props["dismissible"] as? Bool ?? true
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: alertStyle)
        
        if let textFields = props["textFields"] as? [[String: Any]] {
            for (index, textFieldProps) in textFields.enumerated() {
                alertController.addTextField { textField in
                    self.configureTextField(textField, with: textFieldProps, sourceView: view, fieldIndex: index)
                }
            }
            
            DispatchQueue.main.async {
                self.resizeAlertForTextFields(alertController, textFieldCount: textFields.count)
            }
        }
        
        if let actions = props["actions"] as? [[String: Any]] {
            for actionProps in actions {
                let action = createAlertAction(actionProps: actionProps, sourceView: view, alertController: alertController)
                alertController.addAction(action)
            }
        } else {
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                self.handleActionPress(on: view, handler: "ok", buttonIndex: 0, title: "OK", textFields: alertController.textFields)
            }
            alertController.addAction(okAction)
        }
        
        if !dismissible {
            alertController.isModalInPresentation = true
        }
        
        if alertStyle == .actionSheet {
            if let popover = alertController.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = view.bounds
                
                if let arrowDirection = props["popoverArrowDirection"] as? String {
                    popover.permittedArrowDirections = parseArrowDirection(arrowDirection)
                }
            }
        }
        
        if let topViewController = getTopViewController() {
            DCFAlertComponent.presentedAlerts.setObject(alertController, forKey: view)
            
            let dismissHandler: (() -> Void) = {
                DCFAlertComponent.presentedAlerts.removeObject(forKey: view)
                propagateEvent(on: view, eventName: "onDismiss", data: [:])
            }
            
            if #available(iOS 13.0, *), alertStyle == .actionSheet {
                alertController.presentationController?.delegate = AlertPresentationDelegate(dismissHandler: dismissHandler)
            }
            
            topViewController.present(alertController, animated: true) {
                propagateEvent(on: view, eventName: "onShow", data: [:])
            }
        }
    }
    
    
    private func configureTextField(_ textField: UITextField, with props: [String: Any], sourceView: UIView, fieldIndex: Int) {
        objc_setAssociatedObject(textField, &AssociatedKeys.sourceView, sourceView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        if let placeholder = props["placeholder"] as? String {
            textField.placeholder = placeholder
        }
        
        if let defaultValue = props["defaultValue"] as? String {
            textField.text = defaultValue
        }
        
        if let secureTextEntry = props["secureTextEntry"] as? Bool {
            textField.isSecureTextEntry = secureTextEntry
        }
        
        if let keyboardType = props["keyboardType"] as? String {
            textField.keyboardType = parseKeyboardType(keyboardType)
        }
        
        if let autocorrectionType = props["autocorrectionType"] as? String {
            textField.autocorrectionType = parseAutocorrectionType(autocorrectionType)
        }
        
        if let autocapitalizationType = props["autocapitalizationType"] as? String {
            textField.autocapitalizationType = parseAutocapitalizationType(autocapitalizationType)
        }
        
        if let returnKeyType = props["returnKeyType"] as? String {
            textField.returnKeyType = parseReturnKeyType(returnKeyType)
        }
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        textField.tag = fieldIndex
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        guard let sourceView = objc_getAssociatedObject(textField, &AssociatedKeys.sourceView) as? UIView else {
            return
        }
        
        let eventData: [String: Any] = [
            "fieldIndex": textField.tag,
            "text": textField.text ?? "",
            "value": textField.text ?? ""
        ]
        
        propagateEvent(on: sourceView, eventName: "onTextFieldChange", data: eventData)
    }
    
    private func parseKeyboardType(_ typeString: String) -> UIKeyboardType {
        switch typeString.lowercased() {
        case "defaulttype":
            return .default
        case "asciicapable":
            return .asciiCapable
        case "numbersandpunctuation":
            return .numbersAndPunctuation
        case "url":
            return .URL
        case "numberpad":
            return .numberPad
        case "phonepad":
            return .phonePad
        case "namephonepad":
            return .namePhonePad
        case "emailaddress":
            return .emailAddress
        case "decimalpad":
            return .decimalPad
        case "twitter":
            return .twitter
        case "websearch":
            return .webSearch
        case "asciicapablenumberpad":
            return .asciiCapableNumberPad
        case "default":
            return .default
        case "asciiCapable":
            return .asciiCapable
        case "numbersAndPunctuation":
            return .numbersAndPunctuation
        case "numberPad":
            return .numberPad
        case "phonePad":
            return .phonePad
        case "namePhonePad":
            return .namePhonePad
        case "emailAddress":
            return .emailAddress
        case "decimalPad":
            return .decimalPad
        case "webSearch":
            return .webSearch
        default:
            return .default
        }
    }
    
    private func parseAutocapitalizationType(_ typeString: String) -> UITextAutocapitalizationType {
        switch typeString.lowercased() {
        case "none":
            return .none
        case "words":
            return .words
        case "sentences":
            return .sentences
        case "allcharacters":
            return .allCharacters
        default:
            return .sentences
        }
    }
    
    private func parseAutocorrectionType(_ typeString: String) -> UITextAutocorrectionType {
        switch typeString.lowercased() {
        case "default":
            return .default
        case "no":
            return .no
        case "yes":
            return .yes
        default:
            return .default
        }
    }
    
    private func parseReturnKeyType(_ typeString: String) -> UIReturnKeyType {
        switch typeString.lowercased() {
        case "defaultreturn":
            return .default
        case "go":
            return .go
        case "google":
            return .google
        case "join":
            return .join
        case "next":
            return .next
        case "route":
            return .route
        case "search":
            return .search
        case "send":
            return .send
        case "yahoo":
            return .yahoo
        case "done":
            return .done
        case "emergencycall":
            return .emergencyCall
        case "continue_":
            return .continue
        default:
            return .default
        }
    }
    
    private func parseTextContentType(_ typeString: String) -> UITextContentType? {
        switch typeString.lowercased() {
        case "none":
            return nil
        case "addresscity":
            return .addressCity
        case "addresscityandstate":
            return .addressCityAndState
        case "addressstate":
            return .addressState
        case "countryname":
            return .countryName
        case "creditcardnumber":
            return .creditCardNumber
        case "emailaddress":
            return .emailAddress
        case "familyname":
            return .familyName
        case "fullstreetaddress":
            return .fullStreetAddress
        case "givenname":
            return .givenName
        case "jobtitle":
            return .jobTitle
        case "location":
            return .location
        case "middlename":
            return .middleName
        case "name":
            return .name
        case "nameprefix":
            return .namePrefix
        case "namesuffix":
            return .nameSuffix
        case "nickname":
            return .nickname
        case "organizationname":
            return .organizationName
        case "postalcode":
            return .postalCode
        case "streetaddressline1":
            return .streetAddressLine1
        case "streetaddressline2":
            return .streetAddressLine2
        case "sublocality":
            return .sublocality
        case "telephonenumber":
            return .telephoneNumber
        case "url":
            return .URL
        case "username":
            return .username
        case "password":
            return .password
        case "newpassword":
            return .newPassword
        case "onetimecode":
            return .oneTimeCode
        default:
            return nil
        }
    }
    
    private func parseColor(_ colorString: String) -> UIColor {
        let hex = colorString.hasPrefix("#") ? String(colorString.dropFirst()) : colorString
        
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    private func parseTextAlignment(_ alignString: String) -> NSTextAlignment {
        switch alignString.lowercased() {
        case "left":
            return .left
        case "center":
            return .center
        case "right":
            return .right
        case "justified":
            return .justified
        case "natural":
            return .natural
        default:
            return .natural
        }
    }
    
    private func parseFontWeight(_ weightString: String, size: CGFloat) -> UIFont {
        switch weightString.lowercased() {
        case "ultralight":
            return .systemFont(ofSize: size, weight: .ultraLight)
        case "thin":
            return .systemFont(ofSize: size, weight: .thin)
        case "light":
            return .systemFont(ofSize: size, weight: .light)
        case "regular":
            return .systemFont(ofSize: size, weight: .regular)
        case "medium":
            return .systemFont(ofSize: size, weight: .medium)
        case "semibold":
            return .systemFont(ofSize: size, weight: .semibold)
        case "bold":
            return .systemFont(ofSize: size, weight: .bold)
        case "heavy":
            return .systemFont(ofSize: size, weight: .heavy)
        case "black":
            return .systemFont(ofSize: size, weight: .black)
        default:
            return .systemFont(ofSize: size, weight: .regular)
        }
    }
    
    private func handleActionPress(on view: UIView, handler: String, buttonIndex: Int, title: String, textFields: [UITextField]?) {
        var eventData: [String: Any] = [
            "handler": handler,
            "action": handler,
            "buttonIndex": buttonIndex,
            "title": title
        ]
        
        if let textFields = textFields, !textFields.isEmpty {
            let textFieldValues = textFields.map { $0.text ?? "" }
            eventData["textFieldValues"] = textFieldValues
        }
        
        DispatchQueue.main.async {
            DCFAlertComponent.presentedAlerts.removeObject(forKey: view)
        }
        
        propagateEvent(on: view, eventName: "onActionPress", data: eventData)
    }
    
    private func createAlertAction(actionProps: [String: Any], sourceView: UIView, alertController: UIAlertController) -> UIAlertAction {
        let title = actionProps["title"] as? String ?? "Action"
        let style = parseActionStyle(actionProps["style"] as? String)
        let handler = actionProps["handler"] as? String ?? actionProps["id"] as? String ?? title.lowercased()
        let buttonIndex = actionProps["buttonIndex"] as? Int ?? 0
        
        let action = UIAlertAction(title: title, style: style) { _ in
            self.handleActionPress(on: sourceView, handler: handler, buttonIndex: buttonIndex, title: title, textFields: alertController.textFields)
        }
        
        if let enabled = actionProps["enabled"] as? Bool {
            action.isEnabled = enabled
        }
        
        return action
    }
    
    private func parseAlertStyle(_ styleString: String?) -> UIAlertController.Style {
        switch styleString?.lowercased() {
        case "actionsheet", "action_sheet":
            return .actionSheet
        case "alert", "dialog":
            return .alert
        default:
            return .alert
        }
    }
    
    private func parseActionStyle(_ styleString: String?) -> UIAlertAction.Style {
        switch styleString?.lowercased() {
        case "destructive", "danger":
            return .destructive
        case "cancel":
            return .cancel
        case "default", "normal":
            return .default
        default:
            return .default
        }
    }
    
    private func parseArrowDirection(_ directionString: String) -> UIPopoverArrowDirection {
        switch directionString.lowercased() {
        case "up":
            return .up
        case "down":
            return .down
        case "left":
            return .left
        case "right":
            return .right
        case "any":
            return .any
        default:
            return .any
        }
    }
    
    private func getTopViewController() -> UIViewController? {
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


extension DCFAlertComponent {
    
    static func showSimpleAlert(title: String?, message: String?, from view: UIView) {
        let props: [String: Any] = [
            "visible": true,
            "title": title ?? "",
            "message": message ?? "",
            "alertStyle": "alert"
        ]
        
        DCFAlertComponent.sharedInstance.presentAlert(from: view, props: props)
    }
    
    static func showConfirmationAlert(title: String?, message: String?, from view: UIView, onConfirm: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        let props: [String: Any] = [
            "visible": true,
            "title": title ?? "",
            "message": message ?? "",
            "alertStyle": "alert",
            "actions": [
                [
                    "title": "Cancel",
                    "style": "cancel",
                    "id": "cancel",
                    "buttonIndex": 0
                ],
                [
                    "title": "Confirm",
                    "style": "default",
                    "id": "confirm",
                    "buttonIndex": 1
                ]
            ]
        ]
        
        DCFAlertComponent.sharedInstance.presentAlert(from: view, props: props)
    }
}


class DCFAlertWrapper: NSObject {
    weak var alertController: UIAlertController?
    weak var sourceView: UIView?
    
    init(alertController: UIAlertController, sourceView: UIView) {
        self.alertController = alertController
        self.sourceView = sourceView
        super.init()
        
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(alertWillDisappear), 
            name: UIApplication.willResignActiveNotification, 
            object: nil
        )
    }
    
    @objc private func alertWillDisappear() {
        if let alert = alertController, alert.isBeingDismissed {
            if let view = sourceView {
                propagateEvent(on: view, eventName: "onDismiss", data: [:])
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}


extension DCFAlertComponent {
    private func presentCustomAlert(from view: UIView, props: [String: Any], children: [UIView]) {
        let title = props["title"] as? String
        let message = props["message"] as? String
        let alertStyle = parseAlertStyle(props["style"] as? String)
        
        let customAlertVC = UIViewController()
        customAlertVC.modalPresentationStyle = alertStyle == .actionSheet ? .popover : .overFullScreen
        customAlertVC.modalTransitionStyle = .crossDissolve
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        customAlertVC.view.addSubview(backgroundView)
        
        let alertContainer = UIView()
        alertContainer.layer.cornerRadius = 12
        alertContainer.layer.shadowColor = UIColor.black.cgColor
        alertContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        alertContainer.layer.shadowOpacity = 0.25
        alertContainer.layer.shadowRadius = 8
        alertContainer.translatesAutoresizingMaskIntoConstraints = false
        customAlertVC.view.addSubview(alertContainer)
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: customAlertVC.view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: customAlertVC.view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: customAlertVC.view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: customAlertVC.view.bottomAnchor),
            
            alertContainer.centerXAnchor.constraint(equalTo: customAlertVC.view.centerXAnchor),
            alertContainer.centerYAnchor.constraint(equalTo: customAlertVC.view.centerYAnchor),
            alertContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            alertContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 250)
        ])
        
        var currentY: CGFloat = 20
        if let title = title, !title.isEmpty {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 0
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            alertContainer.addSubview(titleLabel)
            
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: alertContainer.topAnchor, constant: currentY),
                titleLabel.leadingAnchor.constraint(equalTo: alertContainer.leadingAnchor, constant: 16),
                titleLabel.trailingAnchor.constraint(equalTo: alertContainer.trailingAnchor, constant: -16)
            ])
            currentY += 40
        }
        
        if let message = message, !message.isEmpty {
            let messageLabel = UILabel()
            messageLabel.text = message
            messageLabel.font = UIFont.systemFont(ofSize: 14)
            messageLabel.textAlignment = .center
            messageLabel.numberOfLines = 0
            messageLabel.translatesAutoresizingMaskIntoConstraints = false
            alertContainer.addSubview(messageLabel)
            
            NSLayoutConstraint.activate([
                messageLabel.topAnchor.constraint(equalTo: alertContainer.topAnchor, constant: currentY),
                messageLabel.leadingAnchor.constraint(equalTo: alertContainer.leadingAnchor, constant: 16),
                messageLabel.trailingAnchor.constraint(equalTo: alertContainer.trailingAnchor, constant: -16)
            ])
            currentY += 40
        }
        
        var lastChildView: UIView?
        for child in children {
            child.isHidden = false // Show the child in alert
            child.translatesAutoresizingMaskIntoConstraints = false
            alertContainer.addSubview(child)
            
            if let lastChild = lastChildView {
                NSLayoutConstraint.activate([
                    child.topAnchor.constraint(equalTo: lastChild.bottomAnchor, constant: 8),
                    child.leadingAnchor.constraint(equalTo: alertContainer.leadingAnchor, constant: 16),
                    child.trailingAnchor.constraint(equalTo: alertContainer.trailingAnchor, constant: -16)
                ])
            } else {
                NSLayoutConstraint.activate([
                    child.topAnchor.constraint(equalTo: alertContainer.topAnchor, constant: currentY),
                    child.leadingAnchor.constraint(equalTo: alertContainer.leadingAnchor, constant: 16),
                    child.trailingAnchor.constraint(equalTo: alertContainer.trailingAnchor, constant: -16)
                ])
            }
            lastChildView = child
        }
        
        let actionsStackView = UIStackView()
        actionsStackView.axis = alertStyle == .actionSheet ? .vertical : .horizontal
        actionsStackView.distribution = .fillEqually
        actionsStackView.spacing = 8
        actionsStackView.translatesAutoresizingMaskIntoConstraints = false
        alertContainer.addSubview(actionsStackView)
        
        if let actions = props["actions"] as? [[String: Any]] {
            for actionProps in actions {
                let button = createCustomAlertButton(actionProps: actionProps, sourceView: view, alertVC: customAlertVC)
                actionsStackView.addArrangedSubview(button)
            }
        } else {
            let okButton = createDefaultOKButton(sourceView: view, alertVC: customAlertVC)
            actionsStackView.addArrangedSubview(okButton)
        }
        
        NSLayoutConstraint.activate([
            actionsStackView.topAnchor.constraint(equalTo: lastChildView?.bottomAnchor ?? alertContainer.topAnchor, constant: 20),
            actionsStackView.leadingAnchor.constraint(equalTo: alertContainer.leadingAnchor, constant: 16),
            actionsStackView.trailingAnchor.constraint(equalTo: alertContainer.trailingAnchor, constant: -16),
            actionsStackView.bottomAnchor.constraint(equalTo: alertContainer.bottomAnchor, constant: -16),
            actionsStackView.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        if let topViewController = getTopViewController() {
            topViewController.present(customAlertVC, animated: true) {
                propagateEvent(on: view, eventName: "onShow", data: [:])
            }
        } else {
        }
    }
    
    private func createCustomAlertButton(actionProps: [String: Any], sourceView: UIView, alertVC: UIViewController) -> UIButton {
        let title = actionProps["title"] as? String ?? "Action"
        let style = actionProps["style"] as? String ?? "default"
        let handler = actionProps["handler"] as? String ?? actionProps["id"] as? String ?? title.lowercased()
        let buttonIndex = actionProps["buttonIndex"] as? Int ?? 0
        
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: style == "cancel" ? .medium : .regular)
        
        switch style.lowercased() {
        case "destructive", "danger":
            button.setTitleColor(.systemRed, for: .normal)
        case "cancel":
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        default:
            break
        }
        
        button.layer.cornerRadius = 8
        
        if #available(iOS 14.0, *) {
            button.addAction(UIAction { _ in
                alertVC.dismiss(animated: true) {
                    propagateEvent(on: sourceView, eventName: "onActionPress", data: [
                        "handler": handler,
                        "action": handler,
                        "buttonIndex": buttonIndex,
                        "title": title
                    ])
                }
            }, for: .touchUpInside)
        } else {
        }
        
        return button
    }
    
    private func createDefaultOKButton(sourceView: UIView, alertVC: UIViewController) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("OK", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.layer.cornerRadius = 8
        
        if #available(iOS 14.0, *) {
            button.addAction(UIAction { _ in
                alertVC.dismiss(animated: true) {
                    propagateEvent(on: sourceView, eventName: "onActionPress", data: [
                        "handler": "ok",
                        "action": "ok",
                        "buttonIndex": 0
                    ])
                }
            }, for: .touchUpInside)
        } else {
        }
        
        return button
    }
    
    
    
    private func resizeAlertForTextFields(_ alertController: UIAlertController, textFieldCount: Int) {
        let textFieldHeight: CGFloat = 30.0 // Approximate height per text field
        let additionalHeight = CGFloat(textFieldCount) * textFieldHeight + 20.0 // Extra padding
        
        let screenHeight = UIScreen.main.bounds.height
        let maxAlertHeight = screenHeight * 0.8 // Max 80% of screen height
        
        let baseAlertHeight: CGFloat = 150.0 // Base alert height
        let desiredHeight = min(baseAlertHeight + additionalHeight, maxAlertHeight)
        
        let heightConstraint = NSLayoutConstraint(
            item: alertController.view!,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1,
            constant: desiredHeight
        )
        alertController.view.addConstraint(heightConstraint)
        
    }
    
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

@available(iOS 13.0, *)
private class AlertPresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    let dismissHandler: () -> Void
    
    init(dismissHandler: @escaping () -> Void) {
        self.dismissHandler = dismissHandler
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        dismissHandler()
    }
}
