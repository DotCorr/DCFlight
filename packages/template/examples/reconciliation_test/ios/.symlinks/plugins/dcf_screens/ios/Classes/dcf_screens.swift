/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */



import UIKit
import Flutter
import dcflight

@objc public class DCFScreens: NSObject {
    @objc public static func registerWithRegistrar(_ registrar: FlutterPluginRegistrar) {
        registerComponents()
    }
    
    @objc public static func registerComponents() {
        DCFComponentRegistry.shared.registerComponent(
            "Screen", componentClass: DCFScreenComponent.self)
        DCFComponentRegistry.shared.registerComponent(
            "TabNavigator", componentClass: DCFTabNavigatorComponent.self)
        DCFComponentRegistry.shared.registerComponent(
            "StackNavigationBootstrapper",
            componentClass: DCFStackNavigationBootstrapperComponent.self)
    }
}
