/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcflight.components

import android.content.Context
import android.util.Log
import android.view.View
import java.util.concurrent.ConcurrentHashMap

/**
 * Registry for all DCFlight component types
 * Manages component registration and creation
 */

// Type alias for component factory function - must be at top level
typealias ComponentFactory = (props: Map<String, Any?>) -> DCFComponent

class DCFComponentRegistry private constructor() {

    companion object {
        private const val TAG = "DCFComponentRegistry"

        @JvmField
        val shared = DCFComponentRegistry()
    }

    // Thread-safe map of component factories
    private val componentFactories = ConcurrentHashMap<String, ComponentFactory>()

    // Map for storing component instances by ID
    private val componentInstances = ConcurrentHashMap<String, DCFComponent>()

    /**
     * Initialize the component registry
     */
    fun initialize() {
        // Clear any existing registrations
        componentFactories.clear()
        componentInstances.clear()
        Log.d(TAG, "Component registry initialized")
    }

    /**
     * Register a component type with a factory function
     */
    fun registerComponent(type: String, factory: ComponentFactory) {
        componentFactories[type] = factory
        Log.d(TAG, "Registered component type: $type")
    }

    /**
     * Register a component type with a class (for backward compatibility)
     */
    fun registerComponent(type: String, componentClass: Class<out DCFComponent>) {
        registerComponent(type) { props ->
            try {
                val constructor = componentClass.getConstructor(Map::class.java)
                constructor.newInstance(props)
            } catch (e: NoSuchMethodException) {
                // Try no-arg constructor
                val instance = componentClass.getDeclaredConstructor().newInstance()
                instance.applyProperties(props)
                instance
            }
        }
    }

    /**
     * Unregister a component type
     */
    fun unregisterComponent(type: String) {
        componentFactories.remove(type)
        Log.d(TAG, "Unregistered component type: $type")
    }

    /**
     * Unregister all components
     */
    fun unregisterAllComponents() {
        componentFactories.clear()
        componentInstances.clear()
        Log.d(TAG, "All components unregistered")
    }

    /**
     * Check if a component type is registered
     */
    fun isComponentRegistered(type: String): Boolean {
        return componentFactories.containsKey(type)
    }

    /**
     * Get the count of registered component types
     */
    fun getRegisteredComponentCount(): Int {
        return componentFactories.size
    }

    /**
     * Get a list of all registered component type names
     */
    fun getRegisteredComponentNames(): List<String> {
        return componentFactories.keys.toList()
    }

    /**
     * Create a component instance
     */
    fun createComponentInstance(type: String): DCFComponent? {
        val factory = componentFactories[type]
        if (factory == null) {
            Log.e(TAG, "No factory registered for component type: $type")
            return null
        }

        return try {
            factory(emptyMap())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create component instance of type: $type", e)
            null
        }
    }

    /**
     * Create a component with view
     */
    fun createComponent(
        type: String,
        properties: Map<String, Any?>,
        context: Context
    ): View? {
        Log.d(TAG, "Creating component of type: $type")

        val factory = componentFactories[type]
        if (factory == null) {
            Log.e(TAG, "No factory registered for component type: $type")
            return null
        }

        return try {
            val component = factory(properties)

            // Store instance if it has an ID
            val componentId = properties["id"] as? String
            if (componentId != null) {
                componentInstances[componentId] = component
            }

            // Create and configure the view
            val view = component.createView(context)
            component.bindView(view)
            component.applyProperties(properties)

            Log.d(TAG, "Component created successfully: $type")
            view
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create component of type: $type", e)
            null
        }
    }

    /**
     * Get a component instance by ID
     */
    fun getComponentById(id: String): DCFComponent? {
        return componentInstances[id]
    }

    /**
     * Update a component's properties
     */
    fun updateComponent(id: String, properties: Map<String, Any?>): Boolean {
        val component = componentInstances[id]
        if (component == null) {
            Log.w(TAG, "Component not found with ID: $id")
            return false
        }

        try {
            component.updateProperties(properties)
            Log.d(TAG, "Component updated: $id")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update component: $id", e)
            return false
        }
    }

    /**
     * Remove a component instance
     */
    fun removeComponent(id: String): Boolean {
        val component = componentInstances.remove(id)
        if (component != null) {
            component.cleanup()
            Log.d(TAG, "Component removed: $id")
            return true
        }
        return false
    }

    /**
     * Remove all component instances
     */
    fun removeAllComponents() {
        componentInstances.forEach { (_, component) ->
            component.cleanup()
        }
        componentInstances.clear()
        Log.d(TAG, "All component instances removed")
    }

    /**
     * Get all component instances
     */
    fun getAllComponents(): Map<String, DCFComponent> {
        return componentInstances.toMap()
    }

    /**
     * Get component statistics for debugging
     */
    fun getStatistics(): Map<String, Any> {
        return mapOf(
            "registeredTypes" to componentFactories.size,
            "activeInstances" to componentInstances.size,
            "types" to getRegisteredComponentNames()
        )
    }

    /**
     * Cleanup the registry
     */
    fun cleanup() {
        removeAllComponents()
        unregisterAllComponents()
        Log.d(TAG, "Component registry cleaned up")
    }
}
