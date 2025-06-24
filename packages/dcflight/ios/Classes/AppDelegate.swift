/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


//
//  AppDelegate.swift
//  Runner
//
//  Created by Tahiru Agbanwa on 4/15/25.
//

import Flutter
import UIKit

@objc open class DCFAppDelegate: FlutterAppDelegate {
    
    // Flutter engine instance that will be used by the whole app
    var flutterEngine: FlutterEngine?
    
    @objc public static func registerWithRegistrar(_ registrar: FlutterPluginRegistrar) {
        // Register the plugin with the Flutter engine
        
        // Set up method channels directly through the registrar
        let messenger = registrar.messenger()
        SysComponentsReg.registerComponents()
        // Initialize method channels for bridge and events
        DCMauiBridgeMethodChannel.shared.initialize(with: messenger)
        DCMauiEventMethodHandler.shared.initialize(with: messenger)
        // Note: Layout is now handled natively, no need for layout method channel
        // Note: Hot restart detection is now handled in DCMauiBridgeMethodChannel
    }
    
    override open func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
      // Create and run engine before diverging to ensure Dart code executes
      self.flutterEngine = FlutterEngine(name: "io.dcflight.engine")
      self.flutterEngine?.run(withEntrypoint: "main", libraryURI: nil)
      
      
      // Now diverge to DCFlight setup
      divergeToFlight()
      
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
