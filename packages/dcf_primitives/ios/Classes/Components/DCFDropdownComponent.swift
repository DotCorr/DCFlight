/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

// 🚀 CLEAN DROPDOWN COMPONENT - Uses only propagateEvent()
class DCFDropdownComponent: NSObject, DCFComponent {
    static let sharedInstance = DCFDropdownComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let button = UIButton(type: .system)
        
        // Apply adaptive default styling - let OS handle light/dark mode
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            // Use system colors that automatically adapt to light/dark mode
            if #available(iOS 13.0, *) {
                button.backgroundColor = UIColor.systemGray6
                button.layer.borderColor = UIColor.systemGray4.cgColor
                button.setTitleColor(UIColor.label, for: .normal)
            } else {
                button.backgroundColor = UIColor.lightGray
                button.layer.borderColor = UIColor.gray.cgColor
                button.setTitleColor(UIColor.black, for: .normal)
            }
        } else {
            button.backgroundColor = UIColor.white
            button.layer.borderColor = UIColor.gray.cgColor
            button.setTitleColor(UIColor.black, for: .normal)
        }
        
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 40)
        
        // Apply StyleSheet properties
        button.applyStyles(props: props)
        
        // Add dropdown arrow
        let arrowImageView = UIImageView(image: UIImage(systemName: "chevron.down"))
        if isAdaptive {
            if #available(iOS 13.0, *) {
                arrowImageView.tintColor = UIColor.systemGray
            } else {
                arrowImageView.tintColor = UIColor.gray
            }
        } else {
            arrowImageView.tintColor = UIColor.gray
        }
        arrowImageView.contentMode = .scaleAspectFit
        button.addSubview(arrowImageView)
        
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arrowImageView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
            arrowImageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 16),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        // Add tap gesture - use sharedInstance to prevent deallocation
        button.addTarget(DCFDropdownComponent.sharedInstance, action: #selector(dropdownTapped(_:)), for: .touchUpInside)
        
        // Apply initial properties
        updateView(button, withProps: props)
        
        // Check if dropdown should be shown immediately
        if let visible = props["visible"] as? Bool, visible {
            showDropdown(for: button, props: props)
        }
        
        return button
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let button = view as? UIButton else { return false }
        
        // Apply StyleSheet properties
        button.applyStyles(props: props)
        
        // Check visible prop to determine if dropdown should be shown
        if let visible = props["visible"] as? Bool {
            if visible {
                showDropdown(for: button, props: props)
            } else {
                hideDropdown(for: button)
            }
        }
        
        // Store props for dropdown presentation
        objc_setAssociatedObject(
            button,
            UnsafeRawPointer(bitPattern: "dropdownProps".hashValue)!,
            props,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Update button title
        if let selectedValue = props["selectedValue"] as? String,
           let items = props["items"] as? [[String: Any]] {
            
            // Find selected item
            let selectedItem = items.first { item in
                return item["value"] as? String == selectedValue
            }
            
            if let label = selectedItem?["label"] as? String {
                button.setTitle(label, for: .normal)
            } else {
                // Show placeholder
                let placeholder = props["placeholder"] as? String ?? "Select..."
                button.setTitle(placeholder, for: .normal)
                
                if let placeholderColor = props["placeholderTextColor"] as? String {
                    button.setTitleColor(ColorUtilities.color(fromHexString: placeholderColor), for: .normal)
                } else {
                    button.setTitleColor(UIColor.placeholderText, for: .normal)
                }
            }
        } else {
            // Show placeholder
            let placeholder = props["placeholder"] as? String ?? "Select..."
            button.setTitle(placeholder, for: .normal)
            
            if let placeholderColor = props["placeholderTextColor"] as? String {
                button.setTitleColor(ColorUtilities.color(fromHexString: placeholderColor), for: .normal)
            } else {
                button.setTitleColor(UIColor.placeholderText, for: .normal)
            }
        }
        
        // Update disabled state
        if let disabled = props["disabled"] as? Bool {
            button.isEnabled = !disabled
            button.alpha = disabled ? 0.5 : 1.0
        }
        
        return true
    }
    
    @objc private func dropdownTapped(_ button: UIButton) {
        guard let props = objc_getAssociatedObject(
            button,
            UnsafeRawPointer(bitPattern: "dropdownProps".hashValue)!
        ) as? [String: Any] else { return }
        
        // Check if disabled
        if let disabled = props["disabled"] as? Bool, disabled {
            return
        }
        
        // Trigger onOpen event
        propagateEvent(on: button, eventName: "onOpen", data: [:])
        
        // Present dropdown
        presentDropdown(for: button, props: props)
    }
    
    private func presentDropdown(for button: UIButton, props: [String: Any]) {
        guard let items = props["items"] as? [[String: Any]] else { return }
        
        let dropdownPosition = props["dropdownPosition"] as? String ?? "bottom"
        let multiSelect = props["multiSelect"] as? Bool ?? false
        let maxHeight = props["maxHeight"] as? CGFloat ?? 200
        
        if multiSelect {
            presentMultiSelectDropdown(for: button, items: items, props: props, maxHeight: maxHeight)
        } else {
            presentSingleSelectDropdown(for: button, items: items, props: props, maxHeight: maxHeight)
        }
    }
    
    private func presentSingleSelectDropdown(for button: UIButton, items: [[String: Any]], props: [String: Any], maxHeight: CGFloat) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        for item in items {
            guard let label = item["label"] as? String,
                  let value = item["value"] as? String else { continue }
            
            let action = UIAlertAction(title: label, style: .default) { _ in
                // 🚀 FIXED: Use proper parameter format for Dart callback
                propagateEvent(on: button, eventName: "onValueChange", data: [
                    "value": value,
                    "selectedItem": [
                        "value": value,
                        "label": label,
                        "title": label  // For DCFDropdownMenuItem compatibility
                    ]
                ])
                propagateEvent(on: button, eventName: "onClose", data: [:])
            }
            
            alertController.addAction(action)
        }
        
        // Add cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            propagateEvent(on: button, eventName: "onClose", data: [:])
        })
        
        // Present the action sheet
        if let topViewController = UIApplication.shared.windows.first?.rootViewController {
            var presentingController = topViewController
            while let presented = presentingController.presentedViewController {
                presentingController = presented
            }
            
            // Configure popover for iPad
            if let popover = alertController.popoverPresentationController {
                popover.sourceView = button
                popover.sourceRect = button.bounds
            }
            
            presentingController.present(alertController, animated: true)
        }
    }
    
    private func presentMultiSelectDropdown(for button: UIButton, items: [[String: Any]], props: [String: Any], maxHeight: CGFloat) {
        // For multi-select, we'll create a custom modal with checkboxes
        let dropdownVC = MultiSelectDropdownViewController()
        dropdownVC.items = items
        dropdownVC.selectedValues = props["selectedValues"] as? [String] ?? []
        dropdownVC.maxHeight = maxHeight
        
        dropdownVC.onSelectionChanged = { selectedValues, selectedItems in
            // 🚀 FIXED: Use proper parameter format for Dart callback
            let formattedItems = selectedItems.map { item in
                return [
                    "value": item["value"] as? String ?? "",
                    "label": item["label"] as? String ?? "",
                    "title": item["label"] as? String ?? ""  // For DCFDropdownMenuItem compatibility
                ]
            }
            propagateEvent(on: button, eventName: "onMultiValueChange", data: [
                "values": selectedValues, 
                "selectedItems": formattedItems
            ])
        }
        
        dropdownVC.onDismiss = {
            propagateEvent(on: button, eventName: "onClose", data: [:])
        }
        
        // Present modally
        if let topViewController = UIApplication.shared.windows.first?.rootViewController {
            var presentingController = topViewController
            while let presented = presentingController.presentedViewController {
                presentingController = presented
            }
            
            presentingController.present(dropdownVC, animated: true)
        }
    }
    
    private func showDropdown(for button: UIButton, props: [String: Any]) {
        presentDropdownMenu(for: button, props: props)
        propagateEvent(on: button, eventName: "onShow", data: [:])
    }
    
    private func hideDropdown(for button: UIButton) {
        // Dismiss any presented dropdown
        if let topViewController = UIApplication.shared.windows.first?.rootViewController {
            var presentingController = topViewController
            while let presented = presentingController.presentedViewController {
                presentingController = presented
            }
            
            if presentingController.presentedViewController != nil {
                presentingController.dismiss(animated: true)
            }
        }
        
        propagateEvent(on: button, eventName: "onHide", data: [:])
    }
    
    private func presentDropdownMenu(for button: UIButton, props: [String: Any]) {
        guard let items = props["items"] as? [[String: Any]] else { return }
        
        let alertController = UIAlertController(
            title: props["placeholder"] as? String ?? "Select an option",
            message: nil,
            preferredStyle: .actionSheet
        )
        
        // Add options
        for (index, item) in items.enumerated() {
            let title = item["label"] as? String ?? "Option \(index)"
            let value = item["value"] as? String ?? ""
            let isSelected = props["selectedValue"] as? String == value
            
            let action = UIAlertAction(title: title, style: .default) { _ in
                // 🚀 FIXED: Use proper parameter format for Dart callback
                propagateEvent(on: button, eventName: "onValueChange", data: [
                    "value": value,
                    "selectedItem": [
                        "value": value,
                        "label": title,
                        "title": title  // For DCFDropdownMenuItem compatibility
                    ]
                ])
                
                // Update button title
                button.setTitle(title, for: .normal)
            }
            
            // Mark selected item
            if isSelected {
                action.setValue(true, forKey: "checked")
            }
            
            alertController.addAction(action)
        }
        
        // Add cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            propagateEvent(on: button, eventName: "onCancel", data: [:])
        })
        
        // Configure for iPad
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = button
            popover.sourceRect = button.bounds
        }
        
        // Present
        if let topViewController = UIApplication.shared.windows.first?.rootViewController {
            var presentingController = topViewController
            while let presented = presentingController.presentedViewController {
                presentingController = presented
            }
            presentingController.present(alertController, animated: true)
        }
    }
}

// MARK: - Multi-Select Dropdown View Controller

class MultiSelectDropdownViewController: UIViewController {
    var items: [[String: Any]] = []
    var selectedValues: [String] = []
    var maxHeight: CGFloat = 200
    
    var onSelectionChanged: (([String], [[String: Any]]) -> Void)?
    var onDismiss: (() -> Void)?
    
    private var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onDismiss?()
    }
    
    private func setupView() {
        view.backgroundColor = UIColor.systemBackground
        
        // Add navigation bar
        let navBar = UINavigationBar()
        let navItem = UINavigationItem(title: "Select Items")
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
        navItem.rightBarButtonItem = doneButton
        navBar.setItems([navItem], animated: false)
        
        view.addSubview(navBar)
        
        // Add table view
        tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.allowsMultipleSelection = true
        
        view.addSubview(tableView)
        
        // Setup constraints
        navBar.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.heightAnchor.constraint(lessThanOrEqualToConstant: maxHeight)
        ])
        
        // Pre-select items
        DispatchQueue.main.async {
            self.selectInitialItems()
        }
    }
    
    private func selectInitialItems() {
        for (index, item) in items.enumerated() {
            if let value = item["value"] as? String, selectedValues.contains(value) {
                let indexPath = IndexPath(row: index, section: 0)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
    }
    
    @objc private func donePressed() {
        let selectedItems = tableView.indexPathsForSelectedRows?.compactMap { indexPath in
            return items[indexPath.row]
        } ?? []
        
        let selectedValues = selectedItems.compactMap { $0["value"] as? String }
        
        onSelectionChanged?(selectedValues, selectedItems)
        dismiss(animated: true)
    }
}

// MARK: - Table View Data Source & Delegate

extension MultiSelectDropdownViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = items[indexPath.row]
        
        cell.textLabel?.text = item["label"] as? String
        cell.selectionStyle = .none
        
        // Add checkmark for selection
        if let value = item["value"] as? String, selectedValues.contains(value) {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .checkmark
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .none
    }
}
