/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import Foundation
import dcflight

class DCFTextInputComponent: NSObject, DCFComponent, UITextFieldDelegate, UITextViewDelegate {
    private static let sharedInstance = DCFTextInputComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let isMultiline = props["multiline"] as? Bool ?? false
        
        let inputView: UIView
        if isMultiline {
            let textView = UITextView()
            textView.font = UIFont.systemFont(ofSize: 16)
            
            // UNIFIED SEMANTIC COLOR SYSTEM: Component handles semantic colors
            // primaryColor: text color
            // UNIFIED COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
            if let primaryColorStr = props["primaryColor"] as? String {
                if let color = ColorUtilities.color(fromHexString: primaryColorStr) {
                    textView.textColor = color
                }
                // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
            }
            // NO FALLBACK: If no primaryColor provided, don't set color (StyleSheet is the only source)
            
            // accentColor: selection color
            if let accentColorStr = props["accentColor"] as? String {
                if let color = ColorUtilities.color(fromHexString: accentColorStr) {
                    textView.tintColor = color
                }
                // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
            }
            // NO FALLBACK: If no accentColor provided, don't set color (StyleSheet is the only source)
            
            // backgroundColor handled by applyStyles
            textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            textView.delegate = DCFTextInputComponent.sharedInstance
            inputView = textView
        } else {
            let textField = UITextField()
            textField.font = UIFont.systemFont(ofSize: 16)
            
            // UNIFIED SEMANTIC COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
            // primaryColor: text color
            if let primaryColorStr = props["primaryColor"] as? String {
                if let color = ColorUtilities.color(fromHexString: primaryColorStr) {
                    textField.textColor = color
                }
                // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
            }
            // NO FALLBACK: If no primaryColor provided, don't set color (StyleSheet is the only source)
            
            // secondaryColor: placeholder color
            if let secondaryColorStr = props["secondaryColor"] as? String {
                if let placeholder = props["placeholder"] as? String {
                    if let color = ColorUtilities.color(fromHexString: secondaryColorStr) {
                        textField.attributedPlaceholder = NSAttributedString(
                            string: placeholder,
                            attributes: [NSAttributedString.Key.foregroundColor: color]
                        )
                    }
                    // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
                }
            }
            // NO FALLBACK: If no secondaryColor provided, don't set color (StyleSheet is the only source)
            
            // accentColor: selection color
            if let accentColorStr = props["accentColor"] as? String {
                if let color = ColorUtilities.color(fromHexString: accentColorStr) {
                    textField.tintColor = color
                }
                // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
            }
            // NO FALLBACK: If no accentColor provided, don't set color (StyleSheet is the only source)
            
            // backgroundColor handled by applyStyles
            textField.borderStyle = .none
            textField.delegate = DCFTextInputComponent.sharedInstance
            inputView = textField
        }
        
        updateView(inputView, withProps: props)
        
        return inputView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        if let textField = view as? UITextField {
            return updateTextField(textField, withProps: props)
        } else if let textView = view as? UITextView {
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
        
        // UNIFIED COLOR SYSTEM: ONLY StyleSheet provides colors - NO fallbacks
        // Text color: primaryColor from StyleSheet
        if let primaryColor = props["primaryColor"] as? String {
            if let color = ColorUtilities.color(fromHexString: primaryColor) {
                textField.textColor = color
            }
            // NO FALLBACK: If color parsing fails, don't set color (StyleSheet is the only source)
        }
        // NO FALLBACK: If no primaryColor provided, don't set color (StyleSheet is the only source)
        
        // Placeholder color: secondaryColor from StyleSheet
        if let secondaryColor = props["secondaryColor"] as? String {
            textField.attributedPlaceholder = NSAttributedString(
                string: textField.placeholder ?? "",
                attributes: [NSAttributedString.Key.foregroundColor: ColorUtilities.color(fromHexString: secondaryColor) ?? UIColor.placeholderText]
            )
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
        
        // Selection color: accentColor from StyleSheet
        if let accentColor = props["accentColor"] as? String {
            textField.tintColor = ColorUtilities.color(fromHexString: accentColor)
        }
        
        if let maxLength = props["maxLength"] as? Int {
            objc_setAssociatedObject(textField, UnsafeRawPointer(bitPattern: "maxLength".hashValue)!, maxLength, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        textField.applyStyles(props: props)

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
        
        // UNIFIED COLOR SYSTEM: Use semantic colors from StyleSheet only
        // Selection color: accentColor from StyleSheet
        if let accentColor = props["accentColor"] as? String {
            textView.tintColor = ColorUtilities.color(fromHexString: accentColor)
        }
        
        // Text color: primaryColor from StyleSheet
        if let primaryColor = props["primaryColor"] as? String {
            textView.textColor = ColorUtilities.color(fromHexString: primaryColor)
        }
        // NO FALLBACK: If no primaryColor provided, don't set color (StyleSheet is the only source)
        
        textView.applyStyles(props: props)

        return true
    }
    
    
    private func mapKeyboardType(_ type: String) -> UIKeyboardType {
        switch type {
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
        case "twitter":
            return .twitter
        case "webSearch":
            return .webSearch
        case "asciiCapableNumberPad":
            return .asciiCapableNumberPad
        default:
            return .default
        }
    }
    
    private func mapReturnKeyType(_ type: String) -> UIReturnKeyType {
        switch type {
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
        case "emergencyCall":
            return .emergencyCall
        case "continue_":
            return .continue
        default:
            return .default
        }
    }
    
    private func mapAutoCapitalizationType(_ type: String) -> UITextAutocapitalizationType {
        switch type {
        case "words":
            return .words
        case "sentences":
            return .sentences
        case "allCharacters":
            return .allCharacters
        default:
            return .none
        }
    }
    
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let maxLength = objc_getAssociatedObject(textField, UnsafeRawPointer(bitPattern: "maxLength".hashValue)!) as? Int {
            let currentText = textField.text ?? ""
            let newLength = currentText.count + string.count - range.length
            if newLength > maxLength {
                return false
            }
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
    
    override func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        if let textField = view as? UITextField {
            let size = textField.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            return CGSize(width: max(1, size.width), height: max(1, size.height))
        } else if let textView = view as? UITextView {
            let size = textView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            return CGSize(width: max(1, size.width), height: max(1, size.height))
        }
        return CGSize.zero
    }
}
