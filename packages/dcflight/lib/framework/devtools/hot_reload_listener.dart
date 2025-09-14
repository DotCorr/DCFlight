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
  static bool _isRunning = false;
  static String? _instanceId;
  
  /// Start listening for hot reload commands from the watcher
  static Future<void> start() async {
    print('🔥 HotReloadListener.start() called');
    
    // Prevent multiple instances
    if (_isRunning && _server != null) {
      print('🔥 Hot reload listener already running, stopping previous instance...');
      await stop();
    }
    
    try {
      print('🔥 Attempting to bind server to port $_port...');
      // For better emulator compatibility, try different binding approaches
      try {
        print('🔥 Trying to bind to 0.0.0.0...');
        _server = await HttpServer.bind('0.0.0.0', _port);
        print('🔥 Successfully bound to 0.0.0.0');
      } catch (e) {
        print('🔥 Failed to bind to 0.0.0.0, trying localhost...');
        _server = await HttpServer.bind('localhost', _port);
        print('🔥 Successfully bound to localhost');
      }
      _isRunning = true;
      _instanceId = DateTime.now().millisecondsSinceEpoch.toString();
      
      print('🔥 Hot reload listener started on port $_port (Instance: $_instanceId)');
      print('🔥 Server address: ${_server!.address}:${_server!.port}');
      
      _server!.listen((HttpRequest request) async {
        print('🔥 Received ${request.method} request: ${request.uri.path}');
        
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
            print('🔥 Hot reload request received from watcher (Instance: $_instanceId)');
            
            // Trigger the manual hot reload
            triggerManualHotReload();
            
            // Send success response
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              'status': 'success',
              'message': 'Hot reload triggered successfully',
              'instanceId': _instanceId,
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
            'instanceId': _instanceId,
            'uptime': DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(int.parse(_instanceId ?? '0'))).inSeconds,
          }));
        }
        
        await request.response.close();
      });
      
    } catch (e) {
      print('❌ Failed to start hot reload listener: $e');
      print('❌ Error details: ${e.toString()}');
      print('❌ Stack trace: ${StackTrace.current}');
      _isRunning = false;
      _instanceId = null;
    }
  }
  
  /// Stop the hot reload listener
  static Future<void> stop() async {
    if (_server != null && _isRunning) {
      print('🔥 Stopping hot reload listener (Instance: $_instanceId)');
      await _server!.close(force: true);
      _server = null;
      _isRunning = false;
      _instanceId = null;
      print('🔥 Hot reload listener stopped');
    }
  }
  
  /// Check if the listener is currently running
  static bool get isRunning => _isRunning;
  
  /// Get current instance ID
  static String? get instanceId => _instanceId;
}

