/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
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
 * - Supports automatic font size adjustment to fit bounds
 */
public class DCFTextShadowView: DCFShadowView {
    
    // MARK: - Constants
    
    private static let kAutoSizeGranularity: CGFloat = 0.001
    private static let kAutoSizeWidthErrorMargin: CGFloat = 0.01
    private static let kAutoSizeHeightErrorMargin: CGFloat = 0.01
    
    // MARK: - Enums
    
    private enum DCFSizeComparison {
        case tooLarge
        case tooSmall
        case withinRange
    }
    
    // MARK: - Properties
    
    private var _cachedTextStorage: NSTextStorage?
    private var _cachedTextStorageWidth: CGFloat = -1
    private var _cachedTextStorageWidthMode: YGMeasureMode = .undefined
    private var _cachedAttributedString: NSAttributedString?
    
    // Text properties
    public var text: String = ""
    public var fontSize: CGFloat = CGFloat.nan
    public var fontWeight: Int? // Numeric weight (100-900) from Dart
    public var fontFamily: String?
    public var letterSpacing: CGFloat = CGFloat.nan
    public var lineHeight: CGFloat = 0.0
    public var numberOfLines: Int = 0
    public var textAlign: NSTextAlignment = .natural
    public var textColor: UIColor?
    public var adjustsFontSizeToFit: Bool = false
    public var minimumFontScale: CGFloat = 0.0
    
    // Text storage and frame for rendering (set during layout)
    public var computedTextStorage: NSTextStorage?
    public var computedTextFrame: CGRect = .zero
    public var computedContentInset: UIEdgeInsets = .zero
    
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
     * Matches approach: measurement returns text size only, padding handled separately
     */
    private func measureText(node: YGNodeRef?, width: Float, widthMode: YGMeasureMode, height: Float, heightMode: YGMeasureMode) -> YGSize {
        // Match approach: Yoga passes available width (after padding) to measure function
        // When widthMode is undefined, use CGFLOAT_MAX for unlimited width
        let availableWidth: CGFloat = widthMode == .undefined ? CGFloat.greatestFiniteMagnitude : CGFloat(width)
        let textStorage = buildTextStorageForWidth(availableWidth, widthMode: widthMode)
        
        // Get the layout manager and text container
        guard let layoutManager = textStorage.layoutManagers.first,
              let textContainer = layoutManager.textContainers.first else {
            // Fallback: return minimum size based on font
            // Apply font scale to match Android's SP scaling behavior
            let fontScale = DCFScreenUtilities.shared.fontScale
            let baseFontSize = !fontSize.isNaN ? fontSize : 17
            let minHeight = max(1, baseFontSize * fontScale)
            return YGSize(width: 1, height: Float(minHeight))
        }
        
        // Calculate the actual text size - match approach: use usedRect directly
        let computedSize = layoutManager.usedRect(for: textContainer).size
        
        // Round up to pixel boundaries (match approach: RCTCeilPixelValue)
        let scale = UIScreen.main.scale
        let roundedWidth = ceil(computedSize.width * scale) / scale
        let roundedHeight = ceil(computedSize.height * scale) / scale
        
        // CRITICAL: Don't subtract letter spacing - usedRect already accounts for it!
        // The NSLayoutManager's usedRect already includes the letter spacing in its calculation,
        // so subtracting it again would make the width too small and cause text clipping.
        // Letter spacing is applied during layout, and usedRect reflects the actual bounding box.
        
        // Match approach: return just the text size (no padding added)
        // Yoga automatically accounts for padding when calculating the final frame
        let result = YGSize(
            width: Float(roundedWidth),
            height: Float(roundedHeight)
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
        
        // Match approach: text container size is exactly the width (no buffer)
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
     * Convert numeric font weight (100-900) to UIFont.Weight constant
     * This ensures we use the system's actual font weights instead of synthetic ones
     */
    private func fontWeightFromNumeric(_ weight: Int) -> UIFont.Weight {
        switch weight {
        case 100: return .ultraLight
        case 200: return .thin
        case 300: return .light
        case 400: return .regular
        case 500: return .medium
        case 600: return .semibold
        case 700: return .bold
        case 800: return .heavy
        case 900: return .black
        default:
            // For weights between standard values, map to nearest
            if weight < 150 { return .ultraLight }
            else if weight < 250 { return .thin }
            else if weight < 350 { return .light }
            else if weight < 450 { return .regular }
            else if weight < 550 { return .medium }
            else if weight < 650 { return .semibold }
            else if weight < 750 { return .bold }
            else if weight < 850 { return .heavy }
            else { return .black }
        }
    }
    
    /**
     * Build attributed string from text properties
     */
    private func buildAttributedString() -> NSAttributedString {
        // Check cache
        if let cached = _cachedAttributedString {
            return cached
        }
        
        // If text is empty, return empty attributed string with font to get baseline height
        let textToUse = text.isEmpty ? " " : text
        let mutableString = NSMutableAttributedString(string: textToUse)
        // CRITICAL: Use UTF-16 length for NSRange, not Swift character count
        // Emojis and other Unicode characters can span multiple UTF-16 code units
        // Using .count would create incorrect ranges, breaking emoji rendering
        let range = NSRange(location: 0, length: (textToUse as NSString).length)
        
        // Font - use fontSize from props or default
        // CRITICAL: Apply font scale to match Android's SP behavior
        // Android SP scales with system font size, so iOS should too for consistency
        let fontScale = DCFScreenUtilities.shared.fontScale
        var font = UIFont.systemFont(ofSize: 17)
        let finalFontSize: CGFloat
        if !fontSize.isNaN {
            // Apply font scale to match Android's SP scaling behavior
            finalFontSize = fontSize * fontScale
            font = UIFont.systemFont(ofSize: finalFontSize)
        } else {
            finalFontSize = 17 * fontScale
        }
        
        if let fontWeight = fontWeight {
            // Convert numeric weight (100-900) to proper UIFont.Weight constants
            // This ensures we use the system's actual bold font instead of synthetic weights
            let uiWeight = fontWeightFromNumeric(fontWeight)
            font = UIFont.systemFont(ofSize: finalFontSize, weight: uiWeight)
        }
        if let fontFamily = fontFamily {
            if let customFont = UIFont(name: fontFamily, size: finalFontSize) {
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
        
        // Update fontWeight - now expects numeric weight (100-900) from Dart
        if let fontWeightValue = props["fontWeight"] as? CGFloat {
            let weightInt = Int(fontWeightValue)
            if fontWeight != weightInt {
                fontWeight = weightInt
                needsDirty = true
            }
        } else if let fontWeightValue = props["fontWeight"] as? Int {
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
        
        // Update adjustsFontSizeToFit
        if let adjustsFontSizeToFitValue = props["adjustsFontSizeToFit"] as? Bool {
            if adjustsFontSizeToFit != adjustsFontSizeToFitValue {
                adjustsFontSizeToFit = adjustsFontSizeToFitValue
                needsDirty = true
            }
        }
        
        // Update minimumFontScale
        if let minimumFontScaleValue = props["minimumFontScale"] as? CGFloat {
            let clampedValue = minimumFontScaleValue >= 0.01 ? minimumFontScaleValue : 0.0
            if minimumFontScale != clampedValue {
                minimumFontScale = clampedValue
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
        
        // CRITICAL: Only mark node dirty if it's in a valid state
        // Yoga will crash if we mark a node dirty that has both measure function and children
        // Text nodes should be leaf nodes (no children) when they have a measure function
        let childCount = YGNodeGetChildCount(self.yogaNode)
        if childCount == 0 {
            // Safe to mark dirty - node is a leaf (no children)
        YGNodeMarkDirty(self.yogaNode)
        } else {
            // Node has children - don't mark dirty, let parent handle it
            // This prevents the "Only leaf nodes with custom measure functions should manually mark themselves as dirty" crash
        }
        
        // Call super to maintain text lifecycle tracking
        super.dirtyText()
    }
    
    // MARK: - Overrides
    
    public override func didSetProps(_ changedProps: [String]) {
        // Text props are set through updateTextProps which calls dirtyText()
        // This didSetProps is for layout props only
        super.didSetProps(changedProps)
    }
    
    /**
     * Override applyLayoutNode to build textStorage and calculate textFrame
     */
    public override func applyLayoutNode(_ node: YGNodeRef, viewsWithNewFrame: NSMutableSet, absolutePosition: CGPoint) {
        // Call super to handle frame calculation
        super.applyLayoutNode(node, viewsWithNewFrame: viewsWithNewFrame, absolutePosition: absolutePosition)
        
        // Build text storage and calculate text frame for rendering
        let padding = self.paddingAsInsets
        let width = self.frame.size.width - (padding.left + padding.right)
        
        let textStorage = buildTextStorageForWidth(width, widthMode: .exactly)
        let textFrame = calculateTextFrame(textStorage: textStorage)
        
        // Store for use by DCFTextComponent.applyLayout
        computedTextStorage = textStorage
        computedTextFrame = textFrame
        computedContentInset = padding
    }
    
    /**
     * Calculate text frame from text storage (accounts for padding)
     * Matches approach: simple inset by padding, no buffers
     */
    private func calculateTextFrame(textStorage: NSTextStorage) -> CGRect {
        let padding = self.paddingAsInsets
        var textFrame = CGRect(origin: .zero, size: self.frame.size).inset(by: padding)
        
        if adjustsFontSizeToFit {
            textFrame = updateStorage(textStorage, toFitFrame: textFrame)
        }
        
        return textFrame
    }
    
    /**
     * Update text storage to fit within frame by adjusting font size
     */
    private func updateStorage(_ textStorage: NSTextStorage, toFitFrame frame: CGRect) -> CGRect {
        let fits = attemptScale(1.0, inStorage: textStorage, forFrame: frame)
        let requiredSize: CGSize
        
        if fits == .tooLarge {
            requiredSize = calculateOptimumScaleInFrame(
                frame,
                forStorage: textStorage,
                minScale: minimumFontScale,
                maxScale: 1.0,
                prevMid: CGFloat.greatestFiniteMagnitude
            )
        } else {
            requiredSize = calculateSize(textStorage)
        }
        
        // Vertically center draw position for new text sizing
        var adjustedFrame = frame
        adjustedFrame.origin.y = paddingAsInsets.top + roundPixelValue((frame.height - requiredSize.height) / 2.0)
        
        return adjustedFrame
    }
    
    /**
     * Calculate optimum font scale using binary search
     */
    private func calculateOptimumScaleInFrame(
        _ frame: CGRect,
        forStorage textStorage: NSTextStorage,
        minScale: CGFloat,
        maxScale: CGFloat,
        prevMid: CGFloat
    ) -> CGSize {
        let midScale = (minScale + maxScale) / 2.0
        
        if round(prevMid / Self.kAutoSizeGranularity) == round(midScale / Self.kAutoSizeGranularity) {
            // Bail because we can't meet error margin
            return calculateSize(textStorage)
        }
        
        let comparison = attemptScale(midScale, inStorage: textStorage, forFrame: frame)
        
        if comparison == .withinRange {
            return calculateSize(textStorage)
        } else if comparison == .tooLarge {
            return calculateOptimumScaleInFrame(
                frame,
                forStorage: textStorage,
                minScale: minScale,
                maxScale: midScale - Self.kAutoSizeGranularity,
                prevMid: midScale
            )
        } else {
            return calculateOptimumScaleInFrame(
                frame,
                forStorage: textStorage,
                minScale: midScale + Self.kAutoSizeGranularity,
                maxScale: maxScale,
                prevMid: midScale
            )
        }
    }
    
    /**
     * Attempt to scale text storage by given scale factor and check if it fits
     */
    private func attemptScale(_ scale: CGFloat, inStorage textStorage: NSTextStorage, forFrame frame: CGRect) -> DCFSizeComparison {
        guard let layoutManager = textStorage.layoutManagers.first,
              let textContainer = layoutManager.textContainers.first else {
            return .tooLarge
        }
        
        let glyphRange = NSRange(location: 0, length: textStorage.length)
        let originalAttributedString = buildAttributedString()
        
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: glyphRange, options: []) { (font, range, _) in
            if let font = font as? UIFont {
                if let originalFont = originalAttributedString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont {
                    let newFont = font.withSize(originalFont.pointSize * scale)
                    textStorage.removeAttribute(.font, range: range)
                    textStorage.addAttribute(.font, value: newFont, range: range)
                }
            }
        }
        textStorage.endEditing()
        
        let linesRequired = numberOfLinesRequired(layoutManager)
        let requiredSize = calculateSize(textStorage)
        
        let fitSize = requiredSize.height <= frame.height && requiredSize.width <= frame.width
        let fitLines = linesRequired <= textContainer.maximumNumberOfLines || textContainer.maximumNumberOfLines == 0
        
        if fitLines && fitSize {
            if (requiredSize.width + (frame.width * Self.kAutoSizeWidthErrorMargin)) > frame.width &&
               (requiredSize.height + (frame.height * Self.kAutoSizeHeightErrorMargin)) > frame.height {
                return .withinRange
            } else {
                return .tooSmall
            }
        } else {
            return .tooLarge
        }
    }
    
    /**
     * Calculate size of text storage
     */
    private func calculateSize(_ textStorage: NSTextStorage) -> CGSize {
        guard let layoutManager = textStorage.layoutManagers.first,
              let textContainer = layoutManager.textContainers.first else {
            return .zero
        }
        
        // Set line break mode to word wrapping for size calculation
        let maxLines = textContainer.maximumNumberOfLines
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.maximumNumberOfLines = 0
        
        _ = layoutManager.glyphRange(for: textContainer)
        let requiredSize = layoutManager.usedRect(for: textContainer).size
        
        // Restore original settings
        textContainer.maximumNumberOfLines = maxLines
        if numberOfLines > 0 {
            textContainer.lineBreakMode = .byTruncatingTail
        } else {
            textContainer.lineBreakMode = .byClipping
        }
        
        return requiredSize
    }
    
    /**
     * Calculate number of lines required for text storage
     */
    private func numberOfLinesRequired(_ layoutManager: NSLayoutManager) -> Int {
        var numberOfLines = 0
        var index = 0
        let numberOfGlyphs = layoutManager.numberOfGlyphs
        
        while index < numberOfGlyphs {
            var lineRange = NSRange()
            _ = layoutManager.lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
            index = NSMaxRange(lineRange)
            numberOfLines += 1
        }
        
        return numberOfLines
    }
    
    /**
     * Round pixel value helper
     */
    private func roundPixelValue(_ value: CGFloat) -> CGFloat {
        return round(value * UIScreen.main.scale) / UIScreen.main.scale
    }
}
