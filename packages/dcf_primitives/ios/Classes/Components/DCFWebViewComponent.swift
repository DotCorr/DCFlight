/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import Foundation
import UIKit
import WebKit
import ObjectiveC.runtime
import dcflight

class DCFWebViewComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFWebViewComponent()
    private static var fillScrollContentKey: UInt8 = 0
    private static var sourceKey: UInt8 = 0

        // MARK: - Warm Pool
        // Pre-initialized WKWebViews kept offscreen so that when a surface mounts,
        // the WebKit rendering process is already running (eliminates ~200-350ms cold-start).
        private static var warmPool: [WKWebView] = []

        /// Call once after startup to warm the WebKit process without blocking first frame.
        static func prewarm(count: Int = 1) {
            guard Thread.isMainThread else {
                DispatchQueue.main.async { prewarm(count: count) }
                return
            }
            let toCreate = max(0, count - warmPool.count)
            guard toCreate > 0 else { return }

            for _ in 0..<toCreate {
                let config = WKWebViewConfiguration()
                config.preferences.javaScriptEnabled = true
                config.allowsInlineMediaPlayback = true
                config.mediaTypesRequiringUserActionForPlayback = []
                config.userContentController.add(sharedInstance, name: "dcfMessage")

                // Place well offscreen so it is invisible but fully initialized
                let warmView = WKWebView(
                    frame: CGRect(x: -9999, y: -9999, width: 393, height: 852),
                    configuration: config
                )
                if #available(iOS 16.4, *) { warmView.isInspectable = true }
                warmView.backgroundColor = UIColor(red: 8/255, green: 8/255, blue: 8/255, alpha: 1.0)
                warmView.scrollView.backgroundColor = UIColor(red: 8/255, green: 8/255, blue: 8/255, alpha: 1.0)
                warmView.translatesAutoresizingMaskIntoConstraints = true
                warmView.isOpaque = true
                warmView.isHidden = true

                warmPool.append(warmView)
            }
            print("🔥 DCFWebViewComponent: prewarmed \(toCreate) WebViews, pool size=\(warmPool.count)")
        }

        private static func popWarmView() -> WKWebView? {
            guard !warmPool.isEmpty else { return nil }
            let view = warmPool.removeLast()
            view.removeFromSuperview()
            view.isHidden = false
            view.navigationDelegate = sharedInstance
            view.uiDelegate = sharedInstance
            view.addObserver(sharedInstance, forKeyPath: "estimatedProgress", options: .new, context: nil)

            // Replenish pool asynchronously so future mounts are also instant
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                prewarm(count: 1)
            }
            print("🔥 DCFWebViewComponent: popped warm WebView from pool, remaining=\(warmPool.count)")
            return view
        }
    
    required override init() {
        super.init()
    }

    private func setFillScrollContent(_ webView: WKWebView, enabled: Bool) {
        objc_setAssociatedObject(
            webView,
            &DCFWebViewComponent.fillScrollContentKey,
            enabled,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private func isFillScrollContent(_ webView: WKWebView) -> Bool {
        objc_getAssociatedObject(webView, &DCFWebViewComponent.fillScrollContentKey) as? Bool ?? false
    }

    private func updateFillScrollContentFlag(_ webView: WKWebView, props: [String: Any]) {
        let flexGrowValue = numericValue(props["flexGrow"])
        let flexShrinkValue = numericValue(props["flexShrink"])
        let enabled = (flexGrowValue ?? 0) > 0 && (flexShrinkValue ?? 1) <= 0
        setFillScrollContent(webView, enabled: enabled)
    }

    private func numericValue(_ value: Any?) -> CGFloat? {
        if let number = value as? NSNumber {
            return CGFloat(truncating: number)
        }
        if let doubleValue = value as? Double {
            return CGFloat(doubleValue)
        }
        if let intValue = value as? Int {
            return CGFloat(intValue)
        }
        return nil
    }
    
    func createView(props: [String: Any]) -> UIView {
    print("🔧 DCFWebViewComponent: Found props keys: \(Array(props.keys))")
    
    let eventTypes = props.keys.filter { $0.hasPrefix("on") }
    print("🔧 DCFWebViewComponent: Extracted event types: \(eventTypes)")
    
        guard Thread.isMainThread else {
            return DispatchQueue.main.sync {
                return createView(props: props)
            }
        }
        
            // ── Fast path: reuse a pre-warmed WebView (no cold-start latency) ──────────
            if let warmView = DCFWebViewComponent.popWarmView() {
                warmView.scrollView.isScrollEnabled = props["scrollEnabled"] as? Bool ?? true
                warmView.scrollView.showsHorizontalScrollIndicator = props["showsScrollIndicators"] as? Bool ?? true
                warmView.scrollView.showsVerticalScrollIndicator = props["showsScrollIndicators"] as? Bool ?? true
                warmView.scrollView.bounces = props["bounces"] as? Bool ?? true

                if let userAgent = props["userAgent"] as? String {
                    warmView.customUserAgent = userAgent
                }
                if #available(iOS 11.0, *) {
                    warmView.scrollView.contentInsetAdjustmentBehavior =
                        (props["automaticallyAdjustContentInsets"] as? Bool ?? true) ? .automatic : .never
                }
                updateFillScrollContentFlag(warmView, props: props)
                DispatchQueue.main.async {
                    DCFWebViewComponent.sharedInstance.loadContent(webView: warmView, props: props)
                }
                return warmView
            }

            // ── Cold path: create a fresh WebView (pool was empty) ───────────────────
            let configuration = WKWebViewConfiguration()

            let javaScriptEnabled = props["javaScriptEnabled"] as? Bool ?? true
            configuration.preferences.javaScriptEnabled = javaScriptEnabled

            // Do not set private/undefined WKPreferences keys here.
            // KVC with unsupported keys (like "WebGPUEnabled" on some runtimes)
            // crashes the app with NSUnknownKeyException.
        
            let allowsInlineMediaPlayback = props["allowsInlineMediaPlayback"] as? Bool ?? true
            configuration.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        let mediaPlaybackRequiresUserAction = props["mediaPlaybackRequiresUserAction"] as? Bool ?? true
        configuration.mediaTypesRequiringUserActionForPlayback = mediaPlaybackRequiresUserAction ? .all : []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // CRITICAL: isInspectable=true is required on iOS 16.4+ for GPU access in local HTML
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        
        // Set dark background to prevent white flash before WebGPU content loads
        webView.backgroundColor = UIColor(red: 8/255, green: 8/255, blue: 8/255, alpha: 1.0)
        webView.scrollView.backgroundColor = UIColor(red: 8/255, green: 8/255, blue: 8/255, alpha: 1.0)
        
        webView.navigationDelegate = DCFWebViewComponent.sharedInstance
        webView.uiDelegate = DCFWebViewComponent.sharedInstance
        
        webView.addObserver(DCFWebViewComponent.sharedInstance, forKeyPath: "estimatedProgress", options: .new, context: nil)
        
        let userContentController = webView.configuration.userContentController
        userContentController.add(DCFWebViewComponent.sharedInstance, name: "dcfMessage")
        
        // DCF layout applies frames directly; keep autoresizing-mask translation enabled
        // to avoid AutoLayout collapsing WKWebView when no constraints are provided.
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.isOpaque = true
        
        let allowsZoom = props["allowsZoom"] as? Bool ?? true
        webView.scrollView.isScrollEnabled = props["scrollEnabled"] as? Bool ?? true
        webView.scrollView.showsHorizontalScrollIndicator = props["showsScrollIndicators"] as? Bool ?? true
        webView.scrollView.showsVerticalScrollIndicator = props["showsScrollIndicators"] as? Bool ?? true
        webView.scrollView.bounces = props["bounces"] as? Bool ?? true
        
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = 
                (props["automaticallyAdjustContentInsets"] as? Bool ?? true) ? .automatic : .never
        }
        
        if let userAgent = props["userAgent"] as? String {
            webView.customUserAgent = userAgent
        }

        updateFillScrollContentFlag(webView, props: props)
        
        DispatchQueue.main.async {
            DCFWebViewComponent.sharedInstance.loadContent(webView: webView, props: props)
        }
        
        return webView
    }
    
    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let webView = view as? WKWebView else { 
            return false 
        }
        
        let source = props["source"] as? String ?? ""
        let previousSource = objc_getAssociatedObject(webView, &DCFWebViewComponent.sourceKey) as? String

        if previousSource != source {
            DispatchQueue.main.async {
                DCFWebViewComponent.sharedInstance.loadContent(webView: webView, props: props)
            }
            objc_setAssociatedObject(
                webView,
                &DCFWebViewComponent.sourceKey,
                source,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }

        updateFillScrollContentFlag(webView, props: props)
        
        webView.scrollView.isScrollEnabled = props["scrollEnabled"] as? Bool ?? true
        webView.scrollView.showsHorizontalScrollIndicator = props["showsScrollIndicators"] as? Bool ?? true
        webView.scrollView.showsVerticalScrollIndicator = props["showsScrollIndicators"] as? Bool ?? true
        webView.scrollView.bounces = props["bounces"] as? Bool ?? true
        
        webView.applyStyles(props: props)
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        guard let webView = view as? WKWebView else { return }

        let layoutWidth = CGFloat(layout.width)
        let layoutHeight = CGFloat(layout.height)
        let needsWidthFallback = layoutWidth <= 1 || layoutWidth < 100
        let fillScrollContent = isFillScrollContent(webView)

        // Return the first ancestor that is meaningfully wider than the current
        // Yoga width. This addresses nested percentage-width containers that can
        // transiently report a narrow value during early layout passes.
        func findPromotedAncestor(from v: UIView, currentWidth: CGFloat) -> UIView? {
            var node: UIView? = v.superview
            while let current = node {
                let w = current.bounds.width
                if w > 100 && w > currentWidth + 40 {
                    return current
                }
                node = current.superview
            }
            return nil
        }

        let promotedAncestor = findPromotedAncestor(from: view, currentWidth: layoutWidth)
        let shouldPromoteNarrowWidth = promotedAncestor != nil && layoutWidth < 320

        let resolvedWidth: CGFloat
        if needsWidthFallback {
            resolvedWidth = promotedAncestor?.bounds.width ?? layoutWidth
        } else if shouldPromoteNarrowWidth {
            resolvedWidth = promotedAncestor?.bounds.width ?? layoutWidth
        } else {
            resolvedWidth = layoutWidth
        }

        var targetX = CGFloat(layout.left)
        var targetWidth = resolvedWidth
        if fillScrollContent {
            targetX = 0
            let viewportWidth = webView.window?.bounds.width ?? UIScreen.main.bounds.width
            targetWidth = max(viewportWidth, resolvedWidth)
        } else if resolvedWidth > layoutWidth + 1,
           let parent = view.superview,
           let ancestor = promotedAncestor {
            let promotedRectInParent = parent.convert(ancestor.bounds, from: ancestor)
            let clampedRect = promotedRectInParent.intersection(parent.bounds)
            if !clampedRect.isNull && clampedRect.width > 1 {
                targetX = clampedRect.origin.x
                targetWidth = clampedRect.width
            } else {
                targetX = promotedRectInParent.origin.x
                targetWidth = promotedRectInParent.width
            }
        }
        let targetFrame = CGRect(
            x: targetX,
            y: CGFloat(layout.top),
            width: targetWidth,
            height: layoutHeight
        )
        print("📐 DCFWebViewComponent applyLayout frame=\(targetFrame) layout=(\(layoutWidth), \(layoutHeight))")
        view.frame = targetFrame

        // After layout settles, one more reconciliation pass ensures the webview
        // catches up if parent widths finalize after this apply call.
        DispatchQueue.main.async {
            if fillScrollContent {
                let viewportWidth = webView.window?.bounds.width ?? UIScreen.main.bounds.width
                let finalRect = CGRect(x: 0, y: webView.frame.origin.y, width: viewportWidth, height: webView.frame.height)
                if abs(webView.frame.width - finalRect.width) > 1 || webView.frame.origin.x != 0 {
                    print("📐 DCFWebViewComponent async reconcile pin=\(finalRect)")
                    webView.frame = finalRect
                    webView.setNeedsLayout()
                    webView.layoutIfNeeded()
                }
            } else if let ancestor = findPromotedAncestor(from: webView, currentWidth: webView.frame.width),
                      let parent = webView.superview,
                      webView.frame.width + 1 < ancestor.bounds.width {
                let promotedRectInParent = parent.convert(ancestor.bounds, from: ancestor)
                let clampedRect = promotedRectInParent.intersection(parent.bounds)
                let finalRect: CGRect
                if !clampedRect.isNull && clampedRect.width > 1 {
                    finalRect = clampedRect
                } else {
                    finalRect = promotedRectInParent
                }
                print("📐 DCFWebViewComponent async reconcile frame=\(finalRect)")
                webView.frame = CGRect(
                    x: finalRect.origin.x,
                    y: webView.frame.origin.y,
                    width: finalRect.width,
                    height: webView.frame.height
                )
                webView.setNeedsLayout()
                webView.layoutIfNeeded()
            }
            webView.evaluateJavaScript("window.dispatchEvent(new Event('resize'));", completionHandler: nil)
        }
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, shadowView: DCFShadowView, nodeId: String) {
    }
    
    private func loadContent(webView: WKWebView, props: [String: Any]) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.loadContent(webView: webView, props: props)
            }
            return
        }
        
        let source = props["source"] as? String ?? ""
        let loadMode = props["loadMode"] as? String ?? "url"
        let contentType = props["contentType"] as? String ?? "html"
        
        webView.isHidden = false
        webView.alpha = 1.0
        
        switch loadMode {
        case "url":
            if source.isEmpty {
                return
            }
            
            guard let url = URL(string: source) else {
                return
            }
            
            var request = URLRequest(url: url)
            
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 30.0
            
            webView.load(request)
            
        case "htmlString":
            // CRITICAL: baseURL must NOT be nil for WebGPU (navigator.gpu) to work.
            // When baseURL is nil, content loads as about:blank which WebKit restricts
            // from GPU access. Using http://localhost as the base origin enables WebGPU.
            webView.loadHTMLString(source, baseURL: URL(string: "http://localhost"))
            
        case "localFile":
            if let path = DCFAssetLookup.path(forAsset: source),
               let fileURL = URL(string: "file://" + path) {
                
                if #available(iOS 9.0, *) {
                    webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
                } else {
                    if let data = try? Data(contentsOf: fileURL) {
                        let mimeType = mimeTypeForContentType(contentType)
                        webView.load(data, mimeType: mimeType, characterEncodingName: "UTF-8", baseURL: fileURL.deletingLastPathComponent())
                    }
                }
            } else {
                if let fileURL = URL(string: source.hasPrefix("file://") ? source : "file://" + source) {
                    if #available(iOS 9.0, *) {
                        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
                    } else {
                        if let data = try? Data(contentsOf: fileURL) {
                            let mimeType = mimeTypeForContentType(contentType)
                            webView.load(data, mimeType: mimeType, characterEncodingName: "UTF-8", baseURL: fileURL.deletingLastPathComponent())
                        }
                    }
                }
            }
            
        default:
            break
        }
    }
    
    private func mimeTypeForContentType(_ contentType: String) -> String {
        switch contentType {
        case "html":
            return "text/html"
        case "pdf":
            return "application/pdf"
        case "markdown":
            return "text/markdown"
        case "text":
            return "text/plain"
        default:
            return "text/html"
        }
    }
}

extension DCFWebViewComponent: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        
        propagateEvent(on: webView, eventName: "onLoadStart", data: [
            "url": webView.url?.absoluteString ?? "",
            "title": webView.title ?? ""
        ])
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        DispatchQueue.main.async {
            webView.setNeedsLayout()
            webView.layoutIfNeeded()
            webView.evaluateJavaScript("window.dispatchEvent(new Event('resize'));", completionHandler: nil)
        }
        
        propagateEvent(on: webView, eventName: "onLoadEnd", data: [
            "url": webView.url?.absoluteString ?? "",
            "title": webView.title ?? ""
        ])
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        
        propagateEvent(on: webView, eventName: "onLoadError", data: [
            "error": error.localizedDescription,
            "code": (error as NSError).code,
            "url": webView.url?.absoluteString ?? ""
        ])
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        
        propagateEvent(on: webView, eventName: "onLoadError", data: [
            "error": error.localizedDescription,
            "code": (error as NSError).code,
            "url": webView.url?.absoluteString ?? ""
        ])
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url?.absoluteString ?? ""
        
        propagateEvent(on: webView, eventName: "onNavigationStateChange", data: [
            "url": url,
            "title": webView.title ?? "",
            "canGoBack": webView.canGoBack,
            "canGoForward": webView.canGoForward,
            "loading": webView.isLoading
        ])
        
        decisionHandler(.allow)
    }
}

extension DCFWebViewComponent: WKUIDelegate {
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler()
        })
        
        if let viewController = findViewController(from: webView) {
            viewController.present(alert, animated: true, completion: nil)
        } else {
            completionHandler()
        }
    }
    
    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(true)
        })
        
        if let viewController = findViewController(from: webView) {
            viewController.present(alert, animated: true, completion: nil)
        } else {
            completionHandler(false)
        }
    }
    
    private func findViewController(from view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while responder != nil {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            responder = responder?.next
        }
        return nil
    }
}

extension DCFWebViewComponent {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            if let webView = object as? WKWebView {
                let progress = webView.estimatedProgress
                propagateEvent(on: webView, eventName: "onLoadProgress", data: [
                    "progress": progress
                ])
            }
        }
    }
}

extension DCFWebViewComponent: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "dcfMessage" {
            if let webView = message.webView {
                propagateEvent(on: webView, eventName: "onMessage", data: [
                    "data": message.body
                ])
            }
        }
    }
    static func handleTunnelMethod(_ method: String, params: [String: Any]) -> Any? {
        return nil
    }
}

