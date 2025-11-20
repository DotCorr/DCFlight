/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
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
        
        // Register Canvas component
        DCFComponentRegistry.shared.registerComponent(
            "Canvas",
            componentClass: DCFCanvasComponent.self
        )
        
        // Register GPU component
        DCFComponentRegistry.shared.registerComponent(
            "GPU",
            componentClass: DCFGPUComponent.self
        )
    }
}
