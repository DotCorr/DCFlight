/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit

/// Context protocol for DCFlight components
/// Provides access to view controller, theme, and app-level state
/// Context hierarchy for managing component context and state
public protocol DCFContext {
    var viewController: UIViewController? { get }
    var isDarkMode: Bool { get }
    var textColor: UIColor { get }
    var backgroundColor: UIColor { get }
    var surfaceColor: UIColor { get }
    var accentColor: UIColor { get }
}

/// Application-level context (root context)
/// Provides access to app-level context and theme
public class DCFApplicationContext: DCFContext {
    public let viewController: UIViewController? = nil
    
    private let traitCollection: UITraitCollection
    
    public init(traitCollection: UITraitCollection = UITraitCollection.current) {
        self.traitCollection = traitCollection
    }
    
    public var isDarkMode: Bool {
        return DCFTheme.isDarkTheme(traitCollection: traitCollection)
    }
    
    public var textColor: UIColor {
        return DCFTheme.getTextColor(traitCollection: traitCollection)
    }
    
    public var backgroundColor: UIColor {
        return DCFTheme.getBackgroundColor(traitCollection: traitCollection)
    }
    
    public var surfaceColor: UIColor {
        return DCFTheme.getSurfaceColor(traitCollection: traitCollection)
    }
    
    public var accentColor: UIColor {
        return DCFTheme.getAccentColor(traitCollection: traitCollection)
    }
}

/// Themed context for specific surfaces/views
/// Can override theme values for specific contexts
public class DCFThemedContext: DCFContext {
    public let viewController: UIViewController?
    
    private let parent: DCFContext
    
    public let isDarkMode: Bool
    public let textColor: UIColor
    public let backgroundColor: UIColor
    public let surfaceColor: UIColor
    public let accentColor: UIColor
    
    public init(
        parent: DCFContext,
        viewController: UIViewController? = nil,
        isDarkMode: Bool? = nil,
        textColor: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        surfaceColor: UIColor? = nil,
        accentColor: UIColor? = nil
    ) {
        self.parent = parent
        self.viewController = viewController
        self.isDarkMode = isDarkMode ?? parent.isDarkMode
        self.textColor = textColor ?? parent.textColor
        self.backgroundColor = backgroundColor ?? parent.backgroundColor
        self.surfaceColor = surfaceColor ?? parent.surfaceColor
        self.accentColor = accentColor ?? parent.accentColor
    }
}

