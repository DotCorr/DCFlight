/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

// 🚀 MODAL HEADER COMPONENT - Header for modals with title, close button, etc.
class DCFModalHeaderComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFModalHeaderComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let headerView = UIView()
        
        // Apply adaptive theming
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                headerView.backgroundColor = UIColor.systemBackground
            } else {
                headerView.backgroundColor = UIColor.white
            }
        } else {
            headerView.backgroundColor = UIColor.clear
        }
        
        setupHeaderContent(headerView, props: props)
        updateView(headerView, withProps: props)
        headerView.applyStyles(props: props)
        
        return headerView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // Clear existing subviews and rebuild
        view.subviews.forEach { $0.removeFromSuperview() }
        setupHeaderContent(view, props: props)
        
        view.applyStyles(props: props)
        return true
    }
    
    private func setupHeaderContent(_ headerView: UIView, props: [String: Any]) {
        let title = props["title"] as? String
        let showCloseButton = props["showCloseButton"] as? Bool ?? true
        let closeButtonPosition = props["closeButtonPosition"] as? String ?? "right"
        
        // Create stack view for layout
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(stackView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16)
        ])
        
        // Add close button on left if positioned left
        if showCloseButton && closeButtonPosition.lowercased() == "left" {
            let closeButton = createCloseButton(props: props)
            stackView.addArrangedSubview(closeButton)
        }
        
        // Add title if provided
        if let title = title {
            let titleLabel = createTitleLabel(title: title, props: props)
            stackView.addArrangedSubview(titleLabel)
        }
        
        // Add spacer
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.addArrangedSubview(spacer)
        
        // Add close button on right if positioned right (default)
        if showCloseButton && closeButtonPosition.lowercased() != "left" {
            let closeButton = createCloseButton(props: props)
            stackView.addArrangedSubview(closeButton)
        }
        
        // Add bottom separator if enabled
        if props["showSeparator"] as? Bool == true {
            addBottomSeparator(to: headerView, props: props)
        }
    }
    
    private func createTitleLabel(title: String, props: [String: Any]) -> UILabel {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 1
        
        // Configure font
        if let fontSize = props["titleFontSize"] as? CGFloat {
            titleLabel.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        } else {
            titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        }
        
        // Configure color
        if let titleColor = props["titleColor"] as? String {
            titleLabel.textColor = UIColor(hexString: titleColor)
        } else if #available(iOS 13.0, *) {
            titleLabel.textColor = UIColor.label
        } else {
            titleLabel.textColor = UIColor.black
        }
        
        // Accessibility
        titleLabel.isAccessibilityElement = true
        titleLabel.accessibilityTraits = .header
        titleLabel.accessibilityLabel = "Modal title: \(title)"
        
        return titleLabel
    }
    
    private func createCloseButton(props: [String: Any]) -> UIButton {
        let closeButton = UIButton(type: .system)
        
        // Configure button appearance
        if let closeButtonText = props["closeButtonText"] as? String {
            closeButton.setTitle(closeButtonText, for: .normal)
        } else {
            // Use SF Symbol or fallback
            if #available(iOS 13.0, *) {
                let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
                let closeImage = UIImage(systemName: "xmark", withConfiguration: config)
                closeButton.setImage(closeImage, for: .normal)
            } else {
                closeButton.setTitle("✕", for: .normal)
                closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
            }
        }
        
        // Configure colors
        if let closeButtonColor = props["closeButtonColor"] as? String {
            closeButton.tintColor = UIColor(hexString: closeButtonColor)
        } else if #available(iOS 13.0, *) {
            closeButton.tintColor = UIColor.secondaryLabel
        } else {
            closeButton.tintColor = UIColor.darkGray
        }
        
        // Size constraints
        closeButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        // Add target
        closeButton.addTarget(DCFModalHeaderComponent.sharedInstance, action: #selector(closeButtonTapped(_:)), for: .touchUpInside)
        
        // Accessibility
        closeButton.isAccessibilityElement = true
        closeButton.accessibilityLabel = "Close modal"
        closeButton.accessibilityTraits = .button
        
        return closeButton
    }
    
    private func addBottomSeparator(to headerView: UIView, props: [String: Any]) {
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure separator color
        if let separatorColor = props["separatorColor"] as? String {
            separator.backgroundColor = UIColor(hexString: separatorColor)
        } else if #available(iOS 13.0, *) {
            separator.backgroundColor = UIColor.separator
        } else {
            separator.backgroundColor = UIColor.lightGray
        }
        
        headerView.addSubview(separator)
        
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }
    
    @objc private func closeButtonTapped(_ sender: UIButton) {
        // Find the parent header view to propagate the event
        var currentView: UIView? = sender
        while currentView != nil {
            if currentView is UIView && currentView?.superview != nil {
                // Found the header view, propagate close event
                propagateEvent(on: currentView!, eventName: "onClose", data: [:])
                break
            }
            currentView = currentView?.superview
        }
    }
}
