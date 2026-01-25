/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */


import UIKit
import dcflight

class DCFDropdownComponent: NSObject, DCFComponent {
    static let sharedInstance = DCFDropdownComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        let button = UIButton(type: .system)
        
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 40)
        
        button.applyStyles(props: props)
        
        let arrowImageView = UIImageView(image: UIImage(systemName: "chevron.down"))
        arrowImageView.contentMode = .scaleAspectFit
        button.addSubview(arrowImageView)
        
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arrowImageView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
            arrowImageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 16),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        button.addTarget(DCFDropdownComponent.sharedInstance, action: #selector(dropdownTapped(_:)), for: .touchUpInside)
        
        updateView(button, withProps: props)
        
        if let visible = props["visible"] as? Bool, visible {
            showDropdown(for: button, props: props)
        }
        
        return button
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let button = view as? UIButton else { return false }
        
        button.applyStyles(props: props)
        
        if let visible = props["visible"] as? Bool {
            if visible {
                showDropdown(for: button, props: props)
            } else {
                hideDropdown(for: button)
            }
        }
        
        objc_setAssociatedObject(
            button,
            UnsafeRawPointer(bitPattern: "dropdownProps".hashValue)!,
            props,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        if let selectedValue = props["selectedValue"] as? String,
           let items = props["items"] as? [[String: Any]] {
            
            let selectedItem = items.first { item in
                return item["value"] as? String == selectedValue
            }
            
            if let label = selectedItem?["label"] as? String {
                button.setTitle(label, for: .normal)
            } else {
                let placeholder = props["placeholder"] as? String ?? "Select..."
                button.setTitle(placeholder, for: .normal)
                
                if let placeholderColor = ColorUtilities.getColor(
                    explicitColor: "placeholderColor",
                    semanticColor: "secondaryColor",
                    from: props
                ) {
                    button.setTitleColor(placeholderColor, for: .normal)
                }
            }
        } else {
            let placeholder = props["placeholder"] as? String ?? "Select..."
            button.setTitle(placeholder, for: .normal)
            
            if let placeholderColor = ColorUtilities.getColor(
                explicitColor: "placeholderColor",
                semanticColor: "secondaryColor",
                from: props
            ) {
                button.setTitleColor(placeholderColor, for: .normal)
            }
        }
        
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
        
        if let disabled = props["disabled"] as? Bool, disabled {
            return
        }
        
        propagateEvent(on: button, eventName: "onOpen", data: [:])
        
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
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            propagateEvent(on: button, eventName: "onClose", data: [:])
        })
        
        if let topViewController = UIApplication.shared.windows.first?.rootViewController {
            var presentingController = topViewController
            while let presented = presentingController.presentedViewController {
                presentingController = presented
            }
            
            if let popover = alertController.popoverPresentationController {
                popover.sourceView = button
                popover.sourceRect = button.bounds
            }
            
            presentingController.present(alertController, animated: true)
        }
    }
    
    private func presentMultiSelectDropdown(for button: UIButton, items: [[String: Any]], props: [String: Any], maxHeight: CGFloat) {
        let dropdownVC = MultiSelectDropdownViewController()
        dropdownVC.items = items
        dropdownVC.selectedValues = props["selectedValues"] as? [String] ?? []
        dropdownVC.maxHeight = maxHeight
        
        dropdownVC.onSelectionChanged = { selectedValues, selectedItems in
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
        
        for (index, item) in items.enumerated() {
            let title = item["label"] as? String ?? "Option \(index)"
            let value = item["value"] as? String ?? ""
            let isSelected = props["selectedValue"] as? String == value
            
            let action = UIAlertAction(title: title, style: .default) { _ in
                propagateEvent(on: button, eventName: "onValueChange", data: [
                    "value": value,
                    "selectedItem": [
                        "value": value,
                        "label": title,
                        "title": title  // For DCFDropdownMenuItem compatibility
                    ]
                ])
                
                button.setTitle(title, for: .normal)
            }
            
            if isSelected {
                action.setValue(true, forKey: "checked")
            }
            
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            propagateEvent(on: button, eventName: "onCancel", data: [:])
        })
        
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = button
            popover.sourceRect = button.bounds
        }
        
        if let topViewController = UIApplication.shared.windows.first?.rootViewController {
            var presentingController = topViewController
            while let presented = presentingController.presentedViewController {
                presentingController = presented
            }
            presentingController.present(alertController, animated: true)
        }
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }

    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
        objc_setAssociatedObject(view,
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!,
                               nodeId,
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}


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
        let navBar = UINavigationBar()
        let navItem = UINavigationItem(title: "Select Items")
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
        navItem.rightBarButtonItem = doneButton
        navBar.setItems([navItem], animated: false)
        
        view.addSubview(navBar)
        
        tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.allowsMultipleSelection = true
        
        view.addSubview(tableView)
        
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


extension MultiSelectDropdownViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = items[indexPath.row]
        
        cell.textLabel?.text = item["label"] as? String
        cell.selectionStyle = .none
        
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
