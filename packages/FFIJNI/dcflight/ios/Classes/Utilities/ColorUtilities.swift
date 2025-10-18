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
    public static func color(fromHexString hexString: String) -> UIColor? {

        if hexString.lowercased() == "transparent" {
            return UIColor.clear
        }

        if hexString.contains("Color(") && hexString.contains("alpha:") {
            return parseFlutterColorObject(hexString)
        }

        var cleanHexString = hexString.trimmingCharacters(in: .whitespacesAndNewlines)

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
