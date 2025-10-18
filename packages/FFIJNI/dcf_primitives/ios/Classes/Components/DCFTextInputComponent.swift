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
        let isAdaptive = props["adaptive"] as? Bool ?? true
        
        let inputView: UIView
        if isMultiline {
            let textView = UITextView()
            textView.font = UIFont.systemFont(ofSize: 16)
            
            if isAdaptive {
                if #available(iOS 13.0, *) {
                    textView.backgroundColor = UIColor.systemBackground
                    textView.textColor = UIColor.label
                } else {
                    textView.backgroundColor = UIColor.white
                    textView.textColor = UIColor.black
                }
            } else {
                textView.backgroundColor = UIColor.clear
                textView.textColor = UIColor.black
            }
            
            textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            textView.delegate = DCFTextInputComponent.sharedInstance
            inputView = textView
        } else {
            let textField = UITextField()
            textField.font = UIFont.systemFont(ofSize: 16)
            
            if isAdaptive {
                if #available(iOS 13.0, *) {
                    textField.backgroundColor = UIColor.systemBackground
                    textField.textColor = UIColor.label
                } else {
                    textField.backgroundColor = UIColor.white
                    textField.textColor = UIColor.black
                }
            } else {
                textField.backgroundColor = UIColor.clear
                textField.textColor = UIColor.black
            }
            
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
        
        if let placeholderColor = props["placeholderTextColor"] as? String {
            textField.attributedPlaceholder = NSAttributedString(
                string: textField.placeholder ?? "",
                attributes: [NSAttributedString.Key.foregroundColor: ColorUtilities.color(fromHexString: placeholderColor) ?? UIColor.placeholderText]
            )
        }
        
        if props.keys.contains("textColor") {
            if let textColor = props["textColor"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: textColor)
                textField.textColor = uiColor
            } else {
            }
        }
        
        if props.keys.contains("adaptive") && !props.keys.contains("textColor") {
            let isAdaptive = props["adaptive"] as? Bool ?? true
            if isAdaptive {
                if #available(iOS 13.0, *) {
                    textField.textColor = UIColor.label
                } else {
                    textField.textColor = UIColor.black
                }
            }
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
        
        if let selectionColor = props["selectionColor"] as? String {
            textField.tintColor = ColorUtilities.color(fromHexString: selectionColor)
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
        
        if let selectionColor = props["selectionColor"] as? String {
            textView.tintColor = ColorUtilities.color(fromHexString: selectionColor)
        }
        
        if props.keys.contains("textColor") {
            if let textColor = props["textColor"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: textColor)
                textView.textColor = uiColor
            } else {
            }
        }
        
        if props.keys.contains("adaptive") && !props.keys.contains("textColor") {
            let isAdaptive = props["adaptive"] as? Bool ?? true
            if isAdaptive {
                if #available(iOS 13.0, *) {
                    textView.textColor = UIColor.label
                } else {
                    textView.textColor = UIColor.black
                }
            }
        }
        
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
}
