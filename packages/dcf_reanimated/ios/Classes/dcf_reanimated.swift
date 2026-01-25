/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit
import Flutter
import dcflight

@objc public class DcfReanimated: NSObject {
    @objc public static func registerWithRegistrar(_ registrar: FlutterPluginRegistrar) {
        registerComponents()
    }
    
    @objc public static func registerComponents() {
        // Register ReanimatedView
        DCFComponentRegistry.shared.registerComponent(
            "ReanimatedView",
            componentClass: DCFAnimatedViewComponent.self
        )
    }
}
