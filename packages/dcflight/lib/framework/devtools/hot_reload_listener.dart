/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:io';
import 'dart:convert';
import 'dart:async';
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
    
    if (_isRunning && _server != null) {
      print('🔥 Hot reload listener already running, stopping previous instance...');
      await stop();
    }
    
    try {
      print('🔥 Attempting to bind server to port $_port...');
      
      // On iOS, try 0.0.0.0 first (required for iproxy), then fallback to localhost
      // On other platforms, try 0.0.0.0 first for maximum compatibility
      final isIOS = Platform.isIOS;
      
      if (isIOS) {
        print('🔥 iOS detected - binding to 0.0.0.0 (required for iproxy forwarding)...');
        try {
          _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
          print('🔥 Successfully bound to 0.0.0.0 on iOS');
        } catch (e) {
          print('❌ Failed to bind to 0.0.0.0 on iOS: $e, falling back to localhost...');
          _server = await HttpServer.bind('localhost', _port);
          print('🔥 Successfully bound to localhost on iOS (fallback)');
        }
      } else {
        print('🔥 Trying to bind to 0.0.0.0...');
        try {
          _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
          print('🔥 Successfully bound to 0.0.0.0');
        } catch (e) {
          print('🔥 Failed to bind to 0.0.0.0, trying localhost...');
          _server = await HttpServer.bind('localhost', _port);
          print('🔥 Successfully bound to localhost');
        }
      }
      _isRunning = true;
      _instanceId = DateTime.now().millisecondsSinceEpoch.toString();
      
      print('🔥 Hot reload listener started on port $_port (Instance: $_instanceId)');
      print('🔥 Server address: ${_server!.address}:${_server!.port}');
      
      _server!.listen((HttpRequest request) async {
        try {
          print('🔥 LISTENER: Received ${request.method} request: ${request.uri.path}');
          
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
          request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');
          
          if (request.method == 'OPTIONS') {
            request.response.statusCode = 200;
            await request.response.close();
            return;
          }
          
          if (request.method == 'GET' && request.uri.path == '/health') {
            // Explicit health check endpoint
            print('🔥 LISTENER: Health check request');
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              'status': 'healthy',
              'service': 'DCFlight Hot Reload Listener',
              'port': _port,
              'instanceId': _instanceId,
              'uptime': DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(int.parse(_instanceId ?? '0'))).inSeconds,
              'platform': Platform.operatingSystem,
            }));
            await request.response.close();
          } else if (request.method == 'POST' && request.uri.path == '/hot-reload') {
            print('🔥 LISTENER: Hot reload POST request received (Instance: $_instanceId)');
            
            try {
              // Trigger hot reload - don't await to avoid blocking response
              print('🔥 LISTENER: Calling triggerManualHotReload()...');
              triggerManualHotReload();
              print('🔥 LISTENER: triggerManualHotReload() called (non-blocking)');
              
              request.response.statusCode = 200;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({
                'status': 'success',
                'message': 'Hot reload triggered successfully',
                'instanceId': _instanceId,
                'timestamp': DateTime.now().toIso8601String(),
              }));
              await request.response.close();
              print('🔥 LISTENER: Response sent successfully');
              
            } catch (e, stackTrace) {
              print('❌ LISTENER: Hot reload error: $e');
              print('❌ LISTENER: Stack trace: $stackTrace');
              request.response.statusCode = 500;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({
                'status': 'error',
                'message': e.toString(),
              }));
              await request.response.close();
            }
          } else {
            print('🔥 LISTENER: Unknown request - returning status');
            request.response.statusCode = 200;
            request.response.write(jsonEncode({
              'status': 'listening',
              'service': 'DCFlight Hot Reload Listener',
              'port': _port,
              'instanceId': _instanceId,
              'uptime': DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(int.parse(_instanceId ?? '0'))).inSeconds,
            }));
            await request.response.close();
          }
        } catch (e, stackTrace) {
          print('❌ LISTENER: Error handling request: $e');
          print('❌ LISTENER: Stack trace: $stackTrace');
          try {
            request.response.statusCode = 500;
            await request.response.close();
          } catch (_) {
            // Ignore errors closing response
          }
        }
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

