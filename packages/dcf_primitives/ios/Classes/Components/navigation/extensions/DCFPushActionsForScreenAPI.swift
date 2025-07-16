import SVGKit
import UIKit
import dcflight

extension DCFScreenComponent {

    // MARK: - Enhanced Push Configuration Storage

    private func storePushConfiguration(_ screenContainer: ScreenContainer, props: [String: Any]) {
        var pushConfig: [String: Any] = [:]

        if let pushConfigData = props["pushConfig"] as? [String: Any] {
            pushConfig = pushConfigData
        } else {
            // Extract push config from individual props
            if let title = props["title"] as? String {
                pushConfig["title"] = title
            }

            if let hideNavigationBar = props["hideNavigationBar"] as? Bool {
                pushConfig["hideNavigationBar"] = hideNavigationBar
            }

            if let hideBackButton = props["hideBackButton"] as? Bool {
                pushConfig["hideBackButton"] = hideBackButton
            }

            if let backButtonTitle = props["backButtonTitle"] as? String {
                pushConfig["backButtonTitle"] = backButtonTitle
            }

            if let largeTitleDisplayMode = props["largeTitleDisplayMode"] as? Bool {
                pushConfig["largeTitleDisplayMode"] = largeTitleDisplayMode
            }

            // NEW: Store header actions
            if let prefixActions = props["prefixActions"] as? [[String: Any]] {
                pushConfig["prefixActions"] = prefixActions
            }

            if let suffixActions = props["suffixActions"] as? [[String: Any]] {
                pushConfig["suffixActions"] = suffixActions
            }
        }

        if !pushConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "pushConfig".hashValue)!,
                pushConfig,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    // MARK: - Enhanced Push Screen Configuration

    public func configureScreenForPush(_ screenContainer: ScreenContainer) {
        guard
            let pushConfig = objc_getAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "pushConfig".hashValue)!
            ) as? [String: Any]
        else {
            return
        }

        let viewController = screenContainer.viewController

        // Configure basic navigation item properties
        if let title = pushConfig["title"] as? String {
            viewController.navigationItem.title = title
        }

        let hideBackButton = pushConfig["hideBackButton"] as? Bool ?? false
        viewController.navigationItem.hidesBackButton = hideBackButton

        if let backButtonTitle = pushConfig["backButtonTitle"] as? String {
            let backItem = UIBarButtonItem(
                title: backButtonTitle, style: .plain, target: nil, action: nil)
            viewController.navigationItem.backBarButtonItem = backItem
        }

        let largeTitleDisplayMode = pushConfig["largeTitleDisplayMode"] as? Bool ?? false
        if #available(iOS 11.0, *) {
            viewController.navigationItem.largeTitleDisplayMode =
                largeTitleDisplayMode ? .always : .never
        }

        // NEW: Configure header actions
        configureHeaderActions(for: viewController, pushConfig: pushConfig)
    }

    // MARK: - Header Actions Configuration

    private func configureHeaderActions(
        for viewController: UIViewController, pushConfig: [String: Any]
    ) {
        // Configure left bar button items (prefix actions)
        if let prefixActionsData = pushConfig["prefixActions"] as? [[String: Any]] {
            let leftBarButtonItems = createBarButtonItems(
                from: prefixActionsData,
                for: viewController,
                position: .left
            )
            viewController.navigationItem.leftBarButtonItems = leftBarButtonItems
        }

        // Configure right bar button items (suffix actions)
        if let suffixActionsData = pushConfig["suffixActions"] as? [[String: Any]] {
            let rightBarButtonItems = createBarButtonItems(
                from: suffixActionsData,
                for: viewController,
                position: .right
            )
            viewController.navigationItem.rightBarButtonItems = rightBarButtonItems
        }
    }

    // MARK: - Bar Button Item Creation

    private enum BarButtonPosition {
        case left, right
    }

    private func createBarButtonItems(
        from actionsData: [[String: Any]],
        for viewController: UIViewController,
        position: BarButtonPosition
    ) -> [UIBarButtonItem] {

        var barButtonItems: [UIBarButtonItem] = []

        for (index, actionData) in actionsData.enumerated() {
            if let barButtonItem = createBarButtonItem(
                from: actionData,
                for: viewController,
                position: position,
                index: index
            ) {
                barButtonItems.append(barButtonItem)
            }
        }

        return barButtonItems
    }

    private func createBarButtonItem(
        from actionData: [String: Any],
        for viewController: UIViewController,
        position: BarButtonPosition,
        index: Int
    ) -> UIBarButtonItem? {

        let title = actionData["title"] as? String ?? ""
        let enabled = actionData["enabled"] as? Bool ?? true
        let actionId = actionData["actionId"] as? String ?? "action_\(position)_\(index)"

        guard let iconConfig = actionData["icon"] as? [String: Any] else {
            print("❌ DCFScreenComponent: Missing icon config for header action")
            return nil
        }

        let iconType = iconConfig["type"] as? String ?? "sf"

        var barButtonItem: UIBarButtonItem?

        switch iconType {
        case "text":
            // Text-only button
            barButtonItem = UIBarButtonItem(
                title: title,
                style: .plain,
                target: self,
                action: #selector(headerActionPressed(_:))
            )

        case "sf":
            // SF Symbol button
            if let symbolName = iconConfig["name"] as? String {
                let image = UIImage(systemName: symbolName)
                barButtonItem = UIBarButtonItem(
                    image: image,
                    style: .plain,
                    target: self,
                    action: #selector(headerActionPressed(_:))
                )

                // Add title if provided and not empty
                if !title.isEmpty {
                    barButtonItem?.title = title
                }
            }

        case "package":
            // SVG from package
            if let iconName = iconConfig["name"] as? String,
                let packageName = iconConfig["package"] as? String
            {

                let image = loadSVGForHeaderAction(
                    iconName: iconName,
                    packageName: packageName,
                    iconConfig: iconConfig
                )

                barButtonItem = UIBarButtonItem(
                    image: image,
                    style: .plain,
                    target: self,
                    action: #selector(headerActionPressed(_:))
                )

                // Add title if provided and not empty
                if !title.isEmpty {
                    barButtonItem?.title = title
                }
            }

        case "svg":
            // SVG from asset path
            if let assetPath = iconConfig["assetPath"] as? String {
                let image = loadSVGFromAssetPath(assetPath, iconConfig: iconConfig)

                barButtonItem = UIBarButtonItem(
                    image: image,
                    style: .plain,
                    target: self,
                    action: #selector(headerActionPressed(_:))
                )

                // Add title if provided and not empty
                if !title.isEmpty {
                    barButtonItem?.title = title
                }
            }

        default:
            print("⚠️ DCFScreenComponent: Unknown icon type '\(iconType)' for header action")
            // Fallback to text-only button
            barButtonItem = UIBarButtonItem(
                title: title,
                style: .plain,
                target: self,
                action: #selector(headerActionPressed(_:))
            )
        }

        // Configure button properties
        barButtonItem?.isEnabled = enabled

        // Store action data for later use
        if let barButtonItem = barButtonItem {
            objc_setAssociatedObject(
                barButtonItem,
                UnsafeRawPointer(bitPattern: "actionData".hashValue)!,
                actionData,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

            objc_setAssociatedObject(
                barButtonItem,
                UnsafeRawPointer(bitPattern: "viewController".hashValue)!,
                viewController,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }

        return barButtonItem
    }

    // MARK: - SVG Loading for Header Actions

    private func loadSVGForHeaderAction(
        iconName: String,
        packageName: String,
        iconConfig: [String: Any]
    ) -> UIImage? {

        guard
            let key = sharedFlutterViewController?.lookupKey(
                forAsset: "assets/icons/\(iconName).svg",
                fromPackage: packageName
            )
        else {
            print(
                "❌ DCFScreenComponent: Could not find asset key for \(iconName) in package \(packageName)"
            )
            return nil
        }

        let mainBundle = Bundle.main
        guard let path = mainBundle.path(forResource: key, ofType: nil),
            !path.isEmpty
        else {
            print(
                "❌ DCFScreenComponent: Could not find file path for \(iconName) in package \(packageName)"
            )
            return nil
        }

        return loadSVGImage(from: path, iconConfig: iconConfig)
    }

    private func loadSVGFromAssetPath(_ assetPath: String, iconConfig: [String: Any]) -> UIImage? {
        let key = sharedFlutterViewController?.lookupKey(forAsset: assetPath)
        let mainBundle = Bundle.main
        guard let path = mainBundle.path(forResource: key, ofType: nil) else {
            print("❌ DCFScreenComponent: Could not find SVG at asset path: \(assetPath)")
            return nil
        }

        return loadSVGImage(from: path, iconConfig: iconConfig)
    }

    private func loadSVGImage(from path: String, iconConfig: [String: Any]) -> UIImage? {
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ DCFScreenComponent: SVG file does not exist at path: \(path)")
            return nil
        }

        let cacheKey = path + "_header_action"
        if let cachedImage = DCFSvgComponent.getCachedImage(for: cacheKey) {
            return processHeaderActionSVG(cachedImage, iconConfig: iconConfig)
        }

        guard let svgImage = SVGKImage(contentsOfFile: path) else {
            print("❌ DCFScreenComponent: Failed to load SVG from path: \(path)")
            return nil
        }

        let iconSize = iconConfig["size"] as? CGFloat ?? 22.0  // Default navigation bar icon size
        let targetSize = CGSize(width: iconSize, height: iconSize)

        svgImage.size = targetSize

        DCFSvgComponent.setCachedImage(svgImage, for: cacheKey)

        return processHeaderActionSVG(svgImage, iconConfig: iconConfig)
    }

    private func processHeaderActionSVG(_ svgImage: SVGKImage, iconConfig: [String: Any])
        -> UIImage?
    {
        guard let uiImage = svgImage.uiImage else { return nil }

        // Apply tint color if provided
        if let tintColor = iconConfig["tintColor"] as? String,
            let color = ColorUtilities.color(fromHexString: tintColor)
        {
            return createTintedImage(from: uiImage, color: color)
        }

        // Default to template rendering for navigation bar icons
        return uiImage.withRenderingMode(.alwaysTemplate)
    }

    private func createTintedImage(from image: UIImage, color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        let rect = CGRect(origin: .zero, size: image.size)
        context.clip(to: rect, mask: image.cgImage!)

        color.setFill()
        context.fill(rect)

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - Header Action Event Handling

    @objc private func headerActionPressed(_ sender: UIBarButtonItem) {
        guard
            let actionData = objc_getAssociatedObject(
                sender,
                UnsafeRawPointer(bitPattern: "actionData".hashValue)!
            ) as? [String: Any],
            let viewController = objc_getAssociatedObject(
                sender,
                UnsafeRawPointer(bitPattern: "viewController".hashValue)!
            ) as? UIViewController
        else {
            print("❌ DCFScreenComponent: No action data found for header action")
            return
        }

        let actionId = actionData["actionId"] as? String ?? "unknown_action"
        let title = actionData["title"] as? String ?? ""

        print("🎯 DCFScreenComponent: Header action pressed - ID: \(actionId), Title: \(title)")

        // Find the screen container for this view controller
        for (screenName, container) in DCFScreenComponent.screenRegistry {
            if container.viewController == viewController {
                // Propagate the action press event
                propagateEvent(
                    on: container.contentView,
                    eventName: "onHeaderActionPress",
                    data: [
                        "actionId": actionId,
                        "title": title,
                        "screenName": screenName,
                    ]
                )
                break
            }
        }
    }
}
