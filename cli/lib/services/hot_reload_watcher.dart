/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
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
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  
  // Box drawing characters
  static const String _boxHorizontal = '─';
  static const String _boxVertical = '│';
  static const String _boxTopLeft = '┌';
  static const String _boxTopRight = '┐';
  static const String _boxBottomLeft = '└';
  static const String _boxBottomRight = '┘';
  static const String _boxCross = '┼';
  static const String _boxVerticalRight = '├';
  static const String _boxVerticalLeft = '┤';
  
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
    
    // Wait for Flutter process to complete
    final exitCode = await _flutterProcess.exitCode;
    
    // Clean shutdown
    await _watcherSubscription.cancel();
    await _printShutdownMessage(exitCode);
  }

  /// Print stylish welcome header
  Future<void> _printWelcomeHeader() async {
    final width = 80;
    final title = '🔥 DCFlight Hot Reload Watcher';
    final subtitle = 'Powered by DCFlight Framework';
    
    print('\n$_cyan$_bold$_boxTopLeft${_boxHorizontal * (width - 2)}$_boxTopRight$_reset');
    print('$_cyan$_bold$_boxVertical${' ' * ((width - title.length) ~/ 2 - 1)}$title${' ' * ((width - title.length) ~/ 2 - 1)}$_boxVertical$_reset');
    print('$_cyan$_bold$_boxVertical${' ' * ((width - subtitle.length) ~/ 2 - 1)}$_dim$subtitle$_reset${' ' * ((width - subtitle.length) ~/ 2 - 1)}$_cyan$_bold$_boxVertical$_reset');
    print('$_cyan$_bold$_boxBottomLeft${_boxHorizontal * (width - 2)}$_boxBottomRight$_reset');
    print('');
  }

  /// Setup split terminal layout
  Future<void> _setupSplitTerminal() async {
    final width = 80;
    final halfWidth = width ~/ 2;
    
    print('$_blue$_bold$_boxTopLeft${_boxHorizontal * (halfWidth - 1)}$_boxCross${_boxHorizontal * (halfWidth - 2)}$_boxTopRight$_reset');
    print('$_blue$_bold$_boxVertical${' ' * (halfWidth - 8)}Flutter$_boxVertical${' ' * (halfWidth - 9)}Watcher$_boxVertical$_reset');
    print('$_blue$_bold$_boxVerticalRight${_boxHorizontal * (halfWidth - 1)}$_boxCross${_boxHorizontal * (halfWidth - 2)}$_boxVerticalLeft$_reset');
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
      
      _logWatcher('🚀', 'Starting Flutter process...', _green);
      
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
      
      _logWatcher('✅', 'Flutter process started successfully', _green);
      
    } catch (e) {
      _logWatcher('❌', 'Failed to start Flutter: $e', _red);
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

  /// Trigger hot reload by sending 'r' to Flutter process
  Future<void> _triggerHotReload() async {
    try {
      _logWatcher('🔥', 'Triggering hot reload...', _magenta);
      _flutterProcess.stdin.writeln('r');
      await _flutterProcess.stdin.flush();
    } catch (e) {
      _logWatcher('❌', 'Failed to trigger hot reload: $e', _red);
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

  /// Log Flutter output (left side)
  void _logFlutter(String icon, String message, [String color = '']) {
    final timestamp = _getTimestamp();
    final prefix = '$_blue$_boxVertical$_reset';
    print('$prefix$color $icon $timestamp $message$_reset');
  }

  /// Log watcher output (right side)
  void _logWatcher(String icon, String message, [String color = '']) {
    final timestamp = _getTimestamp();
    final padding = ' ' * 42; // Align to right side of split
    print('$padding$_blue$_boxVertical$_reset$color $icon $timestamp $message$_reset');
  }

  /// Get formatted timestamp
  String _getTimestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  /// Print shutdown message
  Future<void> _printShutdownMessage(int exitCode) async {
    print('\n$_blue$_bold$_boxBottomLeft${_boxHorizontal * 78}$_boxBottomRight$_reset');
    
    if (exitCode == 0) {
      print('$_green✅ DCFlight session completed successfully$_reset');
    } else {
      print('$_red❌ DCFlight session ended with exit code: $exitCode$_reset');
    }
    
    print('$_dim💡 Thanks for using DCFlight Hot Reload Watcher!$_reset\n');
  }
}

