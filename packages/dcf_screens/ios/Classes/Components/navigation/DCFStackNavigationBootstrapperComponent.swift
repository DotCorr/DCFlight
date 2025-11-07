import UIKit
import dcflight

class DCFStackNavigationBootstrapperComponent: NSObject, DCFComponent {

    required override init() {
        super.init()
    }

    func createView(props: [String: Any]) -> UIView {
        print("🔧 DCFStackNavigationBootstrapperComponent: Setting up stack navigation root")

        guard let initialScreen = props["initialScreen"] as? String else {
            print("❌ DCFStackNavigationBootstrapperComponent: Missing initialScreen prop")
            return UIView()
        }

        // Create the navigation controller (like DCFTabNavigatorComponent creates UITabBarController)
        let navigationController = UINavigationController()

        // Configure navigation bar style from props
        configureNavigationBarStyle(navigationController, props: props)

        // 🎯 FIXED: Use multiple retry attempts with increasing delays
        setupInitialScreenWithRetry(
            navigationController, initialScreen: initialScreen, retryCount: 0, maxRetries: 10)

        // Set as root controller immediately (like DCFTabNavigatorComponent does)
        DispatchQueue.main.async {
            replaceRoot(controller: navigationController)
            print("✅ DCFStackNavigationBootstrapperComponent: Stack navigation root ready")
        }

        // Return hidden placeholder view (matches DCFTabNavigatorComponent pattern)
        let placeholderView = UIView()
        placeholderView.isHidden = true
        placeholderView.backgroundColor = UIColor.clear

        // Store reference to navigation controller for future use
        objc_setAssociatedObject(
            placeholderView,
            UnsafeRawPointer(bitPattern: "navigationController".hashValue)!,
            navigationController,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        return placeholderView
    }

    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // Basic update support - navigation bar style changes etc.
        guard
            let navigationController = objc_getAssociatedObject(
                view,
                UnsafeRawPointer(bitPattern: "navigationController".hashValue)!
            ) as? UINavigationController
        else {
            return false
        }

        configureNavigationBarStyle(navigationController, props: props)
        return true
    }

    // MARK: - Private Methods

    private func configureNavigationBarStyle(
        _ navigationController: UINavigationController, props: [String: Any]
    ) {
        let navigationBar = navigationController.navigationBar

        // Background color
        if let backgroundColorString = props["backgroundColor"] as? String,
            let backgroundColor = ColorUtilities.color(fromHexString: backgroundColorString)
        {
            if #available(iOS 13.0, *) {
                let appearance = UINavigationBarAppearance()
                appearance.backgroundColor = backgroundColor
                navigationBar.standardAppearance = appearance
                navigationBar.scrollEdgeAppearance = appearance
            } else {
                navigationBar.backgroundColor = backgroundColor
            }
        }

        // Title color
        if let titleColorString = props["titleColor"] as? String,
            let titleColor = ColorUtilities.color(fromHexString: titleColorString)
        {
            navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: titleColor]
            if #available(iOS 11.0, *) {
                navigationBar.largeTitleTextAttributes = [
                    NSAttributedString.Key.foregroundColor: titleColor
                ]
            }
        }

        // Back button color
        if let backButtonColorString = props["backButtonColor"] as? String,
            let backButtonColor = ColorUtilities.color(fromHexString: backButtonColorString)
        {
            navigationBar.tintColor = backButtonColor
        }

        // Other navigation bar configurations
        let translucent = props["translucent"] as? Bool ?? true
        navigationBar.isTranslucent = translucent

        let hideNavigationBar = props["hideNavigationBar"] as? Bool ?? false
        navigationController.setNavigationBarHidden(hideNavigationBar, animated: false)

        // Title display mode
        if let titleDisplayMode = props["titleDisplayMode"] as? String {
            if #available(iOS 11.0, *) {
                switch titleDisplayMode.lowercased() {
                case "large":
                    navigationBar.prefersLargeTitles = true
                case "inline":
                    navigationBar.prefersLargeTitles = false
                default:  // "automatic"
                    navigationBar.prefersLargeTitles = false
                }
            }
        }
    }

    // 🎯 FIXED: Retry logic with exponential backoff
    private func setupInitialScreenWithRetry(
        _ navigationController: UINavigationController,
        initialScreen: String,
        retryCount: Int,
        maxRetries: Int
    ) {
        // Check if screen is available - FIXED: use correct method name
        if let initialScreenContainer = DCFScreenComponent.getScreenContainer(route: initialScreen) {
            print(
                "🎯 DCFStackNavigationBootstrapperComponent: Found initial screen '\(initialScreen)' on attempt \(retryCount + 1)"
            )
            setupInitialScreen(
                navigationController, screenContainer: initialScreenContainer,
                screenName: initialScreen)
            return
        }

        // Screen not found yet
        if retryCount < maxRetries {
            let delayMs = min(50 * (retryCount + 1), 500)  // Exponential backoff: 50ms, 100ms, 150ms... max 500ms
            print(
                "⏳ DCFStackNavigationBootstrapperComponent: Initial screen '\(initialScreen)' not found, retrying in \(delayMs)ms (attempt \(retryCount + 1)/\(maxRetries + 1))"
            )
            print(
                "   Available screens: \(Array(DCFScreenComponent.routeRegistry.keys))")

            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
                self.setupInitialScreenWithRetry(
                    navigationController, initialScreen: initialScreen, retryCount: retryCount + 1,
                    maxRetries: maxRetries)
            }
        } else {
            print(
                "❌ DCFStackNavigationBootstrapperComponent: Failed to find initial screen '\(initialScreen)' after \(maxRetries + 1) attempts"
            )
            print(
                "   Available screens: \(Array(DCFScreenComponent.routeRegistry.keys))")

            // Create a fallback screen
            createFallbackScreen(navigationController, initialScreen: initialScreen)
        }
    }

    private func setupInitialScreen(
        _ navigationController: UINavigationController,
        screenContainer: ScreenContainer,
        screenName: String
    ) {
        print(
            "🎯 DCFStackNavigationBootstrapperComponent: Setting up initial screen '\(screenName)'")

        // 🎯 CRITICAL FIX: Remove from any existing parent before setting up
        if screenContainer.viewController.parent != nil {
            print("🔧 DCFStackNavigationBootstrapperComponent: Removing view controller from existing parent")
            screenContainer.viewController.willMove(toParent: nil)
            screenContainer.viewController.view.removeFromSuperview()
            screenContainer.viewController.removeFromParent()
        }

        // Ensure content view is ready
        screenContainer.contentView.isHidden = false
        screenContainer.contentView.alpha = 1.0
        screenContainer.contentView.backgroundColor = UIColor.systemBackground

        // Set proper frame and autoresizing
        screenContainer.contentView.frame = UIScreen.main.bounds
        screenContainer.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 🎯 CRITICAL FIX: Configure header actions for initial screen
        if screenContainer.presentationStyle == "push" {
            // FIXED: Use the public method directly - it's available as public
            let screenComponent = DCFScreenComponent()
            screenComponent.configureScreenForPush(screenContainer)
            print(
                "✅ DCFStackNavigationBootstrapperComponent: Configured header actions for initial screen '\(screenName)'"
            )
        }

        // 🎯 CRITICAL FIX: Properly set as root view controller
        navigationController.setViewControllers([screenContainer.viewController], animated: false)

        // 🎯 CRITICAL FIX: Ensure the navigation controller's view is properly configured
        navigationController.view.backgroundColor = UIColor.systemBackground
        navigationController.view.frame = UIScreen.main.bounds
        navigationController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Fire initial lifecycle events (like DCFTabNavigatorComponent does)
        DispatchQueue.main.async {
            propagateEvent(
                on: screenContainer.contentView,
                eventName: "onAppear",
                data: ["route": screenName, "isInitial": true]
            )

            propagateEvent(
                on: screenContainer.contentView,
                eventName: "onActivate",
                data: ["route": screenName, "isInitial": true]
            )
        }

        print("✅ DCFStackNavigationBootstrapperComponent: Initial screen '\(screenName)' ready")
    }

    private func createFallbackScreen(
        _ navigationController: UINavigationController, initialScreen: String
    ) {
        print(
            "🔧 DCFStackNavigationBootstrapperComponent: Creating fallback screen for '\(initialScreen)'"
        )

        let fallbackVC = UIViewController()
        fallbackVC.view.backgroundColor = UIColor.systemBackground
        fallbackVC.title = "Loading..."

        // Add loading label
        let loadingLabel = UILabel()
        loadingLabel.text = "Waiting for '\(initialScreen)' screen to be registered..."
        loadingLabel.textAlignment = .center
        loadingLabel.numberOfLines = 0
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false

        fallbackVC.view.addSubview(loadingLabel)
        NSLayoutConstraint.activate([
            loadingLabel.centerXAnchor.constraint(equalTo: fallbackVC.view.centerXAnchor),
            loadingLabel.centerYAnchor.constraint(equalTo: fallbackVC.view.centerYAnchor),
            loadingLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: fallbackVC.view.leadingAnchor, constant: 20),
            loadingLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: fallbackVC.view.trailingAnchor, constant: -20),
        ])

        navigationController.viewControllers = [fallbackVC]

        // Keep trying to find the screen every second
        continueSearchingForScreen(
            navigationController, initialScreen: initialScreen, fallbackVC: fallbackVC)
    }

    private func continueSearchingForScreen(
        _ navigationController: UINavigationController, initialScreen: String,
        fallbackVC: UIViewController
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // FIXED: use correct method name
            if let screenContainer = DCFScreenComponent.getScreenContainer(route: initialScreen) {
                print(
                    "🎉 DCFStackNavigationBootstrapperComponent: Found initial screen '\(initialScreen)' during background search!"
                )
                self.setupInitialScreen(
                    navigationController, screenContainer: screenContainer,
                    screenName: initialScreen)
            } else {
                // Keep searching
                self.continueSearchingForScreen(
                    navigationController, initialScreen: initialScreen, fallbackVC: fallbackVC)
            }
        }
    }
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(x: layout.left, y: layout.top, width: layout.width, height: layout.height)
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        return CGSize.zero
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
        objc_setAssociatedObject(view, 
                               UnsafeRawPointer(bitPattern: "nodeId".hashValue)!, 
                               nodeId, 
                               .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}
