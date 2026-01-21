
/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Flutter

// Import C functions for FFI screen dimensions callbacks
@_silgen_name("dcflight_send_screen_dimensions_changed")
func dcflight_send_screen_dimensions_changed(_ dimensionsJson: UnsafePointer<CChar>)

@objc public class DCFScreenUtilities: NSObject {
    @objc public static let shared = DCFScreenUtilities()
    
    private var flutterBinaryMessenger: FlutterBinaryMessenger?
    private var methodChannel: FlutterMethodChannel?
    
    private var _screenWidth: CGFloat = 0
    private var _screenHeight: CGFloat = 0
    private var _safeAreaTop: CGFloat = 0
    private var _safeAreaBottom: CGFloat = 0
    private var _safeAreaLeft: CGFloat = 0
    private var _safeAreaRight: CGFloat = 0
    private var _fontScale: CGFloat = 1.0
    
    private var dimensionChangeListeners: [() -> Void] = []
    
    private override init() {
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // Listen for font size changes
        if #available(iOS 10.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(contentSizeCategoryChanged),
                name: UIContentSizeCategory.didChangeNotification,
                object: nil
            )
        }
        
        updateFontScale()
    }
    
    @objc private func contentSizeCategoryChanged() {
        updateFontScale()
        // Notify Dart of font scale change - Dart will trigger full app re-render
        // React Native-style: OS-level changes trigger app re-render, not manual node invalidation
        notifyDartOfDimensionChange()
    }
    
    private func updateFontScale() {
        if #available(iOS 10.0, *) {
            let contentSize = UIApplication.shared.preferredContentSizeCategory
            // Map UIContentSizeCategory to scale factor
            // Default (medium) = 1.0, larger sizes increase the scale
            let scale: CGFloat
            switch contentSize {
            case .extraSmall:
                scale = 0.823
            case .small:
                scale = 0.882
            case .medium:
                scale = 1.0
            case .large:
                scale = 1.118
            case .extraLarge:
                scale = 1.235
            case .extraExtraLarge:
                scale = 1.353
            case .extraExtraExtraLarge:
                scale = 1.471
            case .accessibilityMedium:
                scale = 1.647
            case .accessibilityLarge:
                scale = 1.765
            case .accessibilityExtraLarge:
                scale = 1.882
            case .accessibilityExtraExtraLarge:
                scale = 2.0
            case .accessibilityExtraExtraExtraLarge:
                scale = 2.118
            default:
                scale = 1.0
            }
            _fontScale = scale
        } else {
            _fontScale = 1.0
        }
    }
    
    func initialize(with binaryMessenger: FlutterBinaryMessenger?) {
        // NO MethodChannel - all communication uses direct FFI callbacks
        // No async needed - FFI callbacks can be called from any thread
        updateScreenDimensions()
        
        // CRITICAL: Always notify Dart of initial dimensions (even if unchanged)
        // This ensures safeAreaTop and other values are available immediately
        notifyDartOfDimensionChange()
        
        print("✅ DCFScreenUtilities: Initialized - using FFI callbacks instead of MethodChannel")
    }
    
    func updateScreenDimensions(width: CGFloat? = nil, height: CGFloat? = nil) {
        let oldWidth = _screenWidth
        let oldHeight = _screenHeight
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            _screenWidth = width ?? window.bounds.width
            _screenHeight = height ?? window.bounds.height
            
            if #available(iOS 11.0, *) {
                _safeAreaTop = window.safeAreaInsets.top
                _safeAreaBottom = window.safeAreaInsets.bottom
                _safeAreaLeft = window.safeAreaInsets.left
                _safeAreaRight = window.safeAreaInsets.right
            } else {
                _safeAreaTop = UIApplication.shared.statusBarFrame.height
                _safeAreaBottom = 0
                _safeAreaLeft = 0
                _safeAreaRight = 0
            }
        } else {
            let bounds = UIScreen.main.bounds
            _screenWidth = width ?? bounds.width
            _screenHeight = height ?? bounds.height
            
            _safeAreaTop = UIApplication.shared.statusBarFrame.height
            _safeAreaBottom = 0
            _safeAreaLeft = 0
            _safeAreaRight = 0
        }
        
        if oldWidth != _screenWidth || oldHeight != _screenHeight {
            print("📱 DCFScreenUtilities: Screen dimensions updated to \(_screenWidth)x\(_screenHeight)")
            notifyDimensionChangeListeners()
            
            notifyDartOfDimensionChange()
        }
    }
    
    func addDimensionChangeListener(_ listener: @escaping () -> Void) {
        dimensionChangeListeners.append(listener)
    }
    
    func removeDimensionChangeListener(_ listener: @escaping () -> Void) {
    }
    
    func clearDimensionChangeListeners() {
        dimensionChangeListeners.removeAll()
    }
    
    private func notifyDimensionChangeListeners() {
        for listener in dimensionChangeListeners {
            listener()
        }
    }
    
    private func notifyDartOfDimensionChange() {
        // Use FFI callback instead of MethodChannel
        let dimensionData = getScreenDimensionsDict()
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dimensionData, options: [])
            if let dimensionsJson = String(data: jsonData, encoding: .utf8) {
                dcflight_send_screen_dimensions_changed(dimensionsJson)
            }
        } catch {
            print("❌ DCFScreenUtilities: Failed to serialize dimensions for FFI callback: \(error)")
        }
    }
    
    /// Get screen dimensions as dictionary (for FFI)
    @objc public func getScreenDimensionsDict() -> [String: Any] {
        // CRITICAL: Ensure dimensions are up-to-date before returning
        // This is called from dcflight_get_screen_dimensions which might be called
        // before initialize() has completed, so we refresh dimensions here
        updateScreenDimensions()
        
        // CRITICAL: Always return valid values, even if window isn't ready
        // Use UIScreen.main.bounds as fallback if dimensions are still 0
        var width = _screenWidth
        var height = _screenHeight
        var safeAreaTop = _safeAreaTop
        var safeAreaBottom = _safeAreaBottom
        
        if width == 0 || height == 0 {
            let screenBounds = UIScreen.main.bounds
            width = screenBounds.width
            height = screenBounds.height
            print("⚠️ DCFScreenUtilities: Using fallback dimensions from UIScreen: \(width)x\(height)")
        }
        
        // Use status bar height as fallback for safe area top if not available
        if safeAreaTop == 0 {
            safeAreaTop = UIApplication.shared.statusBarFrame.height
        }
        
        return [
            "width": width,
            "height": height,
            "scale": UIScreen.main.scale,
            "fontScale": _fontScale,
            "statusBarHeight": UIApplication.shared.statusBarFrame.height,
            "safeAreaTop": safeAreaTop,
            "safeAreaBottom": safeAreaBottom,
            "safeAreaLeft": _safeAreaLeft,
            "safeAreaRight": _safeAreaRight
        ]
    }
    
    
    @objc private func orientationChanged() {
        print("🔄 DCFScreenUtilities: Device orientation changed")
        
        updateScreenDimensions()
        
        // Use FFI callback instead of MethodChannel
        // No async needed - FFI callbacks can be called from any thread
        notifyDartOfDimensionChange()
    }
    
    var screenWidth: CGFloat {
        return _screenWidth
    }
    
    var screenHeight: CGFloat {
        return _screenHeight
    }
    
    var safeAreaTop: CGFloat {
        return _safeAreaTop
    }
    
    var safeAreaBottom: CGFloat {
        return _safeAreaBottom
    }
    
    var safeAreaLeft: CGFloat {
        return _safeAreaLeft
    }
    
    var safeAreaRight: CGFloat {
        return _safeAreaRight
    }
    
    var fontScale: CGFloat {
        return _fontScale
    }
    
    private func getSafeAreaInsets() -> UIEdgeInsets {
        return UIEdgeInsets(
            top: _safeAreaTop,
            left: _safeAreaLeft,
            bottom: _safeAreaBottom,
            right: _safeAreaRight
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        clearDimensionChangeListeners()
    }
}


