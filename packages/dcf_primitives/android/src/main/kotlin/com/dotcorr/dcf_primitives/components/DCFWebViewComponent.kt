/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PointF
import android.view.View
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebChromeClient
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcf_primitives.components.DCFPrimitiveTags

class DCFWebViewComponent : DCFComponent() {

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val webView = WebView(context)

        webView.settings.javaScriptEnabled = true

        webView.setTag(DCFTags.COMPONENT_TYPE_KEY, "WebView")

        props["source"]?.let { source ->
            when (source) {
                is String -> {
                    webView.loadUrl(source)
                }
                is Map<*, *> -> {
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

        updateView(webView, props)

        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        webView.applyStyles(nonNullStyleProps)

        return webView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val webView = view as? WebView ?: return false
        val nonNullProps = props.filterValues { it != null }.mapValues { it.value!! }

        props["source"]?.let { newSource ->
            when (newSource) {
                is String -> {
                    webView.loadUrl(newSource)
                }

                is Map<*, *> -> {
                    val uri = newSource["uri"] as? String
                    val html = newSource["html"] as? String
                    val baseUrl = newSource["baseUrl"] as? String

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

        props["javaScriptEnabled"]?.let { enabled ->
            webView.settings.javaScriptEnabled = enabled as? Boolean ?: true
        }

        props["allowsInlineMediaPlayback"]?.let { allows ->
            if (allows as? Boolean == true) {
                webView.settings.mediaPlaybackRequiresUserGesture = false
            }
        }

        props["mediaPlaybackRequiresUserAction"]?.let { requires ->
            webView.settings.mediaPlaybackRequiresUserGesture = requires as? Boolean ?: true
        }

        props["scalesPageToFit"]?.let { scales ->
            val shouldScale = scales as? Boolean ?: false
            webView.settings.loadWithOverviewMode = shouldScale
            webView.settings.useWideViewPort = shouldScale
        }

        props["domStorageEnabled"]?.let { enabled ->
            webView.settings.domStorageEnabled = enabled as? Boolean ?: false
        }

        props["userAgent"]?.let { userAgent ->
            webView.settings.userAgentString = userAgent.toString()
        }

        props["allowsBackForwardNavigationGestures"]?.let { allows ->
            webView.setTag(DCFPrimitiveTags.WEBVIEW_NAVIGATION_GESTURES_KEY, allows)
        }

        props["bounces"]?.let { bounces ->
            webView.overScrollMode = if (bounces as? Boolean == true) {
                View.OVER_SCROLL_ALWAYS
            } else {
                View.OVER_SCROLL_NEVER
            }
        }

        props["scrollEnabled"]?.let { enabled ->
            val isEnabled = enabled as? Boolean ?: true
            webView.isVerticalScrollBarEnabled = isEnabled
            webView.isHorizontalScrollBarEnabled = isEnabled
        }

        props["showsScrollIndicators"]?.let { shows ->
            val showIndicators = shows as? Boolean ?: true
            webView.isHorizontalScrollBarEnabled = showIndicators
            webView.isVerticalScrollBarEnabled = showIndicators
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                if (view != null) {
                    propagateEvent(view, "onLoadStart", mapOf(
                        "url" to (url ?: ""),
                        "loading" to true
                    ))
                }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                if (view != null) {
                    propagateEvent(view, "onLoadEnd", mapOf(
                        "url" to (url ?: ""),
                        "loading" to false
                    ))
                }
            }

            override fun onReceivedError(
                view: WebView?,
                errorCode: Int,
                description: String?,
                failingUrl: String?
            ) {
                super.onReceivedError(view, errorCode, description, failingUrl)
                if (view != null) {
                    propagateEvent(view, "onLoadError", mapOf(
                        "error" to (description ?: "Unknown error"),
                        "errorCode" to errorCode,
                        "url" to (failingUrl ?: "")
                    ))
                }
            }

            override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                nonNullProps["onNavigationStateChange"]?.let { onChange ->
                    webView.setTag(DCFTags.EVENT_CALLBACK_KEY, onChange)
                }
                return false
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                super.onProgressChanged(view, newProgress)
                nonNullProps["onLoadProgress"]?.let { onProgress ->
                    webView.setTag(DCFPrimitiveTags.WEBVIEW_PROGRESS_KEY, newProgress / 100f)
                    webView.setTag(DCFTags.EVENT_CALLBACK_KEY, onProgress)
                }
            }
        }

        webView.setTag(DCFPrimitiveTags.WEBVIEW_CLIENT_KEY, webView.webViewClient)
        webView.setTag(DCFPrimitiveTags.WEBVIEW_CHROME_CLIENT_KEY, webView.webChromeClient)

        props["injectedJavaScript"]?.let { script ->
            webView.evaluateJavascript(script.toString(), null)
        }

        webView.applyStyles(nonNullProps)
        return true
    }


    override fun getIntrinsicSize(view: View, props: Map<String, Any>): PointF {
        val webView = view as? WebView ?: return PointF(0f, 0f)

        webView.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )

        val measuredWidth = webView.measuredWidth.toFloat()
        val measuredHeight = webView.measuredHeight.toFloat()

        return PointF(kotlin.math.max(1f, measuredWidth), kotlin.math.max(1f, measuredHeight))
    }

    override fun viewRegisteredWithShadowTree(view: View, nodeId: String) {
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        return null
    }
}

