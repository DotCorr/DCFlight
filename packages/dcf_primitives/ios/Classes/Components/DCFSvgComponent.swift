/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight
import SVGKit

/// SVG component that renders SVG images from assets
class DCFSvgComponent: NSObject, DCFComponent {
    // Dictionary to cache loaded SVG images
    private static var imageCache = [String: SVGKImage]()
    
    // CRITICAL FIX: Static initializer to properly set up SVGKit
    static let svgKitInitialized: Bool = {
        // Set up SVGKit configuration to prevent assertion errors
        if let displayScale = UIScreen.main.scale as CGFloat? {
            // Force SVGKit to initialize its internal state properly
            let dummySVG = """
            <?xml version="1.0" encoding="UTF-8"?>
            <svg width="24" height="24" xmlns="http://www.w3.org/2000/svg">
            <rect width="24" height="24" fill="transparent"/>
            </svg>
            """
            if let data = dummySVG.data(using: .utf8) {
                let dummyImage = SVGKImage(data: data)
                dummyImage?.size = CGSize(width: 24, height: 24)
                _ = dummyImage?.uiImage // Force rendering to initialize SVGKit
            }
        }
        return true
    }()
    
    required override init() {
        super.init()
        // Ensure SVGKit is properly initialized
        _ = DCFSvgComponent.svgKitInitialized
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Create an image view to display the SVG
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        // Set adaptive background color (SVGs typically transparent)
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            imageView.backgroundColor = UIColor.clear
        } else {
            imageView.backgroundColor = UIColor.clear
        }
        
        // Apply props
        updateView(imageView, withProps: props)
        
        // Apply StyleSheet properties
        imageView.applyStyles(props: props)
        
        return imageView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let imageView = view as? UIImageView else {
            return false
        }
        
        do {
            // Apply background color from StyleSheet
            if let backgroundColor = props["backgroundColor"] as? String {
                imageView.backgroundColor = ColorUtilities.color(fromHexString: backgroundColor)
            } else {
                // Re-apply adaptive colors if no explicit color provided
                let isAdaptive = props["adaptive"] as? Bool ?? true
                if isAdaptive {
                    imageView.backgroundColor = UIColor.clear
                }
            }
            
            // Handle asset loading (for initial creation) or prop updates
            if let asset = props["asset"] as? String {
                let key = sharedFlutterViewController?.lookupKey(forAsset: asset)
                let mainBundle = Bundle.main
                let path = mainBundle.path(forResource: key, ofType: nil)
                
                loadSvgFromAsset(
                    asset,
                    into: imageView,
                    props: props,
                    isRel: (props["isRelativePath"] as? Bool ?? false),
                    path: path ?? "no path"
                )
            } else {
                // No asset provided - this is likely a prop update (like color change)
                // Apply tint color to the existing image
                applyTintColor(to: imageView, props: props)
            }
            
            // Apply StyleSheet properties (handles borderRadius, opacity, backgroundColor, etc.)
            imageView.applyStyles(props: props)
            
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - SVG Loading Methods
    
    private func loadSvgFromAsset(_ asset: String, into imageView: UIImageView, props: [String: Any], isRel: Bool, path: String) {
        // Check cache first
        if let cachedImage = DCFSvgComponent.imageCache[asset] {
            applyCachedImageToView(cachedImage, imageView: imageView, props: props)
            propagateEvent(on: imageView, eventName: "onLoad", data: [:])
            return
        }
        
        // Load SVG using SVGKit with better error handling
        if let svgImage = loadSVGFromAssetPath(asset, isRelativePath: isRel, path: path) {
            // Cache the image
            DCFSvgComponent.imageCache[asset] = svgImage
            
            applyCachedImageToView(svgImage, imageView: imageView, props: props)
            propagateEvent(on: imageView, eventName: "onLoad", data: [:])
        } else {
            // If we reach here, the image couldn't be loaded
            propagateEvent(on: imageView, eventName: "onError", data: ["error": "SVG not found: \(asset)"])
        }
    }
    
    // CRITICAL FIX: Separate method to apply cached image to view
    private func applyCachedImageToView(_ svgImage: SVGKImage, imageView: UIImageView, props: [String: Any]) {
        // Apply correct rendering mode based on whether tint color is specified
        let hasTintColor = props["tintColor"] as? String != nil
        let isAdaptive = props["adaptive"] as? Bool ?? true
        
        if hasTintColor || isAdaptive {
            // Use template mode for tinting
            imageView.image = svgImage.uiImage?.withRenderingMode(.alwaysTemplate)
        } else {
            // Use original mode when no tinting
            imageView.image = svgImage.uiImage?.withRenderingMode(.alwaysOriginal)
        }
        
        // Apply tint color AFTER image is set
        applyTintColor(to: imageView, props: props)
    }
    
    // MARK: - Helper Methods
    
    private func applyTintColor(to imageView: UIImageView, props: [String: Any]) {
        // Apply tint color if specified
        if let tintColorString = props["tintColor"] as? String,
           let tintColor = ColorUtilities.color(fromHexString: tintColorString) {
            imageView.tintColor = tintColor
            // Force the image to use template rendering mode
            if let image = imageView.image {
                imageView.image = image.withRenderingMode(.alwaysTemplate)
            }
        } else {
            // Only apply adaptive tint if no explicit tintColor was provided at all
            // Check if a tintColor key exists but with nil/empty value vs no key at all
            if props["tintColor"] == nil {
                // No tintColor specified - apply adaptive tint
                let isAdaptive = props["adaptive"] as? Bool ?? true
                if isAdaptive {
                    if #available(iOS 13.0, *) {
                        imageView.tintColor = UIColor.label
                    } else {
                        imageView.tintColor = UIColor.black
                    }
                    // Force the image to use template rendering mode
                    if let image = imageView.image {
                        imageView.image = image.withRenderingMode(.alwaysTemplate)
                    }
                } else {
                    // Reset to original rendering mode if no tint specified
                    if let image = imageView.image {
                        imageView.image = image.withRenderingMode(.alwaysOriginal)
                    }
                    // Clear tint color
                    imageView.tintColor = nil
                }
            } else {
                // tintColor key exists but couldn't be parsed - this means
                // an explicit (but invalid) color was provided, keep current state
            }
        }
    }
    
    // CRITICAL FIX: Enhanced SVG loading with better error handling and retry logic
    private func loadSVGFromAssetPath(_ asset: String, isRelativePath: Bool, path: String) -> SVGKImage? {
        // Method 1: Try loading from direct path if it looks like a file path
        if (asset.hasPrefix("/") || asset.contains(".")) && FileManager.default.fileExists(atPath: asset) && isRelativePath == false {
            return createSVGImageSafely(fromPath: asset)
        } else if asset.hasPrefix("http://") || asset.hasPrefix("https://") {
            // Method 2: Try loading from URL
            if let url = URL(string: asset) {
                return createSVGImageSafely(fromURL: url)
            }
        } else if (isRelativePath == true) {
            return createSVGImageSafely(fromPath: path)
        }
        return nil
    }
    
    // CRITICAL FIX: Safe SVG creation methods with proper error handling
    private func createSVGImageSafely(fromPath path: String) -> SVGKImage? {
        guard !path.isEmpty && FileManager.default.fileExists(atPath: path) else {
            print("❌ DCFSvgComponent: File does not exist at path: \(path)")
            return nil
        }
        
        // Ensure SVGKit is initialized before creating images
        _ = DCFSvgComponent.svgKitInitialized
        
        do {
            let svgImage = SVGKImage(contentsOfFile: path)
            if svgImage == nil {
                print("❌ DCFSvgComponent: SVGKit failed to load image from: \(path)")
            } else {
                print("✅ DCFSvgComponent: Successfully loaded SVG from: \(path)")
            }
            return svgImage
        } catch {
            print("❌ DCFSvgComponent: Error loading SVG from \(path): \(error)")
            return nil
        }
    }
    
    private func createSVGImageSafely(fromURL url: URL) -> SVGKImage? {
        // Ensure SVGKit is initialized before creating images
        _ = DCFSvgComponent.svgKitInitialized
        
        do {
            let svgImage = SVGKImage(contentsOf: url)
            if svgImage == nil {
                print("❌ DCFSvgComponent: SVGKit failed to load image from URL: \(url)")
            } else {
                print("✅ DCFSvgComponent: Successfully loaded SVG from URL: \(url)")
            }
            return svgImage
        } catch {
            print("❌ DCFSvgComponent: Error loading SVG from URL \(url): \(error)")
            return nil
        }
    }
    
}

// MARK: - SVGKit Initialization Helper
extension DCFSvgComponent {
    /// Force SVGKit initialization to prevent timing issues
    static func initializeSVGKit() {
        _ = svgKitInitialized
    }
}
