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

  
}



