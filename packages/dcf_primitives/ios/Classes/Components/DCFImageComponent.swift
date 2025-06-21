/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import UIKit
import dcflight
import CoreImage

class DCFImageComponent: NSObject, DCFComponent {
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
            } else {
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
        
        // Handle commands if provided
        if let commandData = props["command"] as? [String: Any] {
            handleCommand(commandData, on: imageView)
        }
        
        // Apply StyleSheet properties
        imageView.applyStyles(props: props)
        
        return true
    }
    
    // MARK: - Command Handling
    
    private func handleCommand(_ command: [String: Any], on imageView: UIImageView) {
        guard let type = command["type"] as? String else { return }
        
        switch type {
        case "setImage":
            if let imageSource = command["imageSource"] as? String {
                let sourceType = command["sourceType"] as? String
                let animated = command["animated"] as? Bool ?? false
                let duration = command["duration"] as? Double ?? 0.3
                let transition = command["transition"] as? String ?? "fade"
                
                if animated {
                    handleAnimatedImageChange(imageView, source: imageSource, duration: duration, transition: transition)
                } else {
                    loadImage(from: imageSource, into: imageView, isLocal: sourceType != "url")
                }
            }
            
        case "clearCache":
            let clearAll = command["clearAll"] as? Bool ?? false
            if clearAll {
                DCFImageComponent.clearAllCache()
            } else if let imageUrl = command["imageUrl"] as? String {
                DCFImageComponent.removeCachedImage(for: imageUrl)
            }
            
        case "preloadImage":
            if let imageSource = command["imageSource"] as? String {
                let sourceType = command["sourceType"] as? String
                preloadImage(from: imageSource, isLocal: sourceType != "url")
            }
            
        case "resizeImage":
            if let width = command["width"] as? Double,
               let height = command["height"] as? Double {
                let maintainAspectRatio = command["maintainAspectRatio"] as? Bool ?? true
                let animated = command["animated"] as? Bool ?? false
                let duration = command["duration"] as? Double ?? 0.3
                
                let newSize = CGSize(width: width, height: height)
                
                if animated {
                    UIView.animate(withDuration: duration) {
                        imageView.frame.size = newSize
                        if maintainAspectRatio {
                            imageView.contentMode = .scaleAspectFit
                        } else {
                            imageView.contentMode = .scaleToFill
                        }
                    }
                } else {
                    imageView.frame.size = newSize
                    if maintainAspectRatio {
                        imageView.contentMode = .scaleAspectFit
                    } else {
                        imageView.contentMode = .scaleToFill
                    }
                }
            }
            
        case "applyImageFilter":
            if let filterType = command["filterType"] as? String {
                let intensity = command["intensity"] as? Double ?? 1.0
                let animated = command["animated"] as? Bool ?? false
                let duration = command["duration"] as? Double ?? 0.3
                
                applyImageFilter(to: imageView, filterType: filterType, intensity: intensity, animated: animated, duration: duration)
            }
            
        default:
            break
        }
    }
    
    private func handleAnimatedImageChange(_ imageView: UIImageView, source: String, duration: Double, transition: String) {
        switch transition {
        case "fade":
            UIView.transition(with: imageView, duration: duration, options: .transitionCrossDissolve, animations: {
                self.loadImage(from: source, into: imageView)
            }, completion: nil)
        case "slide":
            let oldFrame = imageView.frame
            UIView.animate(withDuration: duration / 2, animations: {
                imageView.frame.origin.x -= imageView.frame.width
            }) { _ in
                self.loadImage(from: source, into: imageView)
                imageView.frame.origin.x += imageView.frame.width * 2
                UIView.animate(withDuration: duration / 2) {
                    imageView.frame = oldFrame
                }
            }
        default:
            UIView.transition(with: imageView, duration: duration, options: .transitionCrossDissolve, animations: {
                self.loadImage(from: source, into: imageView)
            }, completion: nil)
        }
    }
    
    private func preloadImage(from source: String, isLocal: Bool = false) {
        let cacheKey = String(describing: source)
        
        // Check if already cached
        if DCFImageComponent.getCachedImage(for: cacheKey) != nil {
            return
        }
        
        if !isLocal && (source.hasPrefix("http://") || source.hasPrefix("https://")) {
            guard let url = URL(string: source) else { return }
            
            DispatchQueue.global(qos: .utility).async {
                do {
                    let data = try Data(contentsOf: url)
                    if let image = UIImage(data: data) {
                        DCFImageComponent.setCachedImage(image, for: cacheKey)
                    }
                } catch {
                    // Silently fail for preloading
                }
            }
        } else {
            DispatchQueue.global(qos: .utility).async {
                var image: UIImage?
                
                if FileManager.default.fileExists(atPath: source) {
                    image = UIImage(contentsOfFile: source)
                } else {
                    image = UIImage(named: source)
                }
                
                if let validImage = image {
                    DCFImageComponent.setCachedImage(validImage, for: cacheKey)
                }
            }
        }
    }
    
    private func applyImageFilter(to imageView: UIImageView, filterType: String, intensity: Double, animated: Bool, duration: Double) {
        guard let currentImage = imageView.image else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let filteredImage = self.createFilteredImage(currentImage, filterType: filterType, intensity: intensity)
            
            DispatchQueue.main.async {
                if animated {
                    UIView.transition(with: imageView, duration: duration, options: .transitionCrossDissolve, animations: {
                        imageView.image = filteredImage
                    }, completion: nil)
                } else {
                    imageView.image = filteredImage
                }
            }
        }
    }
    
    private func createFilteredImage(_ image: UIImage, filterType: String, intensity: Double) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let context = CIContext()
        var filter: CIFilter?
        
        switch filterType {
        case "blur":
            filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(intensity * 10, forKey: kCIInputRadiusKey)
        case "sepia":
            filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(intensity, forKey: kCIInputIntensityKey)
        case "grayscale":
            filter = CIFilter(name: "CIColorMonochrome")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(CIColor.gray, forKey: kCIInputColorKey)
            filter?.setValue(intensity, forKey: kCIInputIntensityKey)
        case "brightness":
            filter = CIFilter(name: "CIColorControls")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(intensity - 0.5, forKey: kCIInputBrightnessKey)
        case "contrast":
            filter = CIFilter(name: "CIColorControls")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(intensity, forKey: kCIInputContrastKey)
        default:
            return image
        }
        
        guard let outputImage = filter?.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    
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
                    DispatchQueue.main.async {
                        propagateEvent(on: imageView, eventName: "onError", data: ["error": "Local image not found"])
                    }
                }
            }
        }
    }
    
    // MARK: - Event Handling
    // Note: Image component uses global propagateEvent() system
    // No custom event methods needed - all handled by DCFComponentProtocol
}
