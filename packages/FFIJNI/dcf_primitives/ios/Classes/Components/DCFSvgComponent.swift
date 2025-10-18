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
    private static var imageCache = [String: SVGKImage]()
    
    static let svgKitInitialized: Bool = {
        if let displayScale = UIScreen.main.scale as CGFloat? {
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
        _ = DCFSvgComponent.svgKitInitialized
    }
    
    func createView(props: [String: Any]) -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        let isAdaptive = props["adaptive"] as? Bool ?? true
        if isAdaptive {
            imageView.backgroundColor = UIColor.clear
        } else {
            imageView.backgroundColor = UIColor.clear
        }
        
        updateView(imageView, withProps: props)
        
        imageView.applyStyles(props: props)
        
        return imageView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let imageView = view as? UIImageView else {
            return false
        }
        
        do {
            if let backgroundColor = props["backgroundColor"] as? String {
                imageView.backgroundColor = ColorUtilities.color(fromHexString: backgroundColor)
            } else {
                let isAdaptive = props["adaptive"] as? Bool ?? true
                if isAdaptive {
                    imageView.backgroundColor = UIColor.clear
                }
            }
            
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
                applyTintColor(to: imageView, props: props)
            }
            
            imageView.applyStyles(props: props)
            
            return true
        } catch {
            return false
        }
    }
    
    
    private func loadSvgFromAsset(_ asset: String, into imageView: UIImageView, props: [String: Any], isRel: Bool, path: String) {
        if let cachedImage = DCFSvgComponent.imageCache[asset] {
            applyCachedImageToView(cachedImage, imageView: imageView, props: props)
            propagateEvent(on: imageView, eventName: "onLoad", data: [:])
            return
        }
        
        if let svgImage = loadSVGFromAssetPath(asset, isRelativePath: isRel, path: path) {
            DCFSvgComponent.imageCache[asset] = svgImage
            
            applyCachedImageToView(svgImage, imageView: imageView, props: props)
            propagateEvent(on: imageView, eventName: "onLoad", data: [:])
        } else {
            propagateEvent(on: imageView, eventName: "onError", data: ["error": "SVG not found: \(asset)"])
        }
    }
    
    private func applyCachedImageToView(_ svgImage: SVGKImage, imageView: UIImageView, props: [String: Any]) {
        let hasTintColor = props["tintColor"] as? String != nil
        let isAdaptive = props["adaptive"] as? Bool ?? true
        
        if hasTintColor || isAdaptive {
            imageView.image = svgImage.uiImage?.withRenderingMode(.alwaysTemplate)
        } else {
            imageView.image = svgImage.uiImage?.withRenderingMode(.alwaysOriginal)
        }
        
        applyTintColor(to: imageView, props: props)
    }
    
    
    private func applyTintColor(to imageView: UIImageView, props: [String: Any]) {
        if let tintColorString = props["tintColor"] as? String,
           let tintColor = ColorUtilities.color(fromHexString: tintColorString) {
            imageView.tintColor = tintColor
            if let image = imageView.image {
                imageView.image = image.withRenderingMode(.alwaysTemplate)
            }
        } else {
            if props["tintColor"] == nil {
                let isAdaptive = props["adaptive"] as? Bool ?? true
                if isAdaptive {
                    if #available(iOS 13.0, *) {
                        imageView.tintColor = UIColor.label
                    } else {
                        imageView.tintColor = UIColor.black
                    }
                    if let image = imageView.image {
                        imageView.image = image.withRenderingMode(.alwaysTemplate)
                    }
                } else {
                    if let image = imageView.image {
                        imageView.image = image.withRenderingMode(.alwaysOriginal)
                    }
                    imageView.tintColor = nil
                }
            } else {
            }
        }
    }
    
    private func loadSVGFromAssetPath(_ asset: String, isRelativePath: Bool, path: String) -> SVGKImage? {
        if (asset.hasPrefix("/") || asset.contains(".")) && FileManager.default.fileExists(atPath: asset) && isRelativePath == false {
            return createSVGImageSafely(fromPath: asset)
        } else if asset.hasPrefix("http://") || asset.hasPrefix("https://") {
            if let url = URL(string: asset) {
                return createSVGImageSafely(fromURL: url)
            }
        } else if (isRelativePath == true) {
            return createSVGImageSafely(fromPath: path)
        }
        return nil
    }
    
    private func createSVGImageSafely(fromPath path: String) -> SVGKImage? {
        guard !path.isEmpty && FileManager.default.fileExists(atPath: path) else {
            print("❌ DCFSvgComponent: File does not exist at path: \(path)")
            return nil
        }
        
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

extension DCFSvgComponent {
    /// Force SVGKit initialization to prevent timing issues
    static func initializeSVGKit() {
        _ = svgKitInitialized
    }
}
