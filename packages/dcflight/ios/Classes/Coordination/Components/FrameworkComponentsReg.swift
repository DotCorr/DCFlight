/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import Flutter
import UIKit
import dcflight

@objc public class FrameworkComponentsReg: NSObject {
    @objc public static func registerWithRegistrar(_ registrar: FlutterPluginRegistrar) {
        registerComponents()
    }

    @objc public static func registerComponents() {
        // Register FlutterWidget component for embedding Flutter widgets
        DCFComponentRegistry.shared.registerComponent("FlutterWidget", componentClass: DCFFlutterWidgetComponent.self)
        
        // Register core framework components
        DCFComponentRegistry.shared.registerComponent("View", componentClass: DCFViewComponent.self)
        
        DCFComponentRegistry.shared.registerComponent("Text", componentClass: DCFTextComponent.self)

        DCFComponentRegistry.shared.registerComponent("ScrollView", componentClass: DCFScrollViewComponent.self)
     
        
        DCFComponentRegistry.shared.registerComponent("ScrollContentView", componentClass: DCFScrollContentViewComponent.self)
        
        DCFComponentRegistry.shared.registerComponent("Viewport", componentClass: DCFViewportComponent.self)
        
        // Register TouchableOpacity component (framework-level, used by Button)
        DCFComponentRegistry.shared.registerComponent("TouchableOpacity", componentClass: DCFTouchableOpacityComponent.self)
        
    }
}
