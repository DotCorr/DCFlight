/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives

import com.dotcorr.dcflight.components.DCFComponentRegistry
import com.dotcorr.dcf_primitives.components.*

object PrimitivesComponentsReg {

    /**
     * Register all primitive components with the framework
     * This should be called during app initialization
     */
    fun registerComponents() {
        val registry = DCFComponentRegistry.shared

        // NOTE: View, Text, and ScrollView are CORE framework components
        // They are registered in FrameworkComponentsReg, NOT here!
        // Only register primitives that are NOT in the core framework
        registry.registerComponent("Image", DCFImageComponent::class.java)
        registry.registerComponent("TextInput", DCFTextInputComponent::class.java)
        registry.registerComponent("Toggle", DCFToggleComponent::class.java)
        registry.registerComponent("Slider", DCFSliderComponent::class.java)
        registry.registerComponent("Checkbox", DCFCheckboxComponent::class.java)
        registry.registerComponent("Spinner", DCFSpinnerComponent::class.java)
        registry.registerComponent("WebView", DCFWebViewComponent::class.java)

        registry.registerComponent("Alert", DCFAlertComponent::class.java)
        registry.registerComponent("Dropdown", DCFDropdownComponent::class.java)
        registry.registerComponent("GestureDetector", DCFGestureDetectorComponent::class.java)
        registry.registerComponent("SegmentedControl", DCFSegmentedControlComponent::class.java)
        
        registry.registerComponent("Svg", DCFSvgComponent::class.java)
        registry.registerComponent("DCFIcon", DCFIconComponent::class.java)
        // Canvas component not needed - using WidgetToDCFAdaptor with CustomPaint directly
        // registry.registerComponent("Canvas", DCFCanvasComponent::class.java)
    }

}

