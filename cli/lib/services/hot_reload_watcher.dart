/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source c  /// Print stylish welcome header
  Future<void> _printWelcomeHeader() async {
    print('');
    print('$_brightCyan$_bold🚀 DCFlight Hot Reload System$_reset');
    print('$_dim   Powered by DCFlight Framework with Flutter Tooling$_reset');
    print('');
  }sed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:io';
import 'dart:async';
import 'dart:convert';

/// Stylish hot reload watcher with split terminal interface
class HotReloadWatcher {
  late Process _flutterProcess;
  late StreamSubscription _watcherSubscription;
  final bool verbose;
  final List<String> additionalArgs;
  
  // Terminal styling
  static const String _reset = '\x1B[0m';
  static const String _bold = '\x1B[1m';
  static const String _dim = '\x1B[2m';
  static const String _cyan = '\x1B[36m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _red = '\x1B[31m';
  static const String _magenta = '\x1B[35m';
  static const String _white = '\x1B[37m';
  static const String _brightBlue = '\x1B[94m';
  static const String _brightGreen = '\x1B[92m';
  static const String _brightCyan = '\x1B[96m';
  
  // Box drawing characters for beautiful UI
  static const String _boxHorizontal = '─';
  static const String _boxVertical = '│';
  static const String _boxTopLeft = '╭';
  static const String _boxTopRight = '╮';
  static const String _boxBottomLeft = '╰';
  static const String _boxBottomRight = '╯';
  static const String _boxHeavyHorizontal = '━';
  
  HotReloadWatcher({
    this.additionalArgs = const [],
    this.verbose = false,
  });

  /// Start the stylish hot reload watcher system
  Future<void> start() async {
    await _printWelcomeHeader();
    await _setupSplitTerminal();
    
    // Start Flutter process with custom output handling
    await _startFlutterProcess();
    
    // Start file watcher
    await _startFileWatcher();
    
    // Start user input handler
    _startUserInputHandler();
    
    // Wait for Flutter process to complete
    final exitCode = await _flutterProcess.exitCode;
    
    // Clean shutdown
    await _watcherSubscription.cancel();
    await _printShutdownMessage(exitCode);
  }

  /// Print stylish welcome header
  Future<void> _printWelcomeHeader() async {
    final width = 80;
    final title = '� DCFlight Hot Reload System';
    final subtitle = 'Powered by DCFlight Framework with Flutter Tooling';
    
    print('\n$_brightCyan$_bold$_boxTopLeft${_boxHeavyHorizontal * (width - 2)}$_boxTopRight$_reset');
    print('$_brightCyan$_bold$_boxVertical${' ' * ((width - title.length) ~/ 2 - 1)}$_white$title$_reset${' ' * ((width - title.length) ~/ 2 - 1)}$_brightCyan$_bold$_boxVertical$_reset');
    print('$_brightCyan$_bold$_boxVertical${' ' * ((width - subtitle.length) ~/ 2 - 1)}$_dim$subtitle$_reset${' ' * ((width - subtitle.length) ~/ 2 - 1)}$_brightCyan$_bold$_boxVertical$_reset');
    print('$_brightCyan$_bold$_boxBottomLeft${_boxHeavyHorizontal * (width - 2)}$_boxBottomRight$_reset');
    print('');
  }

  /// Setup split terminal layout
  Future<void> _setupSplitTerminal() async {
    print('$_brightBlue$_bold━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$_reset');
    print('$_brightGreen$_bold  DCFApp (Flutter Tooling)$_reset                       $_brightCyan$_bold  Watcher$_reset');
    print('$_brightBlue$_bold━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$_reset');
  }

  /// Start Flutter process with custom output handling
  Future<void> _startFlutterProcess() async {
    try {
      // Get device ID
      final deviceId = await _selectDevice();
      
      final args = [
        'run',
        '-d', deviceId,
        '--hot',
        ...additionalArgs,
      ];
      
      _logWatcher('🚀', 'Starting DCFlight process...', _brightGreen);
      
      _flutterProcess = await Process.start(
        'flutter',
        args,
        mode: ProcessStartMode.normal,
      );
      
      // Handle Flutter stdout (left side of split)
      _flutterProcess.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logFlutter('📱', line);
      });
      
      // Handle Flutter stderr (left side of split)
      _flutterProcess.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logFlutter('⚠️ ', line, _yellow);
      });
      
      _logWatcher('✅', 'DCFlight process started successfully', _brightGreen);
      
    } catch (e) {
      _logWatcher('❌', 'Failed to start DCFlight: $e', _red);
      rethrow;
    }
  }

  /// Start file system watcher for Dart files
  Future<void> _startFileWatcher() async {
    _logWatcher('👀', 'Starting file watcher...', _cyan);
    
    try {
      final libDir = Directory('lib');
      if (!await libDir.exists()) {
        throw Exception('lib directory not found');
      }
      
      final watcher = libDir.watch(recursive: true);
      
      _watcherSubscription = watcher.listen((event) async {
        if (event.path.endsWith('.dart')) {
          final filename = event.path.split('/').last;
          
          switch (event.type) {
            case FileSystemEvent.modify:
              _logWatcher('📝', 'File changed: $filename', _yellow);
              await _triggerHotReload();
              break;
            case FileSystemEvent.create:
              _logWatcher('➕', 'File created: $filename', _green);
              await _triggerHotReload();
              break;
            case FileSystemEvent.delete:
              _logWatcher('🗑️ ', 'File deleted: $filename', _red);
              await _triggerHotReload();
              break;
          }
        }
      });
      
      _logWatcher('✅', 'File watcher active - watching lib/ directory', _green);
      
    } catch (e) {
      _logWatcher('❌', 'Failed to start file watcher: $e', _red);
      rethrow;
    }
  }

  /// Start user input handler for Flutter commands
  void _startUserInputHandler() {
    _logWatcher('⌨️ ', 'User input handler active - press keys for Flutter commands', _brightCyan);
    
    // Listen to stdin in raw mode for immediate key detection
    stdin.lineMode = false;
    stdin.echoMode = false;
    
    stdin.listen((List<int> data) {
      try {
        final input = String.fromCharCodes(data).trim();
        
        // Handle Flutter commands
        switch (input) {
          case 'r':
            _logWatcher('🔥', 'Manual hot reload triggered by user', _magenta);
            _flutterProcess.stdin.writeln('r');
            _flutterProcess.stdin.flush();
            break;
          case 'R':
            _logWatcher('🔄', 'Hot restart triggered by user', _yellow);
            _flutterProcess.stdin.writeln('R');
            _flutterProcess.stdin.flush();
            break;
          case 'q':
            _logWatcher('👋', 'Quit command sent by user', _red);
            _flutterProcess.stdin.writeln('q');
            _flutterProcess.stdin.flush();
            break;
          case 'h':
            _logWatcher('❓', 'Help command sent by user', _cyan);
            _flutterProcess.stdin.writeln('h');
            _flutterProcess.stdin.flush();
            break;
          case 'd':
            _logWatcher('🔌', 'Detach command sent by user', _yellow);
            _flutterProcess.stdin.writeln('d');
            _flutterProcess.stdin.flush();
            break;
          case 'c':
            _logWatcher('🧹', 'Clear screen command sent by user', _cyan);
            _flutterProcess.stdin.writeln('c');
            _flutterProcess.stdin.flush();
            break;
          default:
            // Pass through any other input
            if (input.isNotEmpty && input != '\n' && input != '\r') {
              _flutterProcess.stdin.writeln(input);
              _flutterProcess.stdin.flush();
            }
        }
      } catch (e) {
        // Ignore input errors
      }
    });
  }

  /// Trigger hot reload by sending 'r' to Flutter process and HTTP request to DCFlight app
  Future<void> _triggerHotReload() async {
    try {
      _logWatcher('🔥', 'Triggering hot reload...', _magenta);
      
      // Send 'r' to Flutter process (for Flutter's own hot reload)
      _flutterProcess.stdin.writeln('r');
      await _flutterProcess.stdin.flush();
      
      // Also send HTTP request to DCFlight app for VDOM hot reload
      await _triggerDCFlightHotReload();
      
    } catch (e) {
      _logWatcher('❌', 'Failed to trigger hot reload: $e', _red);
    }
  }

  /// Send HTTP request to DCFlight app to trigger VDOM hot reload
  Future<void> _triggerDCFlightHotReload() async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('http://localhost:8765/hot-reload'));
      request.headers.set('Content-Type', 'application/json');
      
      // Send the request
      final response = await request.close();
      
      if (response.statusCode == 200) {
        _logWatcher('✅', 'DCFlight VDOM hot reload triggered', _green);
      } else {
        _logWatcher('⚠️', 'DCFlight app may not be running (${response.statusCode})', _yellow);
      }
      
      client.close();
    } catch (e) {
      // This is expected if the app isn't running or doesn't have the listener
      // Don't log as error since Flutter hot reload still works
      _logWatcher('💡', 'DCFlight hot reload listener not available', _dim);
    }
  }

  /// Select device for Flutter
  Future<String> _selectDevice() async {
    final result = await Process.run('flutter', ['devices', '--machine']);
    if (result.exitCode != 0) {
      throw Exception('Failed to get Flutter devices');
    }
    
    final devices = (jsonDecode(result.stdout) as List)
        .cast<Map<String, dynamic>>();
    
    if (devices.isEmpty) {
      throw Exception('No Flutter devices available');
    }
    
    // Prefer iOS Simulator or first available device
    final preferredDevice = devices.firstWhere(
      (device) => device['name'].toString().toLowerCase().contains('simulator'),
      orElse: () => devices.first,
    );
    
    final deviceName = preferredDevice['name'];
    final deviceId = preferredDevice['id'];
    
    _logWatcher('📱', 'Selected device: $deviceName', _cyan);
    
    return deviceId;
  }

  /// Log DCFlight App output (left side)
  void _logFlutter(String icon, String message, [String color = '']) {
    final timestamp = _getTimestamp();
    print('$color  $icon $timestamp $message$_reset');
  }

  /// Log watcher output (right side)
  void _logWatcher(String icon, String message, [String color = '']) {
    final timestamp = _getTimestamp();
    final padding = ' ' * 50; // Align to right side
    print('$padding$color$icon $timestamp $message$_reset');
  }

  /// Get formatted timestamp
  String _getTimestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  /// Print shutdown message
  Future<void> _printShutdownMessage(int exitCode) async {
    print('\n$_brightBlue$_bold$_boxBottomLeft${_boxHorizontal * 78}$_boxBottomRight$_reset');
    
    if (exitCode == 0) {
      print('$_brightGreen✅ DCFlight session completed successfully$_reset');
    } else {
      print('$_red❌ DCFlight session ended with exit code: $exitCode$_reset');
    }
    
    print('$_dim💡 Thanks for using DCFlight Hot Reload System!$_reset\n');
  }
}

