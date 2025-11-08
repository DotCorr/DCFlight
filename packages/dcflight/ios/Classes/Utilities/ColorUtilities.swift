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
        var hex = hexString.trimmingCharacters(in: .whitespaces)
        
        // Handle DCFColors prefix: "dcf:black", "dcf:transparent", "dcf:#RRGGBB"
        if hex.hasPrefix("dcf:") {
            let dcfColor = String(hex.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            
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
                hex = dcfColor // Remove dcf: prefix, keep #
            } else {
                // Try as named color
                if let namedColor = getDCFNamedColor(dcfColor.lowercased()) {
                    return namedColor
                }
                return nil
            }
        }
        
        // Handle transparent/clear
        if hex.lowercased() == "transparent" || hex.lowercased() == "clear" {
            return UIColor.clear
        }
        
        // Handle Flutter Color object format
        if hex.contains("Color(") && hex.contains("alpha:") {
            return parseFlutterColorObject(hex)
        }
        
        // Remove "#" prefix if present
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }
        
        // Try named colors first
        if let namedColor = getNamedColor(hex.lowercased()) {
            return namedColor
        }
        
        // Handle numeric string (Flutter color format)
        if let intValue = UInt64(hex, radix: 16), intValue > 0 {
            if intValue == 0 {
                return UIColor.clear
            }
            hex = String(format: "%08llx", intValue)
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
            // RGBA format (AARRGGBB)
            alpha = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            red = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            green = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            blue = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            // RGB format
            red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgb & 0x0000FF) / 255.0
            alpha = 1.0
        }
        
        // Only treat as transparent if explicitly marked
        // Black (#000000) is a valid color, not transparent
        if hexString.lowercased() == "transparent" {
            return UIColor.clear
        }
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    /// Get named color (basic colors)
    private static func getNamedColor(_ colorName: String) -> UIColor? {
        switch colorName {
        case "red": return UIColor.red
        case "green": return UIColor.green
        case "blue": return UIColor.blue
        case "black": return UIColor.black
        case "white": return UIColor.white
        case "yellow": return UIColor.yellow
        case "purple": return UIColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0)
        case "orange": return UIColor.orange
        case "cyan": return UIColor.cyan
        case "clear", "transparent": return UIColor.clear
        case "gray", "grey": return UIColor.gray
        case "lightgray", "lightgrey": return UIColor.lightGray
        case "darkgray", "darkgrey": return UIColor.darkGray
        case "brown": return UIColor.brown
        case "magenta": return UIColor.magenta
        default: return nil
        }
    }
    
    /// Get DCF named color (comprehensive color palette)
    private static func getDCFNamedColor(_ colorName: String) -> UIColor? {
        switch colorName {
        // Base
        case "black": return UIColor.black
        case "white": return UIColor.white
        case "transparent", "clear": return UIColor.clear
        
        // Grays
        case "gray50", "grey50": return UIColor(hex: "#FAFAFA")
        case "gray100", "grey100": return UIColor(hex: "#F5F5F5")
        case "gray200", "grey200": return UIColor(hex: "#EEEEEE")
        case "gray300", "grey300": return UIColor(hex: "#E0E0E0")
        case "gray400", "grey400": return UIColor(hex: "#BDBDBD")
        case "gray500", "grey500": return UIColor(hex: "#9E9E9E")
        case "gray600", "grey600": return UIColor(hex: "#757575")
        case "gray700", "grey700": return UIColor(hex: "#616161")
        case "gray800", "grey800": return UIColor(hex: "#424242")
        case "gray900", "grey900": return UIColor(hex: "#212121")
        case "lightgray", "lightgrey": return UIColor(hex: "#D3D3D3")
        case "darkgray", "darkgrey": return UIColor(hex: "#A9A9A9")
        
        // Blues
        case "blue": return UIColor(hex: "#007AFF")
        case "blue50": return UIColor(hex: "#E3F2FD")
        case "blue100": return UIColor(hex: "#BBDEFB")
        case "blue200": return UIColor(hex: "#90CAF9")
        case "blue300": return UIColor(hex: "#64B5F6")
        case "blue400": return UIColor(hex: "#42A5F5")
        case "blue500": return UIColor(hex: "#2196F3")
        case "blue600": return UIColor(hex: "#1E88E5")
        case "blue700": return UIColor(hex: "#1976D2")
        case "blue800": return UIColor(hex: "#1565C0")
        case "blue900": return UIColor(hex: "#0D47A1")
        case "lightblue": return UIColor(hex: "#5AC8FA")
        case "darkblue": return UIColor(hex: "#0051D5")
        case "blueaccent": return UIColor(hex: "#448AFF")
        case "indigo": return UIColor(hex: "#3F51B5")
        case "indigoaccent": return UIColor(hex: "#536DFE")
        
        // Reds
        case "red": return UIColor(hex: "#FF3B30")
        case "red50": return UIColor(hex: "#EFEBE9")
        case "red100": return UIColor(hex: "#FFCDD2")
        case "red200": return UIColor(hex: "#EF9A9A")
        case "red300": return UIColor(hex: "#E57373")
        case "red400": return UIColor(hex: "#EF5350")
        case "red500": return UIColor(hex: "#F44336")
        case "red600": return UIColor(hex: "#E53935")
        case "red700": return UIColor(hex: "#D32F2F")
        case "red800": return UIColor(hex: "#C62828")
        case "red900": return UIColor(hex: "#B71C1C")
        case "lightred": return UIColor(hex: "#FF6961")
        case "darkred": return UIColor(hex: "#CC0000")
        case "redaccent": return UIColor(hex: "#FF5252")
        case "pink": return UIColor(hex: "#E91E63")
        case "pinkaccent": return UIColor(hex: "#FF4081")
        
        // Greens
        case "green": return UIColor(hex: "#34C759")
        case "green50": return UIColor(hex: "#E8F5E9")
        case "green100": return UIColor(hex: "#C8E6C9")
        case "green200": return UIColor(hex: "#A5D6A7")
        case "green300": return UIColor(hex: "#81C784")
        case "green400": return UIColor(hex: "#66BB6A")
        case "green500": return UIColor(hex: "#4CAF50")
        case "green600": return UIColor(hex: "#43A047")
        case "green700": return UIColor(hex: "#388E3C")
        case "green800": return UIColor(hex: "#2E7D32")
        case "green900": return UIColor(hex: "#1B5E20")
        case "lightgreen": return UIColor(hex: "#90EE90")
        case "darkgreen": return UIColor(hex: "#228B22")
        case "greenaccent": return UIColor(hex: "#69F0AE")
        case "teal": return UIColor(hex: "#009688")
        case "tealaccent": return UIColor(hex: "#64FFDA")
        
        // Yellows & Oranges
        case "yellow": return UIColor(hex: "#FFCC00")
        case "yellow50": return UIColor(hex: "#FFFDE7")
        case "yellow100": return UIColor(hex: "#FFF9C4")
        case "yellow200": return UIColor(hex: "#FFF59D")
        case "yellow300": return UIColor(hex: "#FFF176")
        case "yellow400": return UIColor(hex: "#FFEE58")
        case "yellow500": return UIColor(hex: "#FFEB3B")
        case "yellow600": return UIColor(hex: "#FDD835")
        case "yellow700": return UIColor(hex: "#FBC02D")
        case "yellow800": return UIColor(hex: "#F9A825")
        case "yellow900": return UIColor(hex: "#F57F17")
        case "lightyellow": return UIColor(hex: "#FFFF00")
        case "darkyellow": return UIColor(hex: "#CC9900")
        case "orange": return UIColor(hex: "#FF9500")
        case "orange50": return UIColor(hex: "#FFF3E0")
        case "orange100": return UIColor(hex: "#FFE0B2")
        case "orange200": return UIColor(hex: "#FFCC80")
        case "orange300": return UIColor(hex: "#FFB74D")
        case "orange400": return UIColor(hex: "#FFA726")
        case "orange500": return UIColor(hex: "#FF9800")
        case "orange600": return UIColor(hex: "#FB8C00")
        case "orange700": return UIColor(hex: "#F57C00")
        case "orange800": return UIColor(hex: "#EF6C00")
        case "orange900": return UIColor(hex: "#E65100")
        case "lightorange": return UIColor(hex: "#FFA500")
        case "darkorange": return UIColor(hex: "#FF8C00")
        case "orangeaccent": return UIColor(hex: "#FFAB40")
        case "deeporange": return UIColor(hex: "#FF5722")
        case "deeporangeaccent": return UIColor(hex: "#FF6E40")
        case "amber": return UIColor(hex: "#FFC107")
        case "amberaccent": return UIColor(hex: "#FFD740")
        
        // Purples
        case "purple": return UIColor(hex: "#AF52DE")
        case "purple50": return UIColor(hex: "#F3E5F5")
        case "purple100": return UIColor(hex: "#E1BEE7")
        case "purple200": return UIColor(hex: "#CE93D8")
        case "purple300": return UIColor(hex: "#BA68C8")
        case "purple400": return UIColor(hex: "#AB47BC")
        case "purple500": return UIColor(hex: "#9C27B0")
        case "purple600": return UIColor(hex: "#8E24AA")
        case "purple700": return UIColor(hex: "#7B1FA2")
        case "purple800": return UIColor(hex: "#6A1B9A")
        case "purple900": return UIColor(hex: "#4A148C")
        case "lightpurple": return UIColor(hex: "#DA70D6")
        case "darkpurple": return UIColor(hex: "#8B008B")
        case "purpleaccent": return UIColor(hex: "#E040FB")
        case "deeppurple": return UIColor(hex: "#673AB7")
        case "deeppurpleaccent": return UIColor(hex: "#7C4DFF")
        case "violet": return UIColor(hex: "#9C27B0")
        
        // Cyans
        case "cyan": return UIColor(hex: "#00BCD4")
        case "cyan50": return UIColor(hex: "#E0F7FA")
        case "cyan100": return UIColor(hex: "#B2EBF2")
        case "cyan200": return UIColor(hex: "#80DEEA")
        case "cyan300": return UIColor(hex: "#4DD0E1")
        case "cyan400": return UIColor(hex: "#26C6DA")
        case "cyan500": return UIColor(hex: "#00BCD4")
        case "cyan600": return UIColor(hex: "#00ACC1")
        case "cyan700": return UIColor(hex: "#0097A7")
        case "cyan800": return UIColor(hex: "#00838F")
        case "cyan900": return UIColor(hex: "#006064")
        case "cyanaccent": return UIColor(hex: "#18FFFF")
        case "turquoise": return UIColor(hex: "#40E0D0")
        case "aqua": return UIColor(hex: "#00FFFF")
        
        // Browns
        case "brown": return UIColor(hex: "#795548")
        case "brown50": return UIColor(hex: "#EFEBE9")
        case "brown100": return UIColor(hex: "#D7CCC8")
        case "brown200": return UIColor(hex: "#BCAAA4")
        case "brown300": return UIColor(hex: "#A1887F")
        case "brown400": return UIColor(hex: "#8D6E63")
        case "brown500": return UIColor(hex: "#795548")
        case "brown600": return UIColor(hex: "#6D4C41")
        case "brown700": return UIColor(hex: "#5D4037")
        case "brown800": return UIColor(hex: "#4E342E")
        case "brown900": return UIColor(hex: "#3E2723")
        case "tan": return UIColor(hex: "#D2B48C")
        case "beige": return UIColor(hex: "#F5F5DC")
        
        // System Colors
        case "systemblue": return UIColor(hex: "#007AFF")
        case "systemgreen": return UIColor(hex: "#34C759")
        case "systemindigo": return UIColor(hex: "#5856D6")
        case "systemorange": return UIColor(hex: "#FF9500")
        case "systempink": return UIColor(hex: "#FF2D55")
        case "systempurple": return UIColor(hex: "#AF52DE")
        case "systemred": return UIColor(hex: "#FF3B30")
        case "systemteal": return UIColor(hex: "#5AC8FA")
        case "systemyellow": return UIColor(hex: "#FFCC00")
        
        // Material Colors
        case "materialblue": return UIColor(hex: "#2196F3")
        case "materialred": return UIColor(hex: "#F44336")
        case "materialgreen": return UIColor(hex: "#4CAF50")
        case "materialyellow": return UIColor(hex: "#FFEB3B")
        case "materialorange": return UIColor(hex: "#FF9800")
        case "materialpurple": return UIColor(hex: "#9C27B0")
        case "materialpink": return UIColor(hex: "#E91E63")
        case "materialteal": return UIColor(hex: "#009688")
        case "materialindigo": return UIColor(hex: "#3F51B5")
        
        // Common UI
        case "success": return UIColor(hex: "#34C759")
        case "error": return UIColor(hex: "#FF3B30")
        case "warning": return UIColor(hex: "#FF9500")
        case "info": return UIColor(hex: "#007AFF")
        
        // Social Media
        case "facebook": return UIColor(hex: "#1877F2")
        case "twitter": return UIColor(hex: "#1DA1F2")
        case "instagram": return UIColor(hex: "#E4405F")
        case "linkedin": return UIColor(hex: "#0077B5")
        case "youtube": return UIColor(hex: "#FF0000")
        case "github": return UIColor(hex: "#181717")
        case "google": return UIColor(hex: "#4285F4")
        
        default: return nil
        }
    }
    
    /// Parse Flutter Color object format
    private static func parseFlutterColorObject(_ colorString: String) -> UIColor? {
        // Format: "Color(alpha: 1.0000, red: 0.0000, green: 0.0000, blue: 0.0000, colorSpace: ColorSpace.sRGB)"
        let pattern = #"alpha:\s*([\d.]+).*?red:\s*([\d.]+).*?green:\s*([\d.]+).*?blue:\s*([\d.]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: colorString, range: NSRange(colorString.startIndex..., in: colorString)),
              match.numberOfRanges == 5 else {
            return nil
        }
        
        guard let alphaRange = Range(match.range(at: 1), in: colorString),
              let redRange = Range(match.range(at: 2), in: colorString),
              let greenRange = Range(match.range(at: 3), in: colorString),
              let blueRange = Range(match.range(at: 4), in: colorString),
              let alpha = Double(colorString[alphaRange]),
              let red = Double(colorString[redRange]),
              let green = Double(colorString[greenRange]),
              let blue = Double(colorString[blueRange]) else {
            return nil
        }
        
        return UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
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
        if let explicitColorKey = explicitColor,
           let explicitColorStr = props[explicitColorKey] as? String {
            if let color = color(fromHexString: explicitColorStr) {
                return color
            }
        }
        
        if let semanticColorKey = semanticColor,
           let semanticColorStr = props[semanticColorKey] as? String {
            if let color = color(fromHexString: semanticColorStr) {
                return color
            }
        }
        
        return nil
    }
}

/// UIColor extension for hex color initialization
extension UIColor {
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if hexString.hasPrefix("#") {
            hexString = String(hexString.dropFirst())
        }
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgb) else {
            return nil
        }
        
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        
        if hexString.count == 8 {
            // RGBA format (AARRGGBB)
            alpha = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            red = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            green = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            blue = CGFloat(rgb & 0x000000FF) / 255.0
        } else if hexString.count == 6 {
            // RGB format
            red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgb & 0x0000FF) / 255.0
            alpha = 1.0
        } else {
            return nil
        }
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
