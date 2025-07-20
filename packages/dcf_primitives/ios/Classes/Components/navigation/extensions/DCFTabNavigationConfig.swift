/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

extension DCFScreenComponent {

    private func configureTabScreen(_ screenContainer: ScreenContainer, props: [String: Any]) {
        let viewController = screenContainer.viewController

        if #available(iOS 11.0, *) {
            viewController.extendedLayoutIncludesOpaqueBars = true
            viewController.edgesForExtendedLayout = .all
            viewController.automaticallyAdjustsScrollViewInsets = false
        } else {
            viewController.automaticallyAdjustsScrollViewInsets = false
        }

        if let title = props["title"] as? String {
            viewController.title = title
            viewController.tabBarItem.title = title
        }

        if let iconName = props["icon"] as? String {
            viewController.tabBarItem.image = UIImage(systemName: iconName)
        }

        if let badge = props["badge"] as? String {
            viewController.tabBarItem.badgeValue = badge
        }

        let enabled = props["enabled"] as? Bool ?? true
        viewController.tabBarItem.isEnabled = enabled

        if let index = props["index"] as? Int {
            viewController.tabBarItem.tag = index
        }

        configureNavigationBarForTabScreen(viewController, props: props)
    }

    internal func configureNavigationBarForTabScreen(
        _ viewController: UIViewController, props: [String: Any]
    ) {

        if let navigationBarTitle = props["navigationBarTitle"] as? String {
            viewController.navigationItem.title = navigationBarTitle
        }

        let largeTitleDisplayMode = props["largeTitleDisplayMode"] as? Bool ?? false
        if #available(iOS 11.0, *) {
            viewController.navigationItem.largeTitleDisplayMode =
                largeTitleDisplayMode ? .always : .never
        }

        let hideNavigationBar = props["hideNavigationBar"] as? Bool ?? false
        if hideNavigationBar {
            viewController.navigationController?.setNavigationBarHidden(
                hideNavigationBar, animated: false)
        }

        let hideBackButton = props["hideBackButton"] as? Bool ?? false
        viewController.navigationItem.hidesBackButton = hideBackButton

        if let backButtonTitle = props["backButtonTitle"] as? String {
            let backItem = UIBarButtonItem(
                title: backButtonTitle, style: .plain, target: nil, action: nil)
            viewController.navigationItem.backBarButtonItem = backItem
        }

        configureHeaderActionsFromProps(for: viewController, props: props)
    }

    private func configureHeaderActionsFromProps(
        for viewController: UIViewController, props: [String: Any]
    ) {

        if let prefixActionsData = props["prefixActions"] as? [[String: Any]] {
            let leftBarButtonItems = createBarButtonItems(
                from: prefixActionsData,
                for: viewController,
                position: .left
            )
            viewController.navigationItem.leftBarButtonItems = leftBarButtonItems
        }

        if let suffixActionsData = props["suffixActions"] as? [[String: Any]] {
            let rightBarButtonItems = createBarButtonItems(
                from: suffixActionsData,
                for: viewController,
                position: .right
            )
            viewController.navigationItem.rightBarButtonItems = rightBarButtonItems
        }
    }

    internal func storeNavigationBarConfiguration(
        _ screenContainer: ScreenContainer, props: [String: Any]
    ) {
        var navBarConfig: [String: Any] = [:]

        if let navigationBarTitle = props["navigationBarTitle"] as? String {
            navBarConfig["navigationBarTitle"] = navigationBarTitle
        }

        if let largeTitleDisplayMode = props["largeTitleDisplayMode"] as? Bool {
            navBarConfig["largeTitleDisplayMode"] = largeTitleDisplayMode
        }

        if let hideNavigationBar = props["hideNavigationBar"] as? Bool {
            navBarConfig["hideNavigationBar"] = hideNavigationBar
        }

        if let prefixActions = props["prefixActions"] as? [[String: Any]] {
            navBarConfig["prefixActions"] = prefixActions
        }

        if let suffixActions = props["suffixActions"] as? [[String: Any]] {
            navBarConfig["suffixActions"] = suffixActions
        }

        if !navBarConfig.isEmpty {
            objc_setAssociatedObject(
                screenContainer.viewController,
                UnsafeRawPointer(bitPattern: "navigationBarConfig".hashValue)!,
                navBarConfig,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}
