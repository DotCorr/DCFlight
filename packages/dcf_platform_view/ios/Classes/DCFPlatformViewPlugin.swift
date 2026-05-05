/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import Flutter
import UIKit

public class DCFPlatformViewPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let factory = DCFSurfaceViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "DCFSurface")
  }
}

@objc public class DCFSurfaceViewFactory: NSObject, FlutterPlatformViewFactory {
  private var messenger: FlutterBinaryMessenger
  private static var lastFrame: CGRect = .zero
  private static var activeView: DCFSurfaceNativeView?

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  public func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let view = DCFSurfaceNativeView(frame: frame, viewId: viewId)
    Self.activeView = view
    Self.lastFrame = frame
    return view
  }

  public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  /// Called from Dart via FFI (DCFPlatformViewFfi.m). ObjC name: updateSurfaceFrameWithX:y:width:height:
  @objc public static func updateSurfaceFrame(x: Double, y: Double, width: Double, height: Double) {
    let frame = CGRect(x: x, y: y, width: width, height: height)
    lastFrame = frame
    DispatchQueue.main.async {
      activeView?.updateFrame(frame)
    }
  }
}

/// C-callable entry point for FFI (no Swift header import in .m).
@_cdecl("dcplatformview_set_surface_frame_impl")
public func dcplatformviewSetSurfaceFrameImpl(x: Double, y: Double, width: Double, height: Double) {
  DCFSurfaceViewFactory.updateSurfaceFrame(x: x, y: y, width: width, height: height)
}

class DCFSurfaceNativeView: NSObject, FlutterPlatformView {
  private var _view: UIView

  init(frame: CGRect, viewId: Int64) {
    _view = UIView(frame: frame)
    _view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
    _view.layer.borderWidth = 3
    _view.layer.borderColor = UIColor.systemBlue.cgColor
    _view.layer.cornerRadius = 8
    let label = UILabel(frame: .zero)
    label.text = "Native UI (UIKit)"
    label.font = .systemFont(ofSize: 18, weight: .semibold)
    label.textColor = .systemBlue
    label.translatesAutoresizingMaskIntoConstraints = false
    _view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: _view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: _view.centerYAnchor),
    ])
    super.init()
  }

  func view() -> UIView {
    return _view
  }

  func updateFrame(_ frame: CGRect) {
    _view.frame = frame
  }
}
