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
    private static let cacheQueue = DispatchQueue(label: "com.dcf.imageCache", attributes: .concurrent)
    private static var _imageCache = [String: UIImage]()
    
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
        let imageView = UIImageView()
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        updateView(imageView, withProps: props)
        
        imageView.applyStyles(props: props)
        
        return imageView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let imageView = view as? UIImageView else { return false }
        
        if let sourceAny = props["source"] {
            let source: String
            
            if let sourceString = sourceAny as? String {
                source = sourceString
            } else if let sourceNumber = sourceAny as? NSNumber {
                source = sourceNumber.stringValue
            } else {
                propagateEvent(on: imageView, eventName: "onError", data: ["error": "Invalid source type"])
                return false
            }
            
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
        
        if props.keys.contains("backgroundColor") {
            if let backgroundColor = props["backgroundColor"] as? String {
                let uiColor = ColorUtilities.color(fromHexString: backgroundColor)
                imageView.backgroundColor = uiColor
            } else {
            }
        }
        
        if !props.keys.contains("backgroundColor") {
            imageView.backgroundColor = DCFTheme.getBackgroundColor(traitCollection: imageView.traitCollection)
        }
        
        imageView.applyStyles(props: props)
        
        return true
    }
    
    private func loadImage(from source: String, into imageView: UIImageView, isLocal: Bool = false) {
        guard !source.isEmpty else {
            propagateEvent(on: imageView, eventName: "onError", data: ["error": "Empty source"])
            return
        }
        
        let cacheKey = String(describing: source)
        
        if let cachedImage = DCFImageComponent.getCachedImage(for: cacheKey) {
            DispatchQueue.main.async {
                imageView.image = cachedImage
                propagateEvent(on: imageView, eventName: "onLoad", data: [:])
            }
            return
        }
        
        if !isLocal && (source.hasPrefix("http://") || source.hasPrefix("https://")) {
            guard let url = URL(string: source) else {
                propagateEvent(on: imageView, eventName: "onError", data: ["error": "Invalid URL"])
                return
            }
            
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
                    
                    DCFImageComponent.setCachedImage(image, for: cacheKey)
                    
                    DispatchQueue.main.async {
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
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                var image: UIImage?
                
                if FileManager.default.fileExists(atPath: source) {
                    image = UIImage(contentsOfFile: source)
                } else {
                    image = UIImage(named: source)
                }
                
                if let validImage = image {
                    DCFImageComponent.setCachedImage(validImage, for: cacheKey)
                    
                    DispatchQueue.main.async {
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
    
}
