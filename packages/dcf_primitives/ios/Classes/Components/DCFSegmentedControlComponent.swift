/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

class DCFSegmentedControlComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFSegmentedControlComponent()
    
    required override init() {
        super.init()
    }
    
    func createView(props: [String: Any]) -> UIView {
        
        var segments: [String] = []
        var iconAssets: [String] = []
        
        if let segmentArray = props["segments"] as? [[String: Any]] {
            for segmentData in segmentArray {
                if let title = segmentData["title"] as? String {
                    segments.append(title)
                    if let iconAsset = segmentData["iconAsset"] as? String {
                        iconAssets.append(iconAsset)
                    } else {
                        iconAssets.append("")
                    }
                }
            }
        } else if let segmentArray = props["segments"] as? [String] {
            segments = segmentArray
        } else if let segmentArray = props["segments"] as? [Any] {
            segments = segmentArray.compactMap { $0 as? String }
        }
        
        
        let segmentedControl = UISegmentedControl(items: segments.isEmpty ? ["Segment 1"] : segments)
        
        if !iconAssets.isEmpty {
            updateSegments(segmentedControl, segments: segments, iconAssets: iconAssets)
        }
        
        if #available(iOS 13.0, *) {
            if let selectedBgColor = ColorUtilities.getColor(
                explicitColor: "selectedBackgroundColor",
                semanticColor: "primaryColor",
                from: props
            ) {
                segmentedControl.selectedSegmentTintColor = selectedBgColor
            }
        }
        
        if let tintColor = ColorUtilities.getColor(
            explicitColor: "tintColor",
            semanticColor: "secondaryColor",
            from: props
        ) {
            segmentedControl.tintColor = tintColor
        }
        
        if let selectedIndex = props["selectedIndex"] as? Int,
           selectedIndex >= 0 && selectedIndex < segmentedControl.numberOfSegments {
            segmentedControl.selectedSegmentIndex = selectedIndex
        } else {
            segmentedControl.selectedSegmentIndex = 0
        }
        
        segmentedControl.addTarget(DCFSegmentedControlComponent.sharedInstance, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
        
        updateView(segmentedControl, withProps: props)
        return segmentedControl
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let segmentedControl = view as? UISegmentedControl else {
            return false
        }
        
        
        var segments: [String] = []
        var iconAssets: [String] = []
        
        if let segmentArray = props["segments"] as? [[String: Any]] {
            for segmentData in segmentArray {
                if let title = segmentData["title"] as? String {
                    segments.append(title)
                    if let iconAsset = segmentData["iconAsset"] as? String {
                        iconAssets.append(iconAsset)
                    } else {
                        iconAssets.append("")
                    }
                }
            }
            updateSegments(segmentedControl, segments: segments, iconAssets: iconAssets)
        } else if let segmentArray = props["segments"] as? [String] {
            segments = segmentArray
            updateSegments(segmentedControl, segments: segments, iconAssets: [])
        } else if let segmentArray = props["segments"] as? [Any] {
            segments = segmentArray.compactMap { $0 as? String }
            updateSegments(segmentedControl, segments: segments, iconAssets: [])
        }
        
        if let selectedIndex = props["selectedIndex"] as? Int {
            if selectedIndex >= 0 && selectedIndex < segmentedControl.numberOfSegments {
                segmentedControl.selectedSegmentIndex = selectedIndex
            } else {
            }
        }
        
        if let enabled = props["enabled"] as? Bool {
            segmentedControl.isEnabled = enabled
        }
        
        if #available(iOS 13.0, *) {
            if let selectedBgColor = ColorUtilities.getColor(
                explicitColor: "selectedBackgroundColor",
                semanticColor: "primaryColor",
                from: props
            ) {
                segmentedControl.selectedSegmentTintColor = selectedBgColor
            }
        }
        
        if let tintColor = ColorUtilities.getColor(
            explicitColor: "tintColor",
            semanticColor: "secondaryColor",
            from: props
        ) {
            segmentedControl.tintColor = tintColor
        }
        
        view.applyStyles(props: props)
        return true
    }
    
    private func updateSegments(_ segmentedControl: UISegmentedControl, segments: [String], iconAssets: [String] = []) {
        let currentSelection = segmentedControl.selectedSegmentIndex
        
        segmentedControl.removeAllSegments()
        
        for (index, segment) in segments.enumerated() {
            if index < iconAssets.count && !iconAssets[index].isEmpty {
                if let iconImage = loadIconImage(iconAssets[index]) {
                    segmentedControl.insertSegment(with: iconImage, at: index, animated: false)
                } else {
                    segmentedControl.insertSegment(withTitle: segment, at: index, animated: false)
                }
            } else {
                segmentedControl.insertSegment(withTitle: segment, at: index, animated: false)
            }
        }
        
        if currentSelection >= 0 && currentSelection < segments.count {
            segmentedControl.selectedSegmentIndex = currentSelection
        } else if !segments.isEmpty {
            segmentedControl.selectedSegmentIndex = 0
        }
        
    }
    
    @objc private func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        let selectedIndex = sender.selectedSegmentIndex
        let selectedTitle = sender.titleForSegment(at: selectedIndex) ?? ""
        
        
        let eventData: [String: Any] = [
            "selectedIndex": selectedIndex,
            "selectedTitle": selectedTitle
        ]
        
        
        propagateEvent(on: sender, eventName: "onSelectionChange", data: eventData) { view, data in
        }
    }
    
    
    private func loadIconImage(_ asset: String) -> UIImage? {
        
        let key = sharedFlutterViewController?.lookupKey(forAsset: asset)
        let mainBundle = Bundle.main
        
        if let assetKey = key,
           let path = mainBundle.path(forResource: assetKey, ofType: nil),
           let image = UIImage(contentsOfFile: path) {
            return image
        }
        
        if let image = UIImage(named: asset) {
            return image
        }
        
        return nil
    }

    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(
            x: CGFloat(layout.left),
            y: CGFloat(layout.top),
            width: CGFloat(layout.width),
            height: CGFloat(layout.height)
        )
        
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
    }
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}
