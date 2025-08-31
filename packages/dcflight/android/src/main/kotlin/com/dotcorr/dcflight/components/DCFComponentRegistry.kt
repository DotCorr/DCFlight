/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import java.util.concurrent.ConcurrentHashMap

/**
 * Registry for all component types
 * Following iOS DCFComponentRegistry pattern
 */
class DCFComponentRegistry private constructor() {

    companion object {
        @JvmField
        val shared = DCFComponentRegistry()
    }

    // Thread-safe map of component types
    private val componentTypes = ConcurrentHashMap<String, Class<out DCFComponent>>()

    // Map for storing component instances (for singleton components if needed)
    private val componentInstances = ConcurrentHashMap<String, DCFComponent>()

    /**
     * Register a component type handler
     */
    fun registerComponent(type: String, componentClass: Class<out DCFComponent>) {
        componentTypes[type] = componentClass
        println("✅ DCFComponentRegistry: Registered component '$type'")
    }

    /**
     * Register a component type handler (Kotlin reified version)
     */
    inline fun <reified T : DCFComponent> registerComponent(type: String) {
        registerComponent(type, T::class.java)
    }

    /**
     * Get the component handler for a specific type
     */
    fun getComponentType(type: String): Class<out DCFComponent>? {
        return componentTypes[type]
    }

    /**
     * Get the component class for tunnel calls (bridge compatibility)
     */
    fun getComponent(type: String): Class<out DCFComponent>? {
        return componentTypes[type]
    }

    /**
     * Create an instance of a component
     */
    fun createComponentInstance(type: String): DCFComponent? {
        val componentClass = componentTypes[type] ?: run {
            println("❌ DCFComponentRegistry: Component type '$type' not found")
            return null
        }

        return try {
            componentClass.getDeclaredConstructor().newInstance()
        } catch (e: Exception) {
            println("❌ DCFComponentRegistry: Failed to create instance of '$type': ${e.message}")
            e.printStackTrace()
            null
        }
    }

    /**
     * Get or create a singleton instance of a component
     */
    fun getOrCreateComponentInstance(type: String): DCFComponent? {
        // Check if we already have an instance
        componentInstances[type]?.let { return it }

        // Create a new instance
        val instance = createComponentInstance(type)
        if (instance != null) {
            componentInstances[type] = instance
        }
        return instance
    }

    /**
     * Get all registered component types
     */
    val registeredTypes: List<String>
        get() = componentTypes.keys().toList()

    /**
     * Check if a component type is registered
     */
    fun isComponentRegistered(type: String): Boolean {
        return componentTypes.containsKey(type)
    }

    /**
     * Clear all registered components (useful for testing)
     */
    fun clearAll() {
        componentTypes.clear()
        componentInstances.clear()
        println("🧹 DCFComponentRegistry: Cleared all registered components")
    }

    /**
     * Handle tunnel method calls to components
     * This is for direct component method calls from Dart that bypass the normal view lifecycle
     */
    fun handleTunnelMethod(componentType: String, method: String, params: Map<String, Any?>): Any? {
        val componentClass = getComponent(componentType) ?: run {
            println("❌ DCFComponentRegistry: Component '$componentType' not found for tunnel method")
            return null
        }

        // Try to call the static/companion object method
        return try {
            // Look for the companion object
            val companionField = componentClass.getDeclaredField("Companion")
            val companionObject = companionField.get(null)

            // Get the handleTunnelMethod from companion
            val tunnelMethod = companionObject::class.java.getMethod(
                "handleTunnelMethod",
                String::class.java,
                Map::class.java
            )

            tunnelMethod.invoke(companionObject, method, params)
        } catch (e: NoSuchFieldException) {
            // No companion object, try static method directly
            try {
                val tunnelMethod = componentClass.getDeclaredMethod(
                    "handleTunnelMethod",
                    String::class.java,
                    Map::class.java
                )
                tunnelMethod.invoke(null, method, params)
            } catch (e2: Exception) {
                println("⚠️ DCFComponentRegistry: Component '$componentType' does not implement tunnel method: $method")
                null
            }
        } catch (e: Exception) {
            println("❌ DCFComponentRegistry: Error calling tunnel method on '$componentType': ${e.message}")
            e.printStackTrace()
            null
        }
    }

    /**
     * Debug print all registered components
     */
    fun debugPrint() {
        println("📋 DCFComponentRegistry: Registered components:")
        componentTypes.forEach { (type, clazz) ->
            println("  - $type: ${clazz.simpleName}")
        }
    }
}
