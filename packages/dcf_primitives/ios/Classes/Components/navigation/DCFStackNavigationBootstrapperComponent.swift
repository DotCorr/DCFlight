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

        DispatchQueue.main.async {
            // Set up the initial screen (wait for screens to be registered)
            self.setupInitialScreen(navigationController, initialScreen: initialScreen)

            // Set as root controller (like DCFTabNavigatorComponent does)
            replaceRoot(controller: navigationController)

            print("✅ DCFStackNavigationBootstrapperComponent: Stack navigation root ready")
        }

        // Return hidden placeholder view (matches DCFTabNavigatorComponent pattern)
        let placeholderView = UIView()
        placeholderView.isHidden = true
        placeholderView.backgroundColor = UIColor.clear

        return placeholderView
    }

    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        // Basic update support - navigation bar style changes etc.
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

    private func setupInitialScreen(
        _ navigationController: UINavigationController, initialScreen: String
    ) {
        // Find the initial screen container from DCFScreenComponent registry
        guard
            let initialScreenContainer = DCFScreenComponent.getScreenContainer(name: initialScreen)
        else {
            print(
                "❌ DCFStackNavigationBootstrapperComponent: Initial screen '\(initialScreen)' not found"
            )
            print(
                "   Available screens: \(Array(DCFScreenComponent.getAllScreenContainers().keys))")
            return
        }

        print(
            "🎯 DCFStackNavigationBootstrapperComponent: Setting up initial screen '\(initialScreen)'"
        )

        // Ensure content view is ready
        initialScreenContainer.contentView.isHidden = false
        initialScreenContainer.contentView.alpha = 1.0
        initialScreenContainer.contentView.backgroundColor = UIColor.systemBackground

        // Set as root view controller of the navigation controller
        navigationController.viewControllers = [initialScreenContainer.viewController]

        // Fire initial lifecycle events (like DCFTabNavigatorComponent does)
        propagateEvent(
            on: initialScreenContainer.contentView,
            eventName: "onAppear",
            data: ["screenName": initialScreen, "isInitial": true]
        )

        propagateEvent(
            on: initialScreenContainer.contentView,
            eventName: "onActivate",
            data: ["screenName": initialScreen, "isInitial": true]
        )

        print("✅ DCFStackNavigationBootstrapperComponent: Initial screen '\(initialScreen)' ready")
    }
}
