/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import Flutter
import dcflight

@objc public class DcfPrimitives: NSObject {
    @objc public static func registerWithRegistrar(_ registrar: FlutterPluginRegistrar) {
        registerComponents()
    }
    
    @objc public static func registerComponents() {
        // Initialize method swizzling for gradient support
        UIView.performSwizzling()
        
        // Register all primitive components with the DCFlight component registry
        DCFComponentRegistry.shared.registerComponent("View", componentClass: DCFViewComponent.self)
        DCFComponentRegistry.shared.registerComponent("Button", componentClass: DCFButtonComponent.self)
        DCFComponentRegistry.shared.registerComponent("Text", componentClass: DCFTextComponent.self)
        DCFComponentRegistry.shared.registerComponent("Image", componentClass: DCFImageComponent.self)
        DCFComponentRegistry.shared.registerComponent("ScrollView", componentClass: DCFVirtualizedScrollViewComponent.self)
        DCFComponentRegistry.shared.registerComponent("FlatList", componentClass: DCFVirtualizedFlatListComponent.self)
               
        // Register new primitives
        DCFComponentRegistry.shared.registerComponent("Svg", componentClass: DCFSvgComponent.self)
        DCFComponentRegistry.shared.registerComponent("DCFIcon", componentClass: DCFIconComponent.self)
        
        // Register interaction primitives
        DCFComponentRegistry.shared.registerComponent("GestureDetector", componentClass: DCFGestureDetectorComponent.self)
        DCFComponentRegistry.shared.registerComponent("TouchableOpacity", componentClass: DCFTouchableOpacityComponent.self)
        // Register animation primitives
        DCFComponentRegistry.shared.registerComponent("AnimatedView", componentClass: DCFAnimatedViewComponent.self)
        
        // Register new cross-platform primitives
        DCFComponentRegistry.shared.registerComponent("TextInput", componentClass: DCFTextInputComponent.self)
        DCFComponentRegistry.shared.registerComponent("Dropdown", componentClass: DCFDropdownComponent.self)
        
        // 🚀 Register NEW primitive components
        DCFComponentRegistry.shared.registerComponent("Modal", componentClass: DCFModalComponent.self)
        DCFComponentRegistry.shared.registerComponent("Toggle", componentClass: DCFToggleComponent.self)
        DCFComponentRegistry.shared.registerComponent("Checkbox", componentClass: DCFCheckboxComponent.self)
        DCFComponentRegistry.shared.registerComponent("Alert", componentClass: DCFAlertComponent.self)
        DCFComponentRegistry.shared.registerComponent("SegmentedControl", componentClass: DCFSegmentedControlComponent.self)
        
        // 🚀 Register ADVANCED primitive components
        DCFComponentRegistry.shared.registerComponent("Slider", componentClass: DCFSliderComponent.self)
        DCFComponentRegistry.shared.registerComponent("Spinner", componentClass: DCFSpinnerComponent.self)
          DCFComponentRegistry.shared.registerComponent("Screen", componentClass: DCFScreenComponent.self)
        DCFComponentRegistry.shared.registerComponent("TabNavigator", componentClass: DCFTabNavigatorComponent.self)
        // 🚀 Register CRITICAL primitive components
        DCFComponentRegistry.shared.registerComponent("WebView", componentClass: DCFWebViewComponent.self)
    }
}
