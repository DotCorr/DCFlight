
/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Flutter

class DCFScreenUtilities {
    static let shared = DCFScreenUtilities()
    
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
    
    private init() {
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
    
    func initialize(with binaryMessenger: FlutterBinaryMessenger) {
        self.flutterBinaryMessenger = binaryMessenger
        
        methodChannel = FlutterMethodChannel(
            name: "com.dcmaui.screen_dimensions",
            binaryMessenger: binaryMessenger
        )
        
        setupMethodChannel()
        
        DispatchQueue.main.async {
            self.updateScreenDimensions()
        }
        
        print("✅ DCFScreenUtilities: Initialized with method channel")
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
        guard let methodChannel = methodChannel else { return }
        
        let dimensionData: [String: Any] = [
            "width": _screenWidth,
            "height": _screenHeight,
            "scale": UIScreen.main.scale,
            "fontScale": _fontScale,
            "statusBarHeight": UIApplication.shared.statusBarFrame.height,
            "safeAreaTop": _safeAreaTop,
            "safeAreaBottom": _safeAreaBottom,
            "safeAreaLeft": _safeAreaLeft,
            "safeAreaRight": _safeAreaRight
        ]
        
        methodChannel.invokeMethod("dimensionsChanged", arguments: dimensionData)
    }
    
    private func setupMethodChannel() {
        guard let methodChannel = methodChannel else { return }
        
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE",
                                   message: "Screen utilities not available",
                                   details: nil))
                return
            }
            
            if call.method == "getScreenDimensions" {
                result([
                    "width": self._screenWidth,
                    "height": self._screenHeight,
                    "scale": UIScreen.main.scale,
                    "fontScale": self._fontScale,
                    "statusBarHeight": UIApplication.shared.statusBarFrame.height,
                    "safeAreaTop": self._safeAreaTop,
                    "safeAreaBottom": self._safeAreaBottom,
                    "safeAreaLeft": self._safeAreaLeft,
                    "safeAreaRight": self._safeAreaRight
                ])
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    @objc private func orientationChanged() {
        print("🔄 DCFScreenUtilities: Device orientation changed")
        
        updateScreenDimensions()
        
        guard let methodChannel = methodChannel else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.notifyDartOfDimensionChange()
        }
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


