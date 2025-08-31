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
    @JvmStatic
    fun registerComponents() {
        val registry = DCFComponentRegistry.shared

        // Core components
        registry.registerComponent("View", DCFViewComponent::class.java)
        registry.registerComponent("Text", DCFTextComponent::class.java)
        registry.registerComponent("Image", DCFImageComponent::class.java)
        registry.registerComponent("ScrollView", DCFScrollViewComponent::class.java)

        // Input components
        registry.registerComponent("TextInput", DCFTextInputComponent::class.java)
        registry.registerComponent("Button", DCFButtonComponent::class.java)
        registry.registerComponent("Toggle", DCFToggleComponent::class.java)
        registry.registerComponent("Slider", DCFSliderComponent::class.java)
        registry.registerComponent("Checkbox", DCFCheckboxComponent::class.java)
        registry.registerComponent("Dropdown", DCFDropdownComponent::class.java)
        registry.registerComponent("SegmentedControl", DCFSegmentedControlComponent::class.java)

        // Interactive components
        registry.registerComponent("TouchableOpacity", DCFTouchableOpacityComponent::class.java)
        registry.registerComponent("GestureDetector", DCFGestureDetectorComponent::class.java)

        // Display components
        registry.registerComponent("Spinner", DCFSpinnerComponent::class.java)
        registry.registerComponent("Alert", DCFAlertComponent::class.java)
        registry.registerComponent("Icon", DCFIconComponent::class.java)
        registry.registerComponent("Svg", DCFSvgComponent::class.java)
        registry.registerComponent("WebView", DCFWebViewComponent::class.java)

        println("✅ PrimitivesComponentsReg: Registered all primitive components")
    }

    /**
     * Unregister all primitive components (useful for testing)
     */
    @JvmStatic
    fun unregisterComponents() {
        val registry = DCFComponentRegistry.shared
        val componentsToUnregister = listOf(
            "View",
            "Text",
            "Image",
            "ScrollView",
            "TextInput",
            "Button",
            "Toggle",
            "Slider",
            "Checkbox",
            "Dropdown",
            "SegmentedControl",
            "TouchableOpacity",
            "GestureDetector",
            "Spinner",
            "Alert",
            "Icon",
            "Svg",
            "WebView"
        )

        componentsToUnregister.forEach { componentType ->
            // Note: This would require adding an unregister method to DCFComponentRegistry
            // For now, just log
            println("🧹 PrimitivesComponentsReg: Unregistering $componentType")
        }
    }

    /**
     * Check if all expected primitive components are registered
     */
    @JvmStatic
    fun verifyRegistration(): Boolean {
        val expectedComponents = listOf(
            "View",
            "Text",
            "Image",
            "ScrollView",
            "TextInput",
            "Button",
            "Toggle",
            "Slider",
            "Checkbox",
            "Dropdown",
            "SegmentedControl",
            "TouchableOpacity",
            "GestureDetector",
            "Spinner",
            "Alert",
            "Icon",
            "Svg",
            "WebView"
        )

        val registry = DCFComponentRegistry.shared
        var allRegistered = true

        for (componentType in expectedComponents) {
            if (!registry.isComponentRegistered(componentType)) {
                println("⚠️ PrimitivesComponentsReg: Component '$componentType' is not registered")
                allRegistered = false
            } else {
                println("✓ PrimitivesComponentsReg: Component '$componentType' is registered")
            }
        }

        if (allRegistered) {
            println("✅ PrimitivesComponentsReg: All expected primitive components are registered")
        } else {
            println("❌ PrimitivesComponentsReg: Some components are missing")
        }

        return allRegistered
    }

    /**
     * Get list of all registered component types
     */
    @JvmStatic
    fun getRegisteredComponentTypes(): List<String> {
        return listOf(
            "View",
            "Text",
            "Image",
            "ScrollView",
            "TextInput",
            "Button",
            "Toggle",
            "Slider",
            "Checkbox",
            "Dropdown",
            "SegmentedControl",
            "TouchableOpacity",
            "GestureDetector",
            "Spinner",
            "Alert",
            "Icon",
            "Svg",
            "WebView"
        )
    }
}
