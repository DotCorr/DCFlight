/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Flutter
import UIKit
import dcflight

@objc public class DcfPrimitives: NSObject {
    @objc public static func registerWithRegistrar(_ registrar: FlutterPluginRegistrar) {
        registerComponents()
    }

    @objc public static func registerComponents() {
        DCFSvgComponent.initializeSVGKit()

        // NOTE: View, Text, ScrollView, and ScrollContentView are CORE framework components
        // They are registered in FrameworkComponentsReg, NOT here!

        // Only register primitives that are NOT in the core framework
        DCFComponentRegistry.shared.registerComponent(
            "Image", componentClass: DCFImageComponent.self)

        DCFComponentRegistry.shared.registerComponent("Svg", componentClass: DCFSvgComponent.self)
        DCFComponentRegistry.shared.registerComponent(
            "DCFIcon", componentClass: DCFIconComponent.self)

        DCFComponentRegistry.shared.registerComponent(
            "GestureDetector", componentClass: DCFGestureDetectorComponent.self)
        DCFComponentRegistry.shared.registerComponent(
            "TextInput", componentClass: DCFTextInputComponent.self)
        DCFComponentRegistry.shared.registerComponent(
            "Dropdown", componentClass: DCFDropdownComponent.self)

        DCFComponentRegistry.shared.registerComponent(
            "Toggle", componentClass: DCFToggleComponent.self)
        DCFComponentRegistry.shared.registerComponent(
            "Checkbox", componentClass: DCFCheckboxComponent.self)
        DCFComponentRegistry.shared.registerComponent(
            "Alert", componentClass: DCFAlertComponent.self)
        DCFComponentRegistry.shared.registerComponent(
            "SegmentedControl", componentClass: DCFSegmentedControlComponent.self)

        DCFComponentRegistry.shared.registerComponent(
            "Slider", componentClass: DCFSliderComponent.self)
        DCFComponentRegistry.shared.registerComponent(
            "Spinner", componentClass: DCFSpinnerComponent.self)
        
        DCFComponentRegistry.shared.registerComponent(
            "WebView", componentClass: DCFWebViewComponent.self)
        // Canvas component not needed - using WidgetToDCFAdaptor with CustomPaint directly
        // DCFComponentRegistry.shared.registerComponent(
        //     "Canvas", componentClass: DCFCanvasComponent.self)
    }
}

