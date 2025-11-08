/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

/// Color utilities for DCFlight components
public class ColorUtilities {
    
    /// Get color from hex string
    public static func color(fromHexString hexString: String) -> UIColor? {
        // Remove "dcf:" prefix if present
        var hex = hexString
        if hex.hasPrefix("dcf:") {
            hex = String(hex.dropFirst(4))
        }
        
        // Remove "#" prefix if present
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }
        
        // Validate hex string
        guard hex.count == 6 || hex.count == 8 else {
            return nil
        }
        
        var rgb: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgb) else {
            return nil
        }
        
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        
        if hex.count == 8 {
            // RGBA format
            red = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            green = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            blue = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            alpha = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            // RGB format
            red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgb & 0x0000FF) / 255.0
            alpha = 1.0
        }
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    /// Get color with explicit override fallback to semantic color
    /// Priority: explicitColor > semanticColor
    /// 
    /// - Parameters:
    ///   - explicitColor: Explicit color prop (e.g., "textColor", "placeholderColor")
    ///   - semanticColor: Semantic color prop (e.g., "primaryColor", "secondaryColor")
    ///   - props: Component props dictionary
    /// - Returns: UIColor if found, nil otherwise
    public static func getColor(
        explicitColor: String?,
        semanticColor: String?,
        from props: [String: Any]
    ) -> UIColor? {
        // Priority 1: Check explicit color prop
        if let explicitColorKey = explicitColor,
           let explicitColorStr = props[explicitColorKey] as? String {
            if let color = color(fromHexString: explicitColorStr) {
                return color
            }
        }
        
        // Priority 2: Fall back to semantic color
        if let semanticColorKey = semanticColor,
           let semanticColorStr = props[semanticColorKey] as? String {
            if let color = color(fromHexString: semanticColorStr) {
                return color
            }
        }
        
        // No color found
        return nil
    }
}
