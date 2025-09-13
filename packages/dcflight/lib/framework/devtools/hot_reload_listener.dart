/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:io';
import 'dart:convert';
import 'package:dcflight/framework/devtools/hot_reload.dart';

/// Hot reload listener that runs inside the DCFlight app
/// Listens for commands from the external file watcher
class HotReloadListener {
  static HttpServer? _server;
  static const int _port = 8765; // Hot reload communication port
  
  /// Start listening for hot reload commands from the watcher
  static Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      
      print('🔥 Hot reload listener started on port $_port (listening on all interfaces)');
      
      _server!.listen((HttpRequest request) async {
        // Handle CORS for development
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');
        
        if (request.method == 'OPTIONS') {
          request.response.statusCode = 200;
          await request.response.close();
          return;
        }
        
        if (request.method == 'POST' && request.uri.path == '/hot-reload') {
          try {
            print('🔥 Hot reload request received from watcher');
            
            // Trigger the manual hot reload
            triggerManualHotReload();
            
            // Send success response
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              'status': 'success',
              'message': 'Hot reload triggered successfully',
              'timestamp': DateTime.now().toIso8601String(),
            }));
            
          } catch (e) {
            print('❌ Hot reload error: $e');
            request.response.statusCode = 500;
            request.response.write(jsonEncode({
              'status': 'error',
              'message': e.toString(),
            }));
          }
        } else {
          // Health check endpoint
          request.response.statusCode = 200;
          request.response.write(jsonEncode({
            'status': 'listening',
            'service': 'DCFlight Hot Reload Listener',
            'port': _port,
          }));
        }
        
        await request.response.close();
      });
      
    } catch (e) {
      print('❌ Failed to start hot reload listener: $e');
    }
  }
  
  /// Stop the hot reload listener
  static Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      print('🔥 Hot reload listener stopped');
    }
  }
}

