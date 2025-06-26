/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import Flutter

@objc public class SysComponentsReg: NSObject {
    @objc public static func registerWithRegistrar(_ registrar: FlutterPluginRegistrar) {
        registerComponents()
    }
    
    @objc public static func registerComponents() {
        // 🧭 Register NAVIGATION components - Screen-based navigation system
        DCFComponentRegistry.shared.registerComponent("Screen", componentClass: DCFScreenComponent.self)
        DCFComponentRegistry.shared.registerComponent("TabNavigator", componentClass: DCFTabNavigatorComponent.self)
    }
}
