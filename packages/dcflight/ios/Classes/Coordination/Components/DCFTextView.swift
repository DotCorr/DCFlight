/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit

class DCFTextView: UIView {
    var textStorage: NSTextStorage? {
        didSet {
            if textStorage != oldValue {
                setNeedsDisplay()
            }
        }
    }
    
    var textFrame: CGRect = .zero {
        didSet {
            if textFrame != oldValue {
                setNeedsDisplay()
            }
        }
    }
    
    var contentInset: UIEdgeInsets = .zero {
        didSet {
            if contentInset != oldValue {
                setNeedsDisplay()
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        textStorage = NSTextStorage()
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        isOpaque = false
        contentMode = .redraw
        
        // CRITICAL: Don't clip text - fonts have metrics (ascenders/descenders) that extend
        // beyond the measured bounds. Text views should not clip to allow full glyph rendering.
        clipsToBounds = false
    }
    
    override func draw(_ rect: CGRect) {
        guard let textStorage = textStorage,
              let layoutManager = textStorage.layoutManagers.first,
              let textContainer = layoutManager.textContainers.first else {
            return
        }
        
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        let drawPoint = textFrame.origin
        
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: drawPoint)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: drawPoint)
    }
    
    override var description: String {
        let superDescription = super.description
        let text = textStorage?.string ?? ""
        return "\(superDescription); text: \(text)"
    }
}

