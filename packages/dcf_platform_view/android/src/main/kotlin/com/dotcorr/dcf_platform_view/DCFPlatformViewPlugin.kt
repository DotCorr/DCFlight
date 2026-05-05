/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

package com.dotcorr.dcf_platform_view

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin

class DCFPlatformViewPlugin : FlutterPlugin {

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    System.loadLibrary("dcf_platform_view_ffi")
    binding.platformViewRegistry.registerViewFactory(
      "DCFSurface",
      DCFSurfaceViewFactory(binding.binaryMessenger)
    )
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}

class DCFSurfaceViewFactory(private val messenger: io.flutter.plugin.common.BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

  override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
    return DCFSurfaceNativeView(context!!, viewId)
  }

  companion object {
    @Volatile
    var activeView: DCFSurfaceNativeView? = null
      private set

    fun setActive(v: DCFSurfaceNativeView?) {
      activeView = v
    }

    /** Called from native (dcf_platform_view_ffi.c) via JNI from Dart FFI. */
    @JvmStatic
    fun updateSurfaceFrameNative(x: Double, y: Double, width: Double, height: Double) {
      updateSurfaceFrame(x, y, width, height)
    }

    fun updateSurfaceFrame(x: Double, y: Double, width: Double, height: Double) {
      android.os.Handler(android.os.Looper.getMainLooper()).post {
        activeView?.updateFrame(android.graphics.RectF(x.toFloat(), y.toFloat(), (x + width).toFloat(), (y + height).toFloat()))
      }
    }
  }
}

class DCFSurfaceNativeView(private val context: Context, viewId: Int) : PlatformView {

  private val view = android.widget.LinearLayout(context).apply {
    orientation = android.widget.LinearLayout.VERTICAL
    setBackgroundColor(android.graphics.Color.parseColor("#1A1E8CFF"))
    setPadding(24, 24, 24, 24)
    addView(android.widget.TextView(context).apply {
      text = "Native UI (Android View)"
      setTextColor(android.graphics.Color.parseColor("#1E88E5"))
      textSize = 18f
      setTypeface(null, android.graphics.Typeface.BOLD)
    })
  }

  init {
    DCFSurfaceViewFactory.setActive(this)
  }

  override fun getView(): android.view.View = view

  override fun dispose() {
    if (DCFSurfaceViewFactory.activeView == this) {
      DCFSurfaceViewFactory.setActive(null)
    }
  }

  fun updateFrame(rect: android.graphics.RectF) {
    view.layout(
      rect.left.toInt(),
      rect.top.toInt(),
      rect.right.toInt(),
      rect.bottom.toInt()
    )
  }
}
