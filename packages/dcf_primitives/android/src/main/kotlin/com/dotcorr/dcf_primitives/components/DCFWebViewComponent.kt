/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_primitives.components

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PointF
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.JavascriptInterface
import com.dotcorr.dcflight.components.DCFComponent
import com.dotcorr.dcflight.components.DCFNodeLayout
import com.dotcorr.dcflight.components.DCFTags
import com.dotcorr.dcflight.components.propagateEvent
import com.dotcorr.dcflight.extensions.applyStyles
import com.dotcorr.dcflight.layout.DCFLayoutManager
import com.dotcorr.dcflight.layout.ViewRegistry
import com.dotcorr.dcf_primitives.components.DCFPrimitiveTags
import org.json.JSONObject

class DCFWebViewComponent : DCFComponent() {

    private companion object {
        private const val TAG_LAST_SOURCE = -2001001
        private const val TAG_LAST_LOAD_MODE = -2001002
    }

    override fun applyLayout(view: View, layout: DCFNodeLayout) {
        val parent = view.parent as? ViewGroup

        // WebView sometimes receives a transiently tiny Yoga frame during navigation
        // while parent dimensions are already correct. Prefer parent bounds in that case.
        val useParentBounds = layout.width in 1f..99f && parent != null && parent.width > 200 && parent.height > 100

        if (useParentBounds) {
            view.layout(0, 0, parent.width, parent.height)
            return
        }

        super.applyLayout(view, layout)
    }

    override fun createView(context: Context, props: Map<String, Any?>): View {
        val webView = WebView(context)

        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.databaseEnabled = true
        webView.settings.allowFileAccess = true
        webView.settings.allowContentAccess = true
        webView.settings.allowFileAccessFromFileURLs = true
        webView.settings.allowUniversalAccessFromFileURLs = true
        webView.settings.setSupportZoom(false)
        webView.settings.builtInZoomControls = false
        webView.settings.displayZoomControls = false
        webView.settings.cacheMode = WebSettings.LOAD_DEFAULT
        webView.settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            webView.settings.safeBrowsingEnabled = true
        }

        // Dark background prevents white flash before WebGPU content renders
        webView.setBackgroundColor(android.graphics.Color.parseColor("#080808"))
        webView.setLayerType(android.view.View.LAYER_TYPE_NONE, null)
        webView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )

        webView.setTag(DCFTags.COMPONENT_TYPE_KEY, "WebView")
        webView.addJavascriptInterface(DCFWebViewJsBridge(webView), "__dcfNativeBridge")

        updateView(webView, props)

        val nonNullStyleProps = props.filterValues { it != null }.mapValues { it.value!! }
        webView.applyStyles(nonNullStyleProps)

        return webView
    }

    override fun updateView(view: View, props: Map<String, Any?>): Boolean {
        val webView = view as? WebView ?: return false
        
        // CRITICAL: Merge new props with existing stored props to preserve all properties
        val existingProps = getStoredProps(view)
        val mergedProps = mergeProps(existingProps, props)
        storeProps(view, mergedProps)
        
        val nonNullProps = mergedProps.filterValues { it != null }.mapValues { it.value!! }

        val updateLoadMode = mergedProps["loadMode"] as? String ?: "url"
        val newSource = mergedProps["source"]
        val sourceFingerprint = when (newSource) {
            is String -> "s:$newSource"
            is Map<*, *> -> {
                val uri = newSource["uri"] as? String
                val html = newSource["html"] as? String
                val baseUrl = newSource["baseUrl"] as? String
                "m:${uri ?: ""}|${baseUrl ?: ""}|${html ?: ""}"
            }
            else -> null
        }
        val previousSource = webView.getTag(TAG_LAST_SOURCE) as? String
        val previousLoadMode = webView.getTag(TAG_LAST_LOAD_MODE) as? String
        val shouldReload = sourceFingerprint != null &&
            (sourceFingerprint != previousSource || updateLoadMode != previousLoadMode)

        if (shouldReload) {
            when (newSource) {
                is String -> {
                    when (updateLoadMode) {
                        "htmlString" -> {
                            webView.loadDataWithBaseURL(
                                "http://localhost",
                                newSource,
                                "text/html",
                                "UTF-8",
                                null
                            )
                        }
                        else -> webView.loadUrl(newSource)
                    }
                }

                is Map<*, *> -> {
                    val uri = newSource["uri"] as? String
                    val html = newSource["html"] as? String
                    val baseUrl = newSource["baseUrl"] as? String

                    when {
                        uri != null -> webView.loadUrl(uri)
                        html != null -> webView.loadDataWithBaseURL(
                            baseUrl ?: "http://localhost",
                            html,
                            "text/html",
                            "UTF-8",
                            null
                        )
                    }
                }
            }
            webView.setTag(TAG_LAST_SOURCE, sourceFingerprint)
            webView.setTag(TAG_LAST_LOAD_MODE, updateLoadMode)
        }

        mergedProps["javaScriptEnabled"]?.let { enabled ->
            webView.settings.javaScriptEnabled = enabled as? Boolean ?: true
        }

        mergedProps["allowsInlineMediaPlayback"]?.let { allows ->
            if (allows as? Boolean == true) {
                webView.settings.mediaPlaybackRequiresUserGesture = false
            }
        }

        mergedProps["mediaPlaybackRequiresUserAction"]?.let { requires ->
            webView.settings.mediaPlaybackRequiresUserGesture = requires as? Boolean ?: true
        }

        mergedProps["scalesPageToFit"]?.let { scales ->
            val shouldScale = scales as? Boolean ?: false
            webView.settings.loadWithOverviewMode = shouldScale
            webView.settings.useWideViewPort = shouldScale
        }

        mergedProps["domStorageEnabled"]?.let { enabled ->
            webView.settings.domStorageEnabled = enabled as? Boolean ?: false
        }

        mergedProps["userAgent"]?.let { userAgent ->
            webView.settings.userAgentString = userAgent.toString()
        }

        mergedProps["allowsBackForwardNavigationGestures"]?.let { allows ->
            webView.setTag(DCFPrimitiveTags.WEBVIEW_NAVIGATION_GESTURES_KEY, allows)
        }

        mergedProps["bounces"]?.let { bounces ->
            webView.overScrollMode = if (bounces as? Boolean == true) {
                View.OVER_SCROLL_ALWAYS
            } else {
                View.OVER_SCROLL_NEVER
            }
        }

        mergedProps["scrollEnabled"]?.let { enabled ->
            val isEnabled = enabled as? Boolean ?: true
            webView.isVerticalScrollBarEnabled = isEnabled
            webView.isHorizontalScrollBarEnabled = isEnabled
        }

        mergedProps["showsScrollIndicators"]?.let { shows ->
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
                view?.post {
                    view.requestLayout()
                    view.invalidate()
                    installDcfMessageShim(view)
                }
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

        mergedProps["injectedJavaScript"]?.let { script ->
            webView.evaluateJavascript(script.toString(), null)
        }

        webView.applyStyles(nonNullProps)

        fun tryExpandCollapsedWidth(attempt: Int = 0) {
            webView.post {
                val parentWidth = (webView.parent as? View)?.width ?: 0
                if (webView.width <= 24 && parentWidth > 0) {
                    val params = webView.layoutParams
                    params.width = parentWidth
                    webView.layoutParams = params
                    webView.requestLayout()
                    webView.invalidate()
                    return@post
                }

                if (webView.width <= 24 && attempt < 8) {
                    webView.postDelayed({ tryExpandCollapsedWidth(attempt + 1) }, 16)
                }
            }
        }

        val requestedWidth = mergedProps["width"]
        if ((requestedWidth is String && requestedWidth.trim().endsWith("%")) || webView.width <= 24) {
            tryExpandCollapsedWidth()
        }

        return true
    }


    override fun viewRegisteredWithShadowTree(view: View, shadowNode: com.dotcorr.dcflight.layout.DCFShadowNode, nodeId: String) {
        // Register this WebView with the ViewRegistry so it can be accessed by viewId
        val viewId = nodeId.toIntOrNull() ?: return
        if (view is WebView) {
            ViewRegistry.shared.registerView(view, viewId, "WebView")
            android.util.Log.d("DCFWebViewComponent", "✅ DCFWebViewComponent registered: viewId=$viewId")
        }
    }

    override fun handleTunnelMethod(method: String, arguments: Map<String, Any?>): Any? {
        val viewId = (arguments["viewId"] as? Number)?.toInt() ?: return null
        val webView = (ViewRegistry.shared.getView(viewId) ?: DCFLayoutManager.shared.getView(viewId)) as? WebView
            ?: return null

        return when (method) {
            "evaluateJavaScript" -> {
                val script = arguments["script"] as? String ?: return null
                webView.post {
                    webView.evaluateJavascript(script, null)
                }
                true
            }

            "postMessage" -> {
                val message = arguments["message"]
                val literal = toJavaScriptLiteral(message)
                val script = """
                    (function() {
                      const payload = $literal;
                      if (window.dcfBridge && typeof window.dcfBridge.onNativeMessage === 'function') {
                        window.dcfBridge.onNativeMessage(payload);
                      }
                      window.dispatchEvent(new CustomEvent('dcf:message', { detail: payload }));
                    })();
                """.trimIndent()
                webView.post {
                    webView.evaluateJavascript(script, null)
                }
                true
            }

            "reload" -> {
                webView.post { webView.reload() }
                true
            }

            "goBack" -> {
                webView.post {
                    if (webView.canGoBack()) {
                        webView.goBack()
                    }
                }
                true
            }

            "goForward" -> {
                webView.post {
                    if (webView.canGoForward()) {
                        webView.goForward()
                    }
                }
                true
            }

            else -> null
        }
    }

    private fun installDcfMessageShim(webView: WebView) {
        val shim = """
            (function() {
              if (!window.webkit) { window.webkit = {}; }
              if (!window.webkit.messageHandlers) { window.webkit.messageHandlers = {}; }
              window.webkit.messageHandlers.dcfMessage = {
                postMessage: function(message) {
                  try {
                    var payload = (typeof message === 'string') ? message : JSON.stringify(message);
                    __dcfNativeBridge.postMessage(payload);
                  } catch (e) {
                    __dcfNativeBridge.postMessage(String(message));
                  }
                }
              };
            })();
        """.trimIndent()
        webView.evaluateJavascript(shim, null)
    }

    private fun toJavaScriptLiteral(value: Any?): String {
        if (value == null) return "null"
        return when (value) {
            is String -> JSONObject.quote(value)
            is Number, is Boolean -> value.toString()
            else -> JSONObject.wrap(value)?.toString() ?: "null"
        }
    }
}

private class DCFWebViewJsBridge(private val webView: WebView) {
    @JavascriptInterface
    fun postMessage(payload: String?) {
        webView.post {
            propagateEvent(webView, "onMessage", mapOf(
                "data" to (payload ?: "null")
            ))
        }
    }
}

