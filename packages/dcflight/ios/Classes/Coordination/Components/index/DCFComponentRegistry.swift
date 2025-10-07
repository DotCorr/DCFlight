/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

/// Registry for all component types
public class DCFComponentRegistry {
    public static let shared = DCFComponentRegistry()
    
    internal var componentTypes: [String: DCFComponent.Type] = [:]
    
    private init() {
    }
    
    /// Register a component type handler
    public func registerComponent(_ type: String, componentClass: DCFComponent.Type) {
        componentTypes[type] = componentClass
    }
    
    /// Get the component handler for a specific type
    func getComponentType(for type: String) -> DCFComponent.Type? {
        return componentTypes[type]
    }
    
    /// Get the component class for tunnel calls (bridge compatibility)
    func getComponent(_ type: String) -> DCFComponent.Type? {
        return componentTypes[type]
    }
    
    /// Get all registered component types
    var registeredTypes: [String] {
        return Array(componentTypes.keys)
    }
}

