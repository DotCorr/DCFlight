/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit
import Foundation
import dcflight

/// Custom UITextField that respects padding/insets for text layout.
/// The padding values are calculated on the Dart side (including border width inflation).
class DCFTextField: UITextField {
    var paddingInsets: UIEdgeInsets = .zero
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: paddingInsets)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: paddingInsets)
    }
    
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: paddingInsets)
    }
    
    // DCFView-like property mapping for borders
    // Since we can't inherit from both DCFView and UITextField, 
    // we handle the styling via the property mapper.
}

/// Custom UITextView that respects padding/insets for text layout
class DCFTextView: UITextView {
    // UITextView already has textContainerInset, so we just need to sync it
}

class DCFTextInputComponent: NSObject, DCFComponent, UITextFieldDelegate, UITextViewDelegate {
    private static let sharedInstance = DCFTextInputComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let isMultiline = props["multiline"] as? Bool ?? false
        
        let inputView: UIView
        if isMultiline {
            let textView = DCFTextView()
            textView.font = UIFont.systemFont(ofSize: 16)
            textView.delegate = self
            inputView = textView
        } else {
            let textField = DCFTextField()
            textField.font = UIFont.systemFont(ofSize: 16)
            textField.borderStyle = .none
            textField.delegate = self
            inputView = textField
        }
        
        updateView(inputView, withProps: props)
        return inputView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // 1. Apply standard styling (borders, background, etc.)
        // Since DCFTextField/TextView aren't DCFViews, the mapper will fall back 
        // to standard CALayer properties, which is fine for uniform borders.
        view.applyProperties(props: props)
        
        // 2. Extract inflated padding from props (set by Dart's StyleWrapperUtil)
        let pt = props["paddingTop"] as? CGFloat ?? props["paddingVertical"] as? CGFloat ?? props["padding"] as? CGFloat ?? 0
        let pb = props["paddingBottom"] as? CGFloat ?? props["paddingVertical"] as? CGFloat ?? props["padding"] as? CGFloat ?? 0
        let pl = props["paddingLeft"] as? CGFloat ?? props["paddingHorizontal"] as? CGFloat ?? props["padding"] as? CGFloat ?? 0
        let pr = props["paddingRight"] as? CGFloat ?? props["paddingHorizontal"] as? CGFloat ?? props["padding"] as? CGFloat ?? 0
        
        let insets = UIEdgeInsets(top: pt, left: pl, bottom: pb, right: pr)
        
        // 3. Update specific input properties
        if let textField = view as? DCFTextField {
            textField.paddingInsets = insets
            return updateTextField(textField, withProps: props)
        } else if let textView = view as? DCFTextView {
            textView.textContainerInset = insets
            return updateTextView(textView, withProps: props)
        }
        return false
    }
    
    private func updateTextField(_ textField: UITextField, withProps props: [String: Any]) -> Bool {
        if let value = props["value"] as? String {
            textField.text = value
        }
        
        if let placeholder = props["placeholder"] as? String {
            textField.placeholder = placeholder
        }
        
        if let keyboardType = props["keyboardType"] as? String {
            textField.keyboardType = mapKeyboardType(keyboardType)
        }
        
        if let returnKeyType = props["returnKeyType"] as? String {
            textField.returnKeyType = mapReturnKeyType(returnKeyType)
        }
        
        if let autoCapitalization = props["autoCapitalization"] as? String {
            textField.autocapitalizationType = mapAutoCapitalizationType(autoCapitalization)
        }
        
        if let secureTextEntry = props["secureTextEntry"] as? Bool {
            textField.isSecureTextEntry = secureTextEntry
        }
        
        if let autoCorrect = props["autoCorrect"] as? Bool {
            textField.autocorrectionType = autoCorrect ? .yes : .no
        }
        
        if let editable = props["editable"] as? Bool {
            textField.isEnabled = editable
        }
        
        if let maxLength = props["maxLength"] as? Int {
            objc_setAssociatedObject(textField, UnsafeRawPointer(bitPattern: "maxLength".hashValue)!, maxLength, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        return true
    }
    
    private func updateTextView(_ textView: UITextView, withProps props: [String: Any]) -> Bool {
        if let value = props["value"] as? String {
            textView.text = value
        }
        
        if let keyboardType = props["keyboardType"] as? String {
            textView.keyboardType = mapKeyboardType(keyboardType)
        }
        
        if let returnKeyType = props["returnKeyType"] as? String {
            textView.returnKeyType = mapReturnKeyType(returnKeyType)
        }
        
        if let autoCapitalization = props["autoCapitalization"] as? String {
            textView.autocapitalizationType = mapAutoCapitalizationType(autoCapitalization)
        }
        
        if let autoCorrect = props["autoCorrect"] as? Bool {
            textView.autocorrectionType = autoCorrect ? .yes : .no
        }
        
        if let editable = props["editable"] as? Bool {
            textView.isEditable = editable
        }
        
        return true
    }
    
    private func mapKeyboardType(_ type: String) -> UIKeyboardType {
        switch type {
        case "numbersAndPunctuation": return .numbersAndPunctuation
        case "numberPad": return .numberPad
        case "phonePad": return .phonePad
        case "namePhonePad": return .namePhonePad
        case "emailAddress": return .emailAddress
        case "decimalPad": return .decimalPad
        case "twitter": return .twitter
        case "webSearch": return .webSearch
        case "asciiCapableNumberPad": return .asciiCapableNumberPad
        default: return .default
        }
    }
    
    private func mapReturnKeyType(_ type: String) -> UIReturnKeyType {
        switch type {
        case "go": return .go
        case "google": return .google
        case "join": return .join
        case "next": return .next
        case "route": return .route
        case "search": return .search
        case "send": return .send
        case "yahoo": return .yahoo
        case "done": return .done
        case "emergencyCall": return .emergencyCall
        case "continue_": return .continue
        default: return .default
        }
    }
    
    private func mapAutoCapitalizationType(_ type: String) -> UITextAutocapitalizationType {
        switch type {
        case "words": return .words
        case "sentences": return .sentences
        case "allCharacters": return .allCharacters
        default: return .none
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let maxLength = objc_getAssociatedObject(textField, UnsafeRawPointer(bitPattern: "maxLength".hashValue)!) as? Int {
            let currentText = textField.text ?? ""
            let newLength = currentText.count + string.count - range.length
            if newLength > maxLength { return false }
        }
        
        let currentText = textField.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
        propagateEvent(on: textField, eventName: "onChangeText", data: ["text": newText])
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        propagateEvent(on: textField, eventName: "onFocus", data: [:])
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        propagateEvent(on: textField, eventName: "onBlur", data: [:])
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        propagateEvent(on: textField, eventName: "onSubmitEditing", data: ["text": textField.text ?? ""])
        return true
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let currentText = textView.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: text)
        propagateEvent(on: textView, eventName: "onChangeText", data: ["text": newText])
        return true
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        propagateEvent(on: textView, eventName: "onFocus", data: [:])
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        propagateEvent(on: textView, eventName: "onBlur", data: [:])
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }

    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        objc_setAssociatedObject(view, UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, nodeId, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}
