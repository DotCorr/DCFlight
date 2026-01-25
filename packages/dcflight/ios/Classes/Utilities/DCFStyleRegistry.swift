/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import Foundation

/// Style registry for caching styles by numeric ID.
///
/// This enables efficient style management by allowing styles to be referenced
/// by numeric IDs instead of sending full style objects on every update.
///
/// **Usage:**
/// ```swift
/// // Register a style
/// let styleId = DCFStyleRegistry.shared.register(style: styleDict)
///
/// // Retrieve a style by ID
/// if let style = DCFStyleRegistry.shared.get(styleId: 1) {
///     view.applyStyles(props: style)
/// }
/// ```
///
/// **Benefits:**
/// - Reduces bridge traffic by sending IDs instead of full objects
/// - Enables style deduplication across views
/// - Improves performance for frequently reused styles
class DCFStyleRegistry {
    /// Shared singleton instance
    static let shared = DCFStyleRegistry()
    
    /// Maps numeric style ID -> style dictionary
    private var styles: [Int: [String: Any]] = [:]
    
    /// Maps style dictionary hash -> numeric ID (for deduplication)
    private var styleToId: [Int: Int] = [:]
    
    /// Next available numeric ID
    private var nextId: Int = 1
    
    private init() {}
    
    /// Register a style and return its numeric ID.
    ///
    /// If an identical style is already registered, returns the existing ID.
    /// This enables automatic style deduplication.
    ///
    /// - Parameter style: Style dictionary to register
    /// - Returns: Numeric ID for the registered style
    @discardableResult
    func register(style: [String: Any]) -> Int {
        // Create hash of style for deduplication
        let styleHash = styleHashValue(style)
        
        // Check if identical style already exists
        if let existingId = styleToId[styleHash] {
            return existingId
        }
        
        // Generate new numeric ID
        let id = nextId
        nextId += 1
        
        // Store style and hash mapping
        styles[id] = style
        styleToId[styleHash] = id
        
        return id
    }
    
    /// Get style by numeric ID.
    ///
    /// - Parameter styleId: Numeric ID of the style
    /// - Returns: Style dictionary if found, nil otherwise
    func get(styleId: Int) -> [String: Any]? {
        return styles[styleId]
    }
    
    /// Check if a style ID exists in the registry.
    ///
    /// - Parameter styleId: Numeric ID to check
    /// - Returns: True if style exists, false otherwise
    func has(styleId: Int) -> Bool {
        return styles[styleId] != nil
    }
    
    /// Remove a style from the registry.
    ///
    /// - Parameter styleId: Numeric ID of the style to remove
    func remove(styleId: Int) {
        if let style = styles[styleId] {
            let styleHash = styleHashValue(style)
            styles.removeValue(forKey: styleId)
            styleToId.removeValue(forKey: styleHash)
        }
    }
    
    /// Clear all registered styles (for testing/debugging).
    func clear() {
        styles.removeAll()
        styleToId.removeAll()
        nextId = 1
    }
    
    /// Create a hash value for a style dictionary.
    ///
    /// This is used for style deduplication - identical styles get the same hash.
    /// - Parameter style: Style dictionary to hash
    /// - Returns: Hash value for the style
    private func styleHashValue(_ style: [String: Any]) -> Int {
        // Create a deterministic hash from style keys and values
        var hasher = Hasher()
        
        // Sort keys for consistent hashing
        let sortedKeys = style.keys.sorted()
        for key in sortedKeys {
            hasher.combine(key)
            if let value = style[key] {
                hasher.combine(String(describing: value))
            }
        }
        
        return hasher.finalize()
    }
}

/// Resolve style props, handling both direct style objects and style IDs.
///
/// If props contain a "styleId" key, resolves it to the full style dictionary.
/// Otherwise, returns the props as-is.
///
/// **Usage:**
/// ```swift
/// let resolvedProps = resolveStyleProps(props: props)
/// view.applyStyles(props: resolvedProps)
/// ```
///
/// - Parameter props: Props dictionary that may contain a "styleId" key
/// - Returns: Resolved props with style ID expanded to full style object
func resolveStyleProps(props: [String: Any]) -> [String: Any] {
    // Check if props contain a style ID
    if let styleId = props["styleId"] as? Int {
        // Resolve style ID to full style object
        if let style = DCFStyleRegistry.shared.get(styleId: styleId) {
            // Merge resolved style with other props (other props take precedence)
            var resolved = style
            for (key, value) in props {
                if key != "styleId" {
                    resolved[key] = value
                }
            }
            return resolved
        }
    }
    
    // No style ID or style not found - return props as-is
    return props
}
