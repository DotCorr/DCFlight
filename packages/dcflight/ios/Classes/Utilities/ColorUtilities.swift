/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import UIKit

/// Utilities for color conversion
public class ColorUtilities {

    /// Convert a hex string to a UIColor
    /// Format: "#RRGGBB" or "#RRGGBBAA" or "#AARRGGBB" (Android format)
    /// Also supports DCFColors format: "dcf:black", "dcf:transparent", "dcf:#RRGGBB"
    public static func color(fromHexString hexString: String) -> UIColor? {
        
        var cleanHexString = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle DCFColors prefix: "dcf:black", "dcf:transparent", "dcf:#RRGGBB"
        if cleanHexString.hasPrefix("dcf:") {
            let dcfColor = String(cleanHexString.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Explicit black - distinguish from transparent
            if dcfColor.lowercased() == "black" {
                return UIColor.black
            }
            
            // Explicit transparent
            if dcfColor.lowercased() == "transparent" || dcfColor.lowercased() == "clear" {
                return UIColor.clear
            }
            
            // DCF hex colors: "dcf:#RRGGBB" or "dcf:#AARRGGBB"
            if dcfColor.hasPrefix("#") {
                cleanHexString = dcfColor // Remove dcf: prefix, keep #
            } else {
                // Try as named color
                return getDCFNamedColor(dcfColor.lowercased())
            }
        }

        if cleanHexString.lowercased() == "transparent" || cleanHexString.lowercased() == "clear" {
            return UIColor.clear
        }

        if cleanHexString.contains("Color(") && cleanHexString.contains("alpha:") {
            return parseFlutterColorObject(cleanHexString)
        }

        if let intValue = Int(cleanHexString), intValue >= 0 {

            if intValue == 0 {
                return UIColor.clear
            }

            let hexValue = String(format: "#%08x", intValue)
            cleanHexString = hexValue
        }

        cleanHexString = cleanHexString.replacingOccurrences(of: "#", with: "")

        if let namedColor = getNamedColor(cleanHexString.lowercased()) {
            return namedColor
        }

        if cleanHexString.count == 3 {
            let r = String(cleanHexString[cleanHexString.startIndex])
            let g = String(
                cleanHexString[cleanHexString.index(cleanHexString.startIndex, offsetBy: 1)])
            let b = String(
                cleanHexString[cleanHexString.index(cleanHexString.startIndex, offsetBy: 2)])
            cleanHexString = r + r + g + g + b + b
        }

        var rgbValue: UInt64 = 0
        Scanner(string: cleanHexString).scanHexInt64(&rgbValue)

        var alpha: CGFloat = 1.0
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0

        switch cleanHexString.count {
        case 8:  // 8 characters: AARRGGBB format used by Flutter
            alpha = CGFloat((rgbValue >> 24) & 0xFF) / 255.0
            red = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
            green = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
            blue = CGFloat(rgbValue & 0xFF) / 255.0

            if alpha == 0 {
                return UIColor.clear
            }

        case 6:  // 6 characters: RRGGBB
            red = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
            green = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
            blue = CGFloat(rgbValue & 0xFF) / 255.0
            alpha = 1.0

            if red == 0 && green == 0 && blue == 0
                && (hexString.contains("transparent") || hexString.contains("00000"))
            {
                return UIColor.clear
            }

        default:
            return .magenta  // Return a bright color to make issues obvious
        }

        let color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
        return color
    }

    /// CRITICAL FIX: Centralized named color handling
    private static func getNamedColor(_ colorName: String) -> UIColor? {
        switch colorName {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "black": return .black
        case "white": return .white
        case "yellow": return .yellow
        case "purple": return .purple
        case "orange": return .orange
        case "cyan": return .cyan
        case "clear", "transparent": return .clear
        case "gray", "grey": return .gray
        case "lightgray", "lightgrey": return .lightGray
        case "darkgray", "darkgrey": return .darkGray
        case "brown": return .brown
        case "magenta": return .magenta
        default: return nil
        }
    }
    
    /// DCFColors named color handling - comprehensive color palette
    private static func getDCFNamedColor(_ colorName: String) -> UIColor? {
        switch colorName {
        // Base
        case "black": return .black
        case "white": return .white
        case "transparent", "clear": return .clear
        
        // Grays
        case "gray50", "grey50": return UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
        case "gray100", "grey100": return UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
        case "gray200", "grey200": return UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.0)
        case "gray300", "grey300": return UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0)
        case "gray400", "grey400": return UIColor(red: 0.74, green: 0.74, blue: 0.74, alpha: 1.0)
        case "gray500", "grey500": return UIColor(red: 0.62, green: 0.62, blue: 0.62, alpha: 1.0)
        case "gray600", "grey600": return UIColor(red: 0.46, green: 0.46, blue: 0.46, alpha: 1.0)
        case "gray700", "grey700": return UIColor(red: 0.38, green: 0.38, blue: 0.38, alpha: 1.0)
        case "gray800", "grey800": return UIColor(red: 0.26, green: 0.26, blue: 0.26, alpha: 1.0)
        case "gray900", "grey900": return UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0)
        case "lightgray", "lightgrey": return UIColor(red: 0.83, green: 0.83, blue: 0.83, alpha: 1.0)
        case "darkgray", "darkgrey": return UIColor(red: 0.66, green: 0.66, blue: 0.66, alpha: 1.0)
        
        // Blues
        case "blue": return UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // #007AFF
        case "blue50": return UIColor(red: 0.89, green: 0.95, blue: 0.99, alpha: 1.0)
        case "blue100": return UIColor(red: 0.73, green: 0.87, blue: 0.98, alpha: 1.0)
        case "blue200": return UIColor(red: 0.56, green: 0.79, blue: 0.98, alpha: 1.0)
        case "blue300": return UIColor(red: 0.39, green: 0.71, blue: 0.96, alpha: 1.0)
        case "blue400": return UIColor(red: 0.26, green: 0.65, blue: 0.96, alpha: 1.0)
        case "blue500": return UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0)
        case "blue600": return UIColor(red: 0.12, green: 0.53, blue: 0.90, alpha: 1.0)
        case "blue700": return UIColor(red: 0.10, green: 0.46, blue: 0.82, alpha: 1.0)
        case "blue800": return UIColor(red: 0.08, green: 0.40, blue: 0.75, alpha: 1.0)
        case "blue900": return UIColor(red: 0.05, green: 0.28, blue: 0.63, alpha: 1.0)
        case "lightblue": return UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1.0)
        case "darkblue": return UIColor(red: 0.0, green: 0.32, blue: 0.84, alpha: 1.0)
        case "blueaccent": return UIColor(red: 0.27, green: 0.54, blue: 1.0, alpha: 1.0)
        case "indigo": return UIColor(red: 0.25, green: 0.32, blue: 0.71, alpha: 1.0)
        case "indigoaccent": return UIColor(red: 0.33, green: 0.43, blue: 1.0, alpha: 1.0)
        
        // Reds
        case "red": return UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0) // #FF3B30
        case "red50": return UIColor(red: 0.94, green: 0.92, blue: 0.91, alpha: 1.0)
        case "red100": return UIColor(red: 1.0, green: 0.80, blue: 0.82, alpha: 1.0)
        case "red200": return UIColor(red: 0.94, green: 0.60, blue: 0.60, alpha: 1.0)
        case "red300": return UIColor(red: 0.90, green: 0.45, blue: 0.45, alpha: 1.0)
        case "red400": return UIColor(red: 0.94, green: 0.33, blue: 0.31, alpha: 1.0)
        case "red500": return UIColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0)
        case "red600": return UIColor(red: 0.90, green: 0.22, blue: 0.21, alpha: 1.0)
        case "red700": return UIColor(red: 0.83, green: 0.18, blue: 0.18, alpha: 1.0)
        case "red800": return UIColor(red: 0.78, green: 0.16, blue: 0.16, alpha: 1.0)
        case "red900": return UIColor(red: 0.72, green: 0.11, blue: 0.11, alpha: 1.0)
        case "lightred": return UIColor(red: 1.0, green: 0.41, blue: 0.38, alpha: 1.0)
        case "darkred": return UIColor(red: 0.80, green: 0.0, blue: 0.0, alpha: 1.0)
        case "redaccent": return UIColor(red: 1.0, green: 0.32, blue: 0.32, alpha: 1.0)
        case "pink": return UIColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 1.0)
        case "pinkaccent": return UIColor(red: 1.0, green: 0.25, blue: 0.51, alpha: 1.0)
        
        // Greens
        case "green": return UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0) // #34C759
        case "green50": return UIColor(red: 0.91, green: 0.96, blue: 0.91, alpha: 1.0)
        case "green100": return UIColor(red: 0.78, green: 0.90, blue: 0.79, alpha: 1.0)
        case "green200": return UIColor(red: 0.65, green: 0.84, blue: 0.65, alpha: 1.0)
        case "green300": return UIColor(red: 0.51, green: 0.78, blue: 0.51, alpha: 1.0)
        case "green400": return UIColor(red: 0.40, green: 0.73, blue: 0.42, alpha: 1.0)
        case "green500": return UIColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0)
        case "green600": return UIColor(red: 0.26, green: 0.63, blue: 0.28, alpha: 1.0)
        case "green700": return UIColor(red: 0.22, green: 0.56, blue: 0.24, alpha: 1.0)
        case "green800": return UIColor(red: 0.18, green: 0.49, blue: 0.20, alpha: 1.0)
        case "green900": return UIColor(red: 0.11, green: 0.37, blue: 0.13, alpha: 1.0)
        case "lightgreen": return UIColor(red: 0.56, green: 0.93, blue: 0.56, alpha: 1.0)
        case "darkgreen": return UIColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1.0)
        case "greenaccent": return UIColor(red: 0.41, green: 0.94, blue: 0.68, alpha: 1.0)
        case "teal": return UIColor(red: 0.0, green: 0.59, blue: 0.53, alpha: 1.0)
        case "tealaccent": return UIColor(red: 0.39, green: 1.0, blue: 0.85, alpha: 1.0)
        
        // Yellows & Oranges
        case "yellow": return UIColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1.0) // #FFCC00
        case "yellow50": return UIColor(red: 1.0, green: 0.99, blue: 0.91, alpha: 1.0)
        case "yellow100": return UIColor(red: 1.0, green: 0.98, blue: 0.77, alpha: 1.0)
        case "yellow200": return UIColor(red: 1.0, green: 0.96, blue: 0.62, alpha: 1.0)
        case "yellow300": return UIColor(red: 1.0, green: 0.95, blue: 0.46, alpha: 1.0)
        case "yellow400": return UIColor(red: 1.0, green: 0.93, blue: 0.35, alpha: 1.0)
        case "yellow500": return UIColor(red: 1.0, green: 0.92, blue: 0.23, alpha: 1.0)
        case "yellow600": return UIColor(red: 0.99, green: 0.85, blue: 0.21, alpha: 1.0)
        case "yellow700": return UIColor(red: 0.98, green: 0.75, blue: 0.18, alpha: 1.0)
        case "yellow800": return UIColor(red: 0.98, green: 0.66, blue: 0.15, alpha: 1.0)
        case "yellow900": return UIColor(red: 0.96, green: 0.50, blue: 0.09, alpha: 1.0)
        case "lightyellow": return UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
        case "darkyellow": return UIColor(red: 0.80, green: 0.60, blue: 0.0, alpha: 1.0)
        case "orange": return UIColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0) // #FF9500
        case "orange50": return UIColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 1.0)
        case "orange100": return UIColor(red: 1.0, green: 0.88, blue: 0.70, alpha: 1.0)
        case "orange200": return UIColor(red: 1.0, green: 0.80, blue: 0.50, alpha: 1.0)
        case "orange300": return UIColor(red: 1.0, green: 0.72, blue: 0.30, alpha: 1.0)
        case "orange400": return UIColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0)
        case "orange500": return UIColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1.0)
        case "orange600": return UIColor(red: 0.98, green: 0.55, blue: 0.0, alpha: 1.0)
        case "orange700": return UIColor(red: 0.96, green: 0.49, blue: 0.0, alpha: 1.0)
        case "orange800": return UIColor(red: 0.94, green: 0.42, blue: 0.0, alpha: 1.0)
        case "orange900": return UIColor(red: 0.90, green: 0.32, blue: 0.0, alpha: 1.0)
        case "lightorange": return UIColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0)
        case "darkorange": return UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1.0)
        case "orangeaccent": return UIColor(red: 1.0, green: 0.67, blue: 0.25, alpha: 1.0)
        case "deeporange": return UIColor(red: 1.0, green: 0.34, blue: 0.13, alpha: 1.0)
        case "deeporangeaccent": return UIColor(red: 1.0, green: 0.43, blue: 0.25, alpha: 1.0)
        case "amber": return UIColor(red: 1.0, green: 0.76, blue: 0.03, alpha: 1.0)
        case "amberaccent": return UIColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 1.0)
        
        // Purples
        case "purple": return UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0) // #AF52DE
        case "purple50": return UIColor(red: 0.95, green: 0.90, blue: 0.96, alpha: 1.0)
        case "purple100": return UIColor(red: 0.88, green: 0.75, blue: 0.91, alpha: 1.0)
        case "purple200": return UIColor(red: 0.81, green: 0.58, blue: 0.85, alpha: 1.0)
        case "purple300": return UIColor(red: 0.73, green: 0.41, blue: 0.78, alpha: 1.0)
        case "purple400": return UIColor(red: 0.67, green: 0.28, blue: 0.74, alpha: 1.0)
        case "purple500": return UIColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1.0)
        case "purple600": return UIColor(red: 0.56, green: 0.14, blue: 0.67, alpha: 1.0)
        case "purple700": return UIColor(red: 0.48, green: 0.12, blue: 0.64, alpha: 1.0)
        case "purple800": return UIColor(red: 0.42, green: 0.11, blue: 0.60, alpha: 1.0)
        case "purple900": return UIColor(red: 0.29, green: 0.08, blue: 0.55, alpha: 1.0)
        case "lightpurple": return UIColor(red: 0.85, green: 0.44, blue: 0.84, alpha: 1.0)
        case "darkpurple": return UIColor(red: 0.55, green: 0.0, blue: 0.55, alpha: 1.0)
        case "purpleaccent": return UIColor(red: 0.88, green: 0.25, blue: 0.98, alpha: 1.0)
        case "deeppurple": return UIColor(red: 0.40, green: 0.23, blue: 0.72, alpha: 1.0)
        case "deeppurpleaccent": return UIColor(red: 0.49, green: 0.30, blue: 1.0, alpha: 1.0)
        case "violet": return UIColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1.0)
        
        // Cyans
        case "cyan": return UIColor(red: 0.0, green: 0.74, blue: 0.83, alpha: 1.0)
        case "cyan50": return UIColor(red: 0.88, green: 0.97, blue: 0.98, alpha: 1.0)
        case "cyan100": return UIColor(red: 0.70, green: 0.92, blue: 0.95, alpha: 1.0)
        case "cyan200": return UIColor(red: 0.50, green: 0.87, blue: 0.92, alpha: 1.0)
        case "cyan300": return UIColor(red: 0.30, green: 0.82, blue: 0.88, alpha: 1.0)
        case "cyan400": return UIColor(red: 0.15, green: 0.78, blue: 0.85, alpha: 1.0)
        case "cyan500": return UIColor(red: 0.0, green: 0.74, blue: 0.83, alpha: 1.0)
        case "cyan600": return UIColor(red: 0.0, green: 0.67, blue: 0.76, alpha: 1.0)
        case "cyan700": return UIColor(red: 0.0, green: 0.59, blue: 0.65, alpha: 1.0)
        case "cyan800": return UIColor(red: 0.0, green: 0.51, blue: 0.56, alpha: 1.0)
        case "cyan900": return UIColor(red: 0.0, green: 0.38, blue: 0.39, alpha: 1.0)
        case "cyanaccent": return UIColor(red: 0.09, green: 1.0, blue: 1.0, alpha: 1.0)
        case "turquoise": return UIColor(red: 0.25, green: 0.88, blue: 0.82, alpha: 1.0)
        case "aqua": return UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
        
        // Browns
        case "brown": return UIColor(red: 0.47, green: 0.33, blue: 0.28, alpha: 1.0)
        case "brown50": return UIColor(red: 0.94, green: 0.92, blue: 0.91, alpha: 1.0)
        case "brown100": return UIColor(red: 0.84, green: 0.80, blue: 0.78, alpha: 1.0)
        case "brown200": return UIColor(red: 0.74, green: 0.67, blue: 0.64, alpha: 1.0)
        case "brown300": return UIColor(red: 0.63, green: 0.53, blue: 0.50, alpha: 1.0)
        case "brown400": return UIColor(red: 0.55, green: 0.43, blue: 0.39, alpha: 1.0)
        case "brown500": return UIColor(red: 0.47, green: 0.33, blue: 0.28, alpha: 1.0)
        case "brown600": return UIColor(red: 0.43, green: 0.30, blue: 0.25, alpha: 1.0)
        case "brown700": return UIColor(red: 0.36, green: 0.25, blue: 0.22, alpha: 1.0)
        case "brown800": return UIColor(red: 0.31, green: 0.20, blue: 0.18, alpha: 1.0)
        case "brown900": return UIColor(red: 0.24, green: 0.15, blue: 0.14, alpha: 1.0)
        case "tan": return UIColor(red: 0.82, green: 0.71, blue: 0.55, alpha: 1.0)
        case "beige": return UIColor(red: 0.96, green: 0.96, blue: 0.86, alpha: 1.0)
        
        // System Colors
        case "systemblue": return UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        case "systemgreen": return UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
        case "systemindigo": return UIColor(red: 0.35, green: 0.34, blue: 0.84, alpha: 1.0)
        case "systemorange": return UIColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
        case "systempink": return UIColor(red: 1.0, green: 0.18, blue: 0.33, alpha: 1.0)
        case "systempurple": return UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0)
        case "systemred": return UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
        case "systemteal": return UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1.0)
        case "systemyellow": return UIColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1.0)
        
        // Material Colors
        case "materialblue": return UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0)
        case "materialred": return UIColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0)
        case "materialgreen": return UIColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0)
        case "materialyellow": return UIColor(red: 1.0, green: 0.92, blue: 0.23, alpha: 1.0)
        case "materialorange": return UIColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1.0)
        case "materialpurple": return UIColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1.0)
        case "materialpink": return UIColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 1.0)
        case "materialteal": return UIColor(red: 0.0, green: 0.59, blue: 0.53, alpha: 1.0)
        case "materialindigo": return UIColor(red: 0.25, green: 0.32, blue: 0.71, alpha: 1.0)
        
        // Common UI
        case "success": return UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
        case "error": return UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
        case "warning": return UIColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
        case "info": return UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        
        // Social Media
        case "facebook": return UIColor(red: 0.09, green: 0.47, blue: 0.95, alpha: 1.0)
        case "twitter": return UIColor(red: 0.11, green: 0.63, blue: 0.95, alpha: 1.0)
        case "instagram": return UIColor(red: 0.89, green: 0.25, blue: 0.37, alpha: 1.0)
        case "linkedin": return UIColor(red: 0.0, green: 0.47, blue: 0.71, alpha: 1.0)
        case "youtube": return UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        case "github": return UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1.0)
        case "google": return UIColor(red: 0.26, green: 0.52, blue: 0.96, alpha: 1.0)
        
        default: return nil
        }
    }

    /// Check if a color string represents transparent
    static func isTransparent(_ colorString: String) -> Bool {
        let lowerString = colorString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        return lowerString == "transparent" || lowerString == "clear" || lowerString == "0x00000000"
            || lowerString == "rgba(0,0,0,0)" || lowerString == "#00000000" || lowerString == "0"
    }

    /// Parse Flutter Color object format: "Color(alpha: 1.0000, red: 0.0000, green: 0.0000, blue: 0.0000, colorSpace: ColorSpace.sRGB)"
    private static func parseFlutterColorObject(_ colorString: String) -> UIColor? {

        let pattern = #"alpha:\s*([\d.]+).*?red:\s*([\d.]+).*?green:\s*([\d.]+).*?blue:\s*([\d.]+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
            let match = regex.firstMatch(
                in: colorString, options: [], range: NSRange(location: 0, length: colorString.count)
            )
        else {
            return .magenta  // Return obvious color for debugging
        }

        let alphaRange = Range(match.range(at: 1), in: colorString)!
        let redRange = Range(match.range(at: 2), in: colorString)!
        let greenRange = Range(match.range(at: 3), in: colorString)!
        let blueRange = Range(match.range(at: 4), in: colorString)!

        guard let alpha = Double(String(colorString[alphaRange])),
            let red = Double(String(colorString[redRange])),
            let green = Double(String(colorString[greenRange])),
            let blue = Double(String(colorString[blueRange]))
        else {
            return .magenta
        }

        let color = UIColor(
            red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))

        return color
    }

    /// Convert a UIColor back to a hex string for debugging purposes
    /// Returns format: "#RRGGBBAA"
    public static func hexString(from color: UIColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        let a = Int(alpha * 255)

        if a == 255 {
            return String(format: "#%02X%02X%02X", r, g, b)
        } else {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
    }

    /// CRITICAL FIX: Add helper method to convert UIColor to ARGB32 format (matching Flutter)
    public static func argb32(from color: UIColor) -> UInt32 {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let a = UInt32(alpha * 255) & 0xFF
        let r = UInt32(red * 255) & 0xFF
        let g = UInt32(green * 255) & 0xFF
        let b = UInt32(blue * 255) & 0xFF

        return (a << 24) | (r << 16) | (g << 8) | b
    }

    /// CRITICAL FIX: Add helper method for color comparison
    public static func colorsAreEqual(_ color1: UIColor?, _ color2: UIColor?) -> Bool {
        guard let color1 = color1, let color2 = color2 else {
            return color1 == nil && color2 == nil
        }

        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0

        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let epsilon: CGFloat = 0.001  // Small tolerance for floating point comparison

        return abs(r1 - r2) < epsilon && abs(g1 - g2) < epsilon && abs(b1 - b2) < epsilon
            && abs(a1 - a2) < epsilon
    }

    /// CRITICAL FIX: Add debug method to print color information
    public static func debugPrint(color: UIColor?, name: String = "Color") {
        guard let color = color else {
            print("\(name): nil")
            return
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        print(
            "\(name): R=\(red), G=\(green), B=\(blue), A=\(alpha) | Hex: \(hexString(from: color)) | ARGB32: \(argb32(from: color))"
        )
    }
}
