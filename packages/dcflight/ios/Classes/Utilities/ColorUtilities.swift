/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import Foundation
/// Utilities for color conversion
 public class ColorUtilities {
    
    /// Convert a hex string to a UIColor
    /// Format: "#RRGGBB" or "#RRGGBBAA" or "#AARRGGBB" (Android format)
   public static func color(fromHexString hexString: String) -> UIColor? {
        print("Color conversion request: \"\(hexString)\"")
        
        // Handle transparent color explicitly
        if hexString.lowercased() == "transparent" {
            print("🔍 Using transparent color (explicit keyword)")
            return UIColor.clear
        }
        
        // Handle Flutter Color object format: "Color(alpha: 1.0000, red: 0.0000, green: 0.0000, blue: 0.0000, colorSpace: ColorSpace.sRGB)"
        if hexString.contains("Color(") && hexString.contains("alpha:") {
            return parseFlutterColorObject(hexString)
        }
        
        // Print debug info for troubleshooting color issues
        print("⚡️ ColorUtilities: Processing color string: \(hexString)")
        
        var cleanHexString = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Special handling for Material colors from Flutter
        // These come in as positive integer values
        if let intValue = Int(cleanHexString), intValue >= 0 {
            print("🎨 Converting Flutter color integer value: \(intValue)")
            
            // Check for transparent (0)
            if intValue == 0 {
                print("🔍 Using transparent color (int zero)")
                return UIColor.clear
            }
            
            // Convert the int to hex - Flutter uses ARGB format
            let hexValue = String(format: "#%08x", intValue)
            cleanHexString = hexValue
        }
        
        cleanHexString = cleanHexString.replacingOccurrences(of: "#", with: "")
        
        // Handle common color names
        if cleanHexString.lowercased() == "red" { return .red }
        if cleanHexString.lowercased() == "green" { return .green }
        if cleanHexString.lowercased() == "blue" { return .blue }
        if cleanHexString.lowercased() == "black" { return .black }
        if cleanHexString.lowercased() == "white" { return .white }
        if cleanHexString.lowercased() == "yellow" { return .yellow }
        if cleanHexString.lowercased() == "purple" { return .purple }
        if cleanHexString.lowercased() == "orange" { return .orange }
        if cleanHexString.lowercased() == "cyan" { return .cyan }
        if cleanHexString.lowercased() == "clear" { return .clear }
        
        // For 3-character hex codes like #RGB
        if cleanHexString.count == 3 {
            let r = String(cleanHexString[cleanHexString.startIndex])
            let g = String(cleanHexString[cleanHexString.index(cleanHexString.startIndex, offsetBy: 1)])
            let b = String(cleanHexString[cleanHexString.index(cleanHexString.startIndex, offsetBy: 2)])
            cleanHexString = r + r + g + g + b + b
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cleanHexString).scanHexInt64(&rgbValue)
        
        var alpha: CGFloat = 1.0
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        
        switch cleanHexString.count {
        case 8: // 8 characters: AARRGGBB format used by Flutter
            alpha = CGFloat((rgbValue >> 24) & 0xFF) / 255.0
            red = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
            green = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
            blue = CGFloat(rgbValue & 0xFF) / 255.0
            
            // If explicitly has alpha 0, return clear regardless of RGB values
            if alpha == 0 {
                print("🔍 Using transparent color (alpha=0)")
                return UIColor.clear
            }
            
        case 6: // 6 characters: RRGGBB
            red = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
            green = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
            blue = CGFloat(rgbValue & 0xFF) / 255.0
            alpha = 1.0
            
            // CRITICAL BUGFIX: Handle #000000 specially - check if it was meant to be transparent
            if red == 0 && green == 0 && blue == 0 && 
               (hexString.contains("transparent") || hexString.contains("00000")) {
                return UIColor.clear
            }
            
        default:
            print("⚠️ Invalid color format: \(cleanHexString) (length: \(cleanHexString.count))")
            return .magenta // Return a bright color to make issues obvious
        }
        
        let color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
        print("🎨 Color components: R=\(red), G=\(green), B=\(blue), A=\(alpha) -> UIColor: \(color)")
        return color
    }
    
    /// Check if a color string represents transparent
    static func isTransparent(_ colorString: String) -> Bool {
        // Clean up the string for comparison
        let lowerString = colorString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return lowerString == "transparent" ||
               lowerString == "clear" ||
               lowerString == "0x00000000" ||
               lowerString == "rgba(0,0,0,0)" ||
               lowerString == "#00000000" ||
               lowerString == "0"
    }
    
    /// Parse Flutter Color object format: "Color(alpha: 1.0000, red: 0.0000, green: 0.0000, blue: 0.0000, colorSpace: ColorSpace.sRGB)"
    private static func parseFlutterColorObject(_ colorString: String) -> UIColor? {
        print("🔍 Parsing Flutter Color object: \(colorString)")
        
        // Use regex to extract color components
        let pattern = #"alpha:\s*([\d.]+).*?red:\s*([\d.]+).*?green:\s*([\d.]+).*?blue:\s*([\d.]+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: colorString, options: [], range: NSRange(location: 0, length: colorString.count)) else {
            return .magenta // Return obvious color for debugging
        }
        
        // Extract components
        let alphaRange = Range(match.range(at: 1), in: colorString)!
        let redRange = Range(match.range(at: 2), in: colorString)!
        let greenRange = Range(match.range(at: 3), in: colorString)!
        let blueRange = Range(match.range(at: 4), in: colorString)!
        
        guard let alpha = Double(String(colorString[alphaRange])),
              let red = Double(String(colorString[redRange])),
              let green = Double(String(colorString[greenRange])),
              let blue = Double(String(colorString[blueRange])) else {
            return .magenta
        }
        
        let color = UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
        print("🎨 Parsed Flutter Color: R=\(red), G=\(green), B=\(blue), A=\(alpha) -> \(color)")
        
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
        
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}
