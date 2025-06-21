/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight

class DCFImageComponent: NSObject, DCFComponent, ComponentMethodHandler {
    // Thread-safe image cache using concurrent queue with barrier writes
    private static let cacheQueue = DispatchQueue(label: "com.dcf.imageCache", attributes: .concurrent)
    private static var _imageCache = [String: UIImage]()
    
    // Thread-safe cache accessors
    private static func getCachedImage(for key: String) -> UIImage? {
        return cacheQueue.sync {
            return _imageCache[key]
        }
    }
    
    private static func setCachedImage(_ image: UIImage, for key: String) {
        cacheQueue.async(flags: .barrier) {
            _imageCache[key] = image
        }
    }
    
    private static func removeCachedImage(for key: String) {
        cacheQueue.async(flags: .barrier) {
            _imageCache.removeValue(forKey: key)
        }
    }
    
    private static func clearAllCache() {
        cacheQueue.async(flags: .barrier) {
            _imageCache.removeAll()
        }
    }
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        // Create an image view
        let imageView = UIImageView()
        
        // Apply initial styling
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        // Set up adaptive background color for cases when no image is loaded
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            if #available(iOS 13.0, *) {
                imageView.backgroundColor = UIColor.systemBackground
            } else {
                imageView.backgroundColor = UIColor.white
            }
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
        guard let imageView = view as? UIImageView else { return false }
        
        // Set image source if specified - with proper type checking
        if let sourceAny = props["source"] {
            let source: String
            
            // Handle different source types safely
            if let sourceString = sourceAny as? String {
                source = sourceString
            } else if let sourceNumber = sourceAny as? NSNumber {
                source = sourceNumber.stringValue
            } else {
                print("❌ Invalid source type: \(type(of: sourceAny))")
                propagateEvent(on: imageView, eventName: "onError", data: ["error": "Invalid source type"])
                return false
            }
            
            // Validate source is not empty
            guard !source.isEmpty else {
                propagateEvent(on: imageView, eventName: "onError", data: ["error": "Empty source"])
                return false
            }
            
            let key = sharedFlutterViewController?.lookupKey(forAsset: source)
            let mainBundle = Bundle.main
            let path = mainBundle.path(forResource: key, ofType: nil)
            
            if !source.hasPrefix("https://") && !source.hasPrefix("http://") {
                if let validPath = path {
                    loadImage(from: validPath, into: imageView, isLocal: true)
                } else {
                    loadImage(from: source, into: imageView, isLocal: true)
                }
            } else {
                loadImage(from: source, into: imageView, isLocal: false)
            }
        }
        
        // Set resize mode if specified
        if let resizeMode = props["resizeMode"] as? String {
            switch resizeMode {
            case "cover":
                imageView.contentMode = .scaleAspectFill
            case "contain":
                imageView.contentMode = .scaleAspectFit
            case "stretch":
                imageView.contentMode = .scaleToFill
            case "center":
                imageView.contentMode = .center
            default:
                imageView.contentMode = .scaleAspectFill
            }
        }
        
        // Handle background color property - key fix for incremental updates
        if props.keys.contains("backgroundColor") {
            if let backgroundColor = props["backgroundColor"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: backgroundColor)
                imageView.backgroundColor = uiColor
                print("🎨 DCFImageComponent: Set background color to: \(backgroundColor) -> \(uiColor)")
            } else {
                print("⚠️ DCFImageComponent: backgroundColor prop present but invalid value: \(props["backgroundColor"] ?? "nil")")
            }
        }
        
        // Handle adaptive color only if explicitly provided and no backgroundColor is set
        if props.keys.contains("adaptive") && !props.keys.contains("backgroundColor") {
            let isAdaptive = props["adaptive"] as? Bool ?? true
            if isAdaptive {
                if #available(iOS 13.0, *) {
                    imageView.backgroundColor = UIColor.systemBackground
                } else {
                    imageView.backgroundColor = UIColor.white
                }
            }
        }
        
        // Apply StyleSheet properties
        imageView.applyStyles(props: props)
        
        return true
    }
    
    // Load image from URL or resource with improved error handling and thread safety
    private func loadImage(from source: String, into imageView: UIImageView, isLocal: Bool = false) {
        // Validate source
        guard !source.isEmpty else {
            propagateEvent(on: imageView, eventName: "onError", data: ["error": "Empty source"])
            return
        }
        
        // Create a safe cache key - ensure it's always a string
        let cacheKey = String(describing: source)
        
        // Check cache first - thread-safe
        if let cachedImage = DCFImageComponent.getCachedImage(for: cacheKey) {
            DispatchQueue.main.async {
                imageView.image = cachedImage
                propagateEvent(on: imageView, eventName: "onLoad", data: [:])
            }
            return
        }
        
        if !isLocal && (source.hasPrefix("http://") || source.hasPrefix("https://")) {
            // Load from URL
            guard let url = URL(string: source) else {
                print("❌ Invalid URL: \(source)")
                propagateEvent(on: imageView, eventName: "onError", data: ["error": "Invalid URL"])
                return
            }
            
            // Load image asynchronously
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                do {
                    let data = try Data(contentsOf: url)
                    guard let image = UIImage(data: data) else {
                        DispatchQueue.main.async {
                            print("❌ Failed to create image from data for URL: \(source)")
                            propagateEvent(on: imageView, eventName: "onError", data: ["error": "Failed to create image from data"])
                        }
                        return
                    }
                    
                    // Cache the image safely - thread-safe
                    DCFImageComponent.setCachedImage(image, for: cacheKey)
                    
                    DispatchQueue.main.async {
                        // Double-check that imageView still exists and hasn't been deallocated
                        guard imageView.superview != nil else { return }
                        
                        UIView.transition(with: imageView, duration: 0.3, options: .transitionCrossDissolve, animations: {
                            imageView.image = image
                        }, completion: { _ in
                            propagateEvent(on: imageView, eventName: "onLoad", data: [:])
                        })
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("❌ Failed to load image from URL: \(source), error: \(error)")
                        propagateEvent(on: imageView, eventName: "onError", data: ["error": "Failed to load image from URL: \(error.localizedDescription)"])
                    }
                }
            }
        } else {
            // Handle local images
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                var image: UIImage?
                
                // Try different methods to load local image
                if FileManager.default.fileExists(atPath: source) {
                    image = UIImage(contentsOfFile: source)
                } else {
                    image = UIImage(named: source)
                }
                
                if let validImage = image {
                    // Cache the image safely - thread-safe
                    DCFImageComponent.setCachedImage(validImage, for: cacheKey)
                    
                    DispatchQueue.main.async {
                        // Double-check that imageView still exists
                        guard imageView.superview != nil else { return }
                        
                        imageView.image = validImage
                        propagateEvent(on: imageView, eventName: "onLoad", data: [:])
                    }
                } else {
                    print("❌ Failed to load local image: \(source)")
                    DispatchQueue.main.async {
                        propagateEvent(on: imageView, eventName: "onError", data: ["error": "Local image not found"])
                    }
                }
            }
        }
    }
    
    // Handle component methods
    func handleMethod(methodName: String, args: [String: Any], view: UIView) -> Bool {
        guard let imageView = view as? UIImageView else { return false }
        
        switch methodName {
        case "setImage":
            if let uriAny = args["uri"] {
                let uri: String
                
                // Handle different URI types safely
                if let uriString = uriAny as? String {
                    uri = uriString
                } else if let uriNumber = uriAny as? NSNumber {
                    uri = uriNumber.stringValue
                } else {
                    print("❌ Invalid URI type in setImage: \(type(of: uriAny))")
                    return false
                }
                
                guard !uri.isEmpty else {
                    return false
                }
                
                loadImage(from: uri, into: imageView)
                return true
            }
        case "reload":
            // Force reload the current image
            if imageView.image != nil {
                propagateEvent(on: imageView, eventName: "onLoad", data: [:])
                return true
            }
        case "clearCache":
            // Clear the entire image cache - thread-safe
            DCFImageComponent.clearAllCache()
            return true
        case "clearImageCache":
            // Clear cache for specific image - thread-safe
            if let sourceAny = args["source"] {
                let source = String(describing: sourceAny)
                DCFImageComponent.removeCachedImage(for: source)
                return true
            }
        default:
            return false
        }
        
        return false
    }
    
    // MARK: - Event Handling
    // Note: Image component uses global propagateEvent() system
    // No custom event methods needed - all handled by DCFComponentProtocol
}
