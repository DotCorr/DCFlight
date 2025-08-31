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
 */
object PrimitivesComponentsReg {

    /**
     * Register all primitive components with the framework
     * This should be called during app initialization
     */
    @JvmStatic
    fun registerComponents() {
        // Register View component
        DCFComponentRegistry.shared.registerComponent("View", DCFViewComponent::class.java)

        // Register Text component
        DCFComponentRegistry.shared.registerComponent("Text", DCFTextComponent::class.java)

        // Register Image component
        DCFComponentRegistry.shared.registerComponent("Image", DCFImageComponent::class.java)

        // Register ScrollView component
        DCFComponentRegistry.shared.registerComponent("ScrollView", DCFScrollViewComponent::class.java)

        // Register Button component
        DCFComponentRegistry.shared.registerComponent("Button", DCFButtonComponent::class.java)

        // Register TextInput component
        DCFComponentRegistry.shared.registerComponent("TextInput", DCFTextInputComponent::class.java)

        // Register additional primitive components as needed
        // DCFComponentRegistry.shared.registerComponent("Switch", DCFSwitchComponent::class.java)
        // DCFComponentRegistry.shared.registerComponent("Slider", DCFSliderComponent::class.java)
        // DCFComponentRegistry.shared.registerComponent("ActivityIndicator", DCFActivityIndicatorComponent::class.java)

        println("✅ PrimitivesComponentsReg: Registered all primitive components")
    }

    /**
     * Unregister all primitive components (useful for testing)
     */
    @JvmStatic
    fun unregisterComponents() {
        // This would require adding an unregister method to DCFComponentRegistry
        // For now, just log
        println("🧹 PrimitivesComponentsReg: Unregistering components not yet implemented")
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
            "Button",
            "TextInput"
        )

        val registry = DCFComponentRegistry.shared
        var allRegistered = true

        for (componentType in expectedComponents) {
            if (!registry.isComponentRegistered(componentType)) {
                println("⚠️ PrimitivesComponentsReg: Component '$componentType' is not registered")
                allRegistered = false
            }
        }

        if (allRegistered) {
            println("✅ PrimitivesComponentsReg: All expected primitive components are registered")
        }

        return allRegistered
    }
}
