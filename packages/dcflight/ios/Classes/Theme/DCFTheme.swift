/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

/// Unified theme system for DCFlight iOS
/// Provides single API for all theme operations (matches Android DCFTheme)
public class DCFTheme {
    
    /// Check if current theme is dark mode
    public static func isDarkTheme(traitCollection: UITraitCollection = UITraitCollection.current) -> Bool {
        return traitCollection.userInterfaceStyle == .dark
    }
    
    /// Get system text color (adapts to light/dark mode)
    public static func getTextColor(traitCollection: UITraitCollection = UITraitCollection.current) -> UIColor {
        return UIColor.label
    }
    
    /// Get system background color (adapts to light/dark mode)
    public static func getBackgroundColor(traitCollection: UITraitCollection = UITraitCollection.current) -> UIColor {
        return UIColor.systemBackground
    }
    
    /// Get system surface color (adapts to light/dark mode)
    public static func getSurfaceColor(traitCollection: UITraitCollection = UITraitCollection.current) -> UIColor {
        return UIColor.secondarySystemBackground
    }
    
    /// Get system accent color
    public static func getAccentColor(traitCollection: UITraitCollection = UITraitCollection.current) -> UIColor {
        return UIColor.systemBlue
    }
    
    /// Get secondary text color (adapts to light/dark mode)
    public static func getSecondaryTextColor(traitCollection: UITraitCollection = UITraitCollection.current) -> UIColor {
        return UIColor.secondaryLabel
    }
    
    /// Get all theme colors as a dictionary (for Dart bridge)
    public static func getAllColors(traitCollection: UITraitCollection = UITraitCollection.current) -> [String: Any] {
        let isDark = isDarkTheme(traitCollection: traitCollection)
        let textColor = getTextColor(traitCollection: traitCollection)
        let backgroundColor = getBackgroundColor(traitCollection: traitCollection)
        let surfaceColor = getSurfaceColor(traitCollection: traitCollection)
        let accentColor = getAccentColor(traitCollection: traitCollection)
        let secondaryTextColor = getSecondaryTextColor(traitCollection: traitCollection)
        
        return [
            "isDark": isDark ? 1 : 0,
            "textColor": colorToHex(textColor),
            "backgroundColor": colorToHex(backgroundColor),
            "surfaceColor": colorToHex(surfaceColor),
            "accentColor": colorToHex(accentColor),
            "secondaryTextColor": colorToHex(secondaryTextColor)
        ]
    }
    
    /// Convert UIColor to hex string
    private static func colorToHex(_ color: UIColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        let a = Int(alpha * 255)
        
        return String(format: "#%02X%02X%02X%02X", a, r, g, b)
    }
}

