/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */



import Flutter
import UIKit

@objc open class DCFAppDelegate: FlutterAppDelegate {
    
    var flutterEngine: FlutterEngine?
    
    @objc public static func registerWithRegistrar(_ registrar: FlutterPluginRegistrar) {
    }
    
    override open func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
      self.flutterEngine = FlutterEngine(name: "io.dcflight.engine")
      self.flutterEngine?.run(withEntrypoint: "main", libraryURI: nil)
      
      
      divergeToFlight()
      
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
