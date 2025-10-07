/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives

import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcf_primitives.components.*

/**
 * Registration class for DCF primitive components
 * Following iOS FrameworkComponentsReg pattern
 * All component names must match iOS exactly for cross-platform consistency
 */
object PrimitivesComponentsReg {

    /**
     * Register all primitive components with the framework
     * This should be called during app initialization
     */
    fun registerComponents() {
        val registry = DCFComponentRegistry.shared

        registry.registerComponent("View", DCFViewComponent::class.java)
        registry.registerComponent("Text", DCFTextComponent::class.java)
        registry.registerComponent("Image", DCFImageComponent::class.java)
        registry.registerComponent("TextInput", DCFTextInputComponent::class.java)
        registry.registerComponent("Button", DCFButtonComponent::class.java)
        registry.registerComponent("Toggle", DCFToggleComponent::class.java)
        registry.registerComponent("Slider", DCFSliderComponent::class.java)
        registry.registerComponent("Checkbox", DCFCheckboxComponent::class.java)
        registry.registerComponent("Spinner", DCFSpinnerComponent::class.java)
        registry.registerComponent("WebView", DCFWebViewComponent::class.java)

        registry.registerComponent("Alert", DCFAlertComponent::class.java)
        registry.registerComponent("Dropdown", DCFDropdownComponent::class.java)
        registry.registerComponent("TouchableOpacity", DCFTouchableOpacityComponent::class.java)
        registry.registerComponent("GestureDetector", DCFGestureDetectorComponent::class.java)
        registry.registerComponent("SegmentedControl", DCFSegmentedControlComponent::class.java)
        
        registry.registerComponent("Svg", DCFSvgComponent::class.java)
        registry.registerComponent("Icon", DCFIconComponent::class.java)
    }

}

