/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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
