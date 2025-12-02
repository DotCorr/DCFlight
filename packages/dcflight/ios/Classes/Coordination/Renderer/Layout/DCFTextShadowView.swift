/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import yoga
import dcflight

/**
 * DCFTextShadowView - Specialized shadow view for Text components
 * 
 * Text components require custom measurement logic because:
 * 1. Text size depends on content and available width (wrapping behavior)
 * 2. Padding must be subtracted from available width before measurement
 * 3. Accurate measurement requires NSLayoutManager/NSTextContainer for proper
 *    text layout, line breaks, and truncation
 * 4. Text properties (font, line height, letter spacing) affect measurement
 * 
 * Other components (View, Image, etc.) either:
 * - Have fixed sizes (explicit width/height)
 * - Use standard intrinsic content size (UIImageView, UIButton)
 * - Are measured by their children (container views)
 * 
 * Key features:
 * - Custom measure function that accounts for padding
 * - Uses NSLayoutManager for accurate text measurement
 * - Handles text wrapping and truncation correctly
 * - Caches text storage to avoid recomputation
 */
open class DCFTextShadowView: DCFShadowView {
    
    // MARK: - Properties
    
    private var _cachedTextStorage: NSTextStorage?
    private var _cachedTextStorageWidth: CGFloat = -1
    private var _cachedTextStorageWidthMode: YGMeasureMode = .undefined
    private var _cachedAttributedString: NSAttributedString?
    
    // Text properties
    public var text: String = ""
    public var fontSize: CGFloat = CGFloat.nan
    public var fontWeight: String?
    public var fontFamily: String?
    public var letterSpacing: CGFloat = CGFloat.nan
    public var lineHeight: CGFloat = 0.0
    public var numberOfLines: Int = 0
    public var textAlign: NSTextAlignment = .natural
    public var textColor: UIColor?
    
    // MARK: - Initialization
    
    public required init(viewId: Int) {
        super.init(viewId: viewId)
        
        // Set up custom measure function for text
        // Use static function to avoid closure capture issues with C function pointers
        YGNodeSetMeasureFunc(self.yogaNode, DCFTextShadowView.textMeasureFunction)
    }
    
    // MARK: - Text Measurement
    
    /**
     * Static measure function for text nodes (C function pointer compatible)
     * Retrieves the shadow view from the Yoga node's context
     */
    private static let textMeasureFunction: YGMeasureFunc = { (node, width, widthMode, height, heightMode) -> YGSize in
        guard let node = node else {
            return YGSize(width: 0, height: 0)
        }
        guard let context = YGNodeGetContext(node) else {
            return YGSize(width: 0, height: 0)
        }
        
        let shadowView = Unmanaged<DCFTextShadowView>.fromOpaque(context).takeUnretainedValue()
        return shadowView.measureText(node: node, width: width, widthMode: widthMode, height: height, heightMode: heightMode)
    }
    
    /**
     * Custom measure function for text nodes
     * Accounts for padding and uses NSLayoutManager for accurate measurement
     */
    private func measureText(node: YGNodeRef?, width: Float, widthMode: YGMeasureMode, height: Float, heightMode: YGMeasureMode) -> YGSize {
        // If text is empty, return minimal size
        if text.isEmpty {
            return YGSize(width: 1, height: 1)
        }
        
        // Get padding to calculate available width
        let padding = self.paddingAsInsets
        let availableWidth: CGFloat
        
        if widthMode == .undefined {
            availableWidth = CGFloat.greatestFiniteMagnitude
        } else {
            // Account for padding when measuring
            availableWidth = max(0, CGFloat(width) - (padding.left + padding.right))
        }
        
        // Build text storage for the available width
        let textStorage = buildTextStorageForWidth(availableWidth, widthMode: widthMode)
        
        // Get the layout manager and text container
        guard let layoutManager = textStorage.layoutManagers.first,
              let textContainer = layoutManager.textContainers.first else {
            return YGSize(width: 1, height: 1)
        }
        
        // Calculate the actual text size
        let computedSize = layoutManager.usedRect(for: textContainer).size
        
        // Round up to pixel boundaries, ensure minimum size
        let result = YGSize(
            width: Float(max(1, ceil(computedSize.width))),
            height: Float(max(1, ceil(computedSize.height)))
        )
        
        return result
    }
    
    /**
     * Build text storage for a given width constraint
     * Caches results to avoid recomputation
     */
    private func buildTextStorageForWidth(_ width: CGFloat, widthMode: YGMeasureMode) -> NSTextStorage {
        // Check cache
        if let cached = _cachedTextStorage,
           width == _cachedTextStorageWidth,
           widthMode == _cachedTextStorageWidthMode {
            return cached
        }
        
        // Create attributed string
        let attributedString = buildAttributedString()
        
        // Create text storage
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        // Create text container
        let textContainer = NSTextContainer()
        textContainer.lineFragmentPadding = 0.0
        
        // Configure line break mode
        if numberOfLines > 0 {
            textContainer.lineBreakMode = .byTruncatingTail
        } else {
            textContainer.lineBreakMode = .byClipping
        }
        
        textContainer.maximumNumberOfLines = numberOfLines
        textContainer.size = CGSize(
            width: widthMode == .undefined ? CGFloat.greatestFiniteMagnitude : width,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureLayout(for: textContainer)
        
        // Cache the result
        _cachedTextStorage = textStorage
        _cachedTextStorageWidth = width
        _cachedTextStorageWidthMode = widthMode
        
        return textStorage
    }
    
    /**
     * Build attributed string from text properties
     */
    private func buildAttributedString() -> NSAttributedString {
        // Check cache
        if let cached = _cachedAttributedString {
            return cached
        }
        
        let mutableString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.count)
        
        // Font
        var font = UIFont.systemFont(ofSize: 17)
        if !fontSize.isNaN {
            font = UIFont.systemFont(ofSize: fontSize)
        }
        if let fontWeight = fontWeight {
            let weight = fontWeightFromString(fontWeight)
            font = UIFont.systemFont(ofSize: font.pointSize, weight: weight)
        }
        if let fontFamily = fontFamily {
            if let customFont = UIFont(name: fontFamily, size: font.pointSize) {
                font = customFont
            }
        }
        mutableString.addAttribute(.font, value: font, range: range)
        
        // Text color
        if let textColor = textColor {
            mutableString.addAttribute(.foregroundColor, value: textColor, range: range)
        }
        
        // Letter spacing
        if !letterSpacing.isNaN {
            mutableString.addAttribute(.kern, value: letterSpacing, range: range)
        }
        
        // Line height and paragraph style
        if lineHeight > 0 || textAlign != .natural {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = textAlign
            
            if lineHeight > 0 {
                // Line height can be a multiplier or absolute value
                let absoluteLineHeight: CGFloat
                if lineHeight < 10 {
                    // Treat as multiplier
                    absoluteLineHeight = lineHeight * font.pointSize
                } else {
                    // Treat as absolute value
                    absoluteLineHeight = lineHeight
                }
                paragraphStyle.minimumLineHeight = absoluteLineHeight
                paragraphStyle.maximumLineHeight = absoluteLineHeight
            }
            
            mutableString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }
        
        // Cache the result
        _cachedAttributedString = NSAttributedString(attributedString: mutableString)
        
        return _cachedAttributedString!
    }
    
    /**
     * Convert fontWeight string to UIFont.Weight
     */
    private func fontWeightFromString(_ weight: String) -> UIFont.Weight {
        switch weight.lowercased() {
        case "thin": return .thin
        case "ultralight": return .ultraLight
        case "light": return .light
        case "regular", "normal", "400": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }
    
    /**
     * Update text properties from props dictionary
     * Called when text props are updated from Dart
     */
    public func updateTextProps(_ props: [String: Any]) {
        var needsDirty = false
        
        // Update text content
        if let content = props["content"] as? String, content != text {
            text = content
            needsDirty = true
        }
        
        // Update fontSize
        if let fontSizeValue = props["fontSize"] as? CGFloat {
            if fontSize != fontSizeValue {
                fontSize = fontSizeValue
                needsDirty = true
            }
        }
        
        // Update fontWeight
        if let fontWeightValue = props["fontWeight"] as? String {
            if fontWeight != fontWeightValue {
                fontWeight = fontWeightValue
                needsDirty = true
            }
        }
        
        // Update fontFamily
        if let fontFamilyValue = props["fontFamily"] as? String {
            if fontFamily != fontFamilyValue {
                fontFamily = fontFamilyValue
                needsDirty = true
            }
        }
        
        // Update letterSpacing
        if let letterSpacingValue = props["letterSpacing"] as? CGFloat {
            if letterSpacing != letterSpacingValue {
                letterSpacing = letterSpacingValue
                needsDirty = true
            }
        }
        
        // Update lineHeight
        if let lineHeightValue = props["lineHeight"] as? CGFloat {
            if lineHeight != lineHeightValue {
                lineHeight = lineHeightValue
                needsDirty = true
            }
        }
        
        // Update numberOfLines
        if let numberOfLinesValue = props["numberOfLines"] as? Int {
            if numberOfLines != numberOfLinesValue {
                numberOfLines = numberOfLinesValue
                needsDirty = true
            }
        }
        
        // Update textAlign
        if let textAlignStr = props["textAlign"] as? String {
            let newAlign: NSTextAlignment
            switch textAlignStr.lowercased() {
            case "left": newAlign = .left
            case "center": newAlign = .center
            case "right": newAlign = .right
            case "justify": newAlign = .justified
            default: newAlign = .natural
            }
            if textAlign != newAlign {
                textAlign = newAlign
                needsDirty = true
            }
        }
        
        // Update textColor
        if let textColorValue = ColorUtilities.getColor(
            explicitColor: "textColor",
            semanticColor: "primaryColor",
            from: props
        ) {
            if textColor != textColorValue {
                textColor = textColorValue
                needsDirty = true
            }
        }
        
        if needsDirty {
            dirtyText()
        }
    }
    
    /**
     * Mark text as dirty to force recomputation.
     * Overrides base class to also clear cached text storage.
     */
    public override func dirtyText() {
        // Clear cached text storage and attributed string
        _cachedTextStorage = nil
        _cachedAttributedString = nil
        _cachedTextStorageWidth = -1
        
        // Mark Yoga node as dirty for layout recalculation
        YGNodeMarkDirty(self.yogaNode)
        
        // Call super to maintain text lifecycle tracking
        super.dirtyText()
    }
    
    // MARK: - Overrides
    
    public override func didSetProps(_ changedProps: [String]) {
        // Check if text-related props changed
        let textProps = ["content", "fontSize", "fontWeight", "fontFamily", "letterSpacing", 
                        "lineHeight", "numberOfLines", "textAlign", "textColor", "primaryColor"]
        
        if changedProps.contains(where: { textProps.contains($0) }) {
            dirtyText()
        }
        
        // Call super to handle layout props
        super.didSetProps(changedProps)
    }
}

