/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Bitmap
import android.view.View
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebChromeClient
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.R

/**
 * DCFWebViewComponent - WebView component matching iOS DCFWebViewComponent
 * Uses exact same prop names as iOS WKWebView for cross-platform consistency
 */
class DCFWebViewComponent : DCFComponent {

    override fun createView(context: Context, props: Map<String, Any>): View {
        val webView = WebView(context)

        // Enable JavaScript by default like iOS
        webView.settings.javaScriptEnabled = true

        // Store component type
        webView.setTag(R.id.dcf_component_type, "WebView")

        // Apply props
        updateView(webView, props)

        // Apply StyleSheet properties
        webView.applyStyles(props)

        return webView
    }

    override fun updateView(view: View, props: Map<String, Any>): Boolean {
        val webView = view as? WebView ?: return false

        // source - EXACT iOS prop name
        props["source"]?.let { source ->
            when (source) {
                is String -> {
                    // Direct URL string
                    webView.loadUrl(source)
                }

                is Map<*, *> -> {
                    // Source object with uri or html
                    val uri = source["uri"] as? String
                    val html = source["html"] as? String
                    val baseUrl = source["baseUrl"] as? String

                    when {
                        uri != null -> webView.loadUrl(uri)
                        html != null -> webView.loadDataWithBaseURL(
                            baseUrl,
                            html,
                            "text/html",
                            "UTF-8",
                            null
                        )
                    }
                }
            }
        }

        // javaScriptEnabled - EXACT iOS prop name
        props["javaScriptEnabled"]?.let { enabled ->
            webView.settings.javaScriptEnabled = enabled as? Boolean ?: true
        }

        // allowsInlineMediaPlayback - EXACT iOS prop name
        props["allowsInlineMediaPlayback"]?.let { allows ->
            if (allows as? Boolean == true) {
                webView.settings.mediaPlaybackRequiresUserGesture = false
            }
        }

        // mediaPlaybackRequiresUserAction - EXACT iOS prop name
        props["mediaPlaybackRequiresUserAction"]?.let { requires ->
            webView.settings.mediaPlaybackRequiresUserGesture = requires as? Boolean ?: true
        }

        // scalesPageToFit - EXACT iOS prop name
        props["scalesPageToFit"]?.let { scales ->
            val shouldScale = scales as? Boolean ?: false
            webView.settings.loadWithOverviewMode = shouldScale
            webView.settings.useWideViewPort = shouldScale
        }

        // domStorageEnabled - EXACT iOS prop name
        props["domStorageEnabled"]?.let { enabled ->
            webView.settings.domStorageEnabled = enabled as? Boolean ?: false
        }

        // userAgent - EXACT iOS prop name
        props["userAgent"]?.let { userAgent ->
            webView.settings.userAgentString = userAgent.toString()
        }

        // allowsBackForwardNavigationGestures - EXACT iOS prop name
        props["allowsBackForwardNavigationGestures"]?.let { allows ->
            // Android doesn't have built-in swipe navigation
            // Would need custom gesture detection
            webView.setTag(R.id.dcf_webview_navigation_gestures, allows)
        }

        // bounces - EXACT iOS prop name
        props["bounces"]?.let { bounces ->
            // Overscroll behavior
            webView.overScrollMode = if (bounces as? Boolean == true) {
                View.OVER_SCROLL_ALWAYS
            } else {
                View.OVER_SCROLL_NEVER
            }
        }

        // scrollEnabled - EXACT iOS prop name
        props["scrollEnabled"]?.let { enabled ->
            val isEnabled = enabled as? Boolean ?: true
            webView.isVerticalScrollBarEnabled = isEnabled
            webView.isHorizontalScrollBarEnabled = isEnabled
        }

        // showsHorizontalScrollIndicator - EXACT iOS prop name
        props["showsHorizontalScrollIndicator"]?.let { shows ->
            webView.isHorizontalScrollBarEnabled = shows as? Boolean ?: true
        }

        // showsVerticalScrollIndicator - EXACT iOS prop name
        props["showsVerticalScrollIndicator"]?.let { shows ->
            webView.isVerticalScrollBarEnabled = shows as? Boolean ?: true
        }

        // Set up WebViewClient for navigation callbacks
        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                // onLoadStart - EXACT iOS prop name
                props["onLoadStart"]?.let { onLoadStart ->
                    webView.setTag(R.id.dcf_event_callback, onLoadStart)
                    // Framework would handle the actual callback
                }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                // onLoadEnd - EXACT iOS prop name
                props["onLoadEnd"]?.let { onLoadEnd ->
                    webView.setTag(R.id.dcf_event_callback, onLoadEnd)
                    // Framework would handle the actual callback
                }
            }

            override fun onReceivedError(
                view: WebView?,
                errorCode: Int,
                description: String?,
                failingUrl: String?
            ) {
                super.onReceivedError(view, errorCode, description, failingUrl)
                // onError - EXACT iOS prop name
                props["onError"]?.let { onError ->
                    webView.setTag(R.id.dcf_event_callback, onError)
                    // Framework would handle the actual callback with error info
                }
            }

            override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                // onNavigationStateChange - EXACT iOS prop name
                props["onNavigationStateChange"]?.let { onChange ->
                    webView.setTag(R.id.dcf_event_callback, onChange)
                    // Framework would handle the actual callback
                }
                return false
            }
        }

        // Set up WebChromeClient for progress updates
        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                super.onProgressChanged(view, newProgress)
                // onLoadProgress - EXACT iOS prop name
                props["onLoadProgress"]?.let { onProgress ->
                    webView.setTag(R.id.dcf_webview_progress, newProgress / 100f)
                    webView.setTag(R.id.dcf_event_callback, onProgress)
                    // Framework would handle the actual callback
                }
            }
        }

        // Store clients for cleanup
        webView.setTag(R.id.dcf_webview_client, webView.webViewClient)
        webView.setTag(R.id.dcf_webview_chrome_client, webView.webChromeClient)

        // injectedJavaScript - EXACT iOS prop name
        props["injectedJavaScript"]?.let { script ->
            webView.evaluateJavascript(script.toString(), null)
        }

        // Accessibility
        props["accessibilityLabel"]?.let { label ->
            webView.contentDescription = label.toString()
        }

        props["testID"]?.let { testId ->
            webView.setTag(R.id.dcf_test_id, testId)
        }

        return true
    }
}
