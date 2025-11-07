/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import UIKit
import WebKit
import dcflight

class DCFWebViewComponent: NSObject, DCFComponent {
    private static let sharedInstance = DCFWebViewComponent()
    
    private var currentURL: String?
    
    required override init() {
        super.init()
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
        
        let configuration = WKWebViewConfiguration()
        
        let javaScriptEnabled = props["javaScriptEnabled"] as? Bool ?? true
        configuration.preferences.javaScriptEnabled = javaScriptEnabled
        
        let allowsInlineMediaPlayback = props["allowsInlineMediaPlayback"] as? Bool ?? true
        configuration.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        
        let mediaPlaybackRequiresUserAction = props["mediaPlaybackRequiresUserAction"] as? Bool ?? true
        configuration.mediaTypesRequiringUserActionForPlayback = mediaPlaybackRequiresUserAction ? .all : []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        
        webView.navigationDelegate = DCFWebViewComponent.sharedInstance
        webView.uiDelegate = DCFWebViewComponent.sharedInstance
        
        webView.addObserver(DCFWebViewComponent.sharedInstance, forKeyPath: "estimatedProgress", options: .new, context: nil)
        
        let userContentController = webView.configuration.userContentController
        userContentController.add(DCFWebViewComponent.sharedInstance, name: "dcfMessage")
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isOpaque = true
        // NO FALLBACK: backgroundColor comes from StyleSheet only
        // StyleSheet will always provide this via toMap() fallbacks
        
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
        
        if DCFWebViewComponent.sharedInstance.currentURL != source {
            DispatchQueue.main.async {
                DCFWebViewComponent.sharedInstance.loadContent(webView: webView, props: props)
            }
        }
        
        webView.scrollView.isScrollEnabled = props["scrollEnabled"] as? Bool ?? true
        webView.scrollView.showsHorizontalScrollIndicator = props["showsScrollIndicators"] as? Bool ?? true
        webView.scrollView.showsVerticalScrollIndicator = props["showsScrollIndicators"] as? Bool ?? true
        webView.scrollView.bounces = props["bounces"] as? Bool ?? true
        
        webView.applyStyles(props: props)
        return true
    }
    
    func applyLayout(_ view: UIView, layout: YGNodeLayout) {
        view.frame = CGRect(
            x: CGFloat(layout.left),
            y: CGFloat(layout.top),
            width: CGFloat(layout.width),
            height: CGFloat(layout.height)
        )
    }
    
    func getIntrinsicSize(_ view: UIView, forProps props: [String: Any]) -> CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
    
    func viewRegisteredWithShadowTree(_ view: UIView, nodeId: String) {
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
        
        
        currentURL = source
        
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
            webView.loadHTMLString(source, baseURL: nil)
            
        case "localFile":
            if let key = sharedFlutterViewController?.lookupKey(forAsset: source),
               let path = Bundle.main.path(forResource: key, ofType: nil),
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
}
