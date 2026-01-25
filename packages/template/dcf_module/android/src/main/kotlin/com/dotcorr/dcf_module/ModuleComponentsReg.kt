/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_module

import com.dotcorr.dcflight.components.DCFComponentRegistry

/**
 * Registration class for DCF module components.
 * 
 * Register your module's components here.
 * All component names must match iOS exactly for cross-platform consistency.
 */
object ModuleComponentsReg {

    /**
     * Register all module components with the framework.
     * This should be called during app initialization.
     */
    fun registerComponents() {
        val registry = DCFComponentRegistry.shared

        registry.registerComponent("View", com.dotcorr.dcf_module.components.DCFViewComponent::class.java)
        registry.registerComponent("Text", com.dotcorr.dcf_module.components.DCFTextComponent::class.java)
        registry.registerComponent("Svg", com.dotcorr.dcf_module.components.DCFSvgComponent::class.java)
        registry.registerComponent("DCFIcon", com.dotcorr.dcf_module.components.DCFIconComponent::class.java)
    }
}

