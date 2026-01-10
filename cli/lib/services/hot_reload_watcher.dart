/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dcflight_cli/services/ide_service.dart';

/// Stylish hot reload watcher with split terminal interface
class HotReloadWatcher {
  late Process _flutterProcess;
  late StreamSubscription _watcherSubscription;
  final bool verbose;
  final List<String> additionalArgs;
  // Device tracking variables removed - no longer needed (no custom HTTP server)
  bool _normalShutdown = false; // Track if shutdown was normal (via 'q') or forced (Ctrl+C)

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

  /// Get terminal width, defaulting to 80 if unavailable
  int _getTerminalWidth() {
    try {
      final width = stdout.terminalColumns;
      if (verbose) {
        print('📏 Terminal width detected: $width columns');
      }
      return width;
    } catch (e) {
      if (verbose) {
        print('⚠️  Could not detect terminal width, using fallback: 80');
      }
      return 80; // Fallback width
    }
  }

  /// Get responsive split position (60% for app output, 40% for watcher)
  int _getSplitPosition() {
    final width = _getTerminalWidth();
    return (width * 0.6).floor();
  }

  /// Start the stylish hot reload watcher system
  Future<void> start() async {
    print('🚨 DEBUG: NEW DEVICE SELECTION CODE IS RUNNING!');

    // Setup signal handlers for graceful shutdown
    ProcessSignal.sigint.watch().listen((_) async {
      await _handleForcedShutdown();
    });
    ProcessSignal.sigterm.watch().listen((_) async {
      await _handleForcedShutdown();
    });

    // SELECT DEVICE FIRST - before any UI setup
    final deviceId = await _selectDevice();

    await _printWelcomeHeader();
    await _setupSplitTerminal();

    // Start Flutter process with the selected device
    await _startFlutterProcess(deviceId);

    // Start file watcher
    await _startFileWatcher();

    // Start user input handler
    _startUserInputHandler();

    // Wait for Flutter process to complete
    final exitCode = await _flutterProcess.exitCode;

    // Clean shutdown
    await _watcherSubscription.cancel();
    // Cleanup removed - no custom HTTP server
    
    // Only print shutdown message if it was a normal shutdown
    if (_normalShutdown) {
    await _printShutdownMessage(exitCode);
    }
  }

  /// Handle forced shutdown (Ctrl+C or kill signal)
  Future<void> _handleForcedShutdown() async {
    // Kill Flutter process immediately
    try {
      _flutterProcess.kill();
    } catch (e) {
      // Process might already be dead
    }
    
    // Cleanup
    try {
      await _watcherSubscription.cancel();
    } catch (e) {
      // Already cancelled
    }
    // Cleanup removed - no custom HTTP server
    
    // Exit immediately without printing shutdown message
    exit(0);
  }

  /// Print commands menu
  void _printCommandsMenu() {
    final width = _getTerminalWidth();
    final commands = [
      'r - Hot reload',
      'R - Hot restart',
      'c - Open IDE',
      'h - Help',
      'q - Quit',
    ];
    
    final menuWidth = commands.map((c) => c.length).reduce((a, b) => a > b ? a : b) + 4;
    final padding = ' ' * ((width - menuWidth) ~/ 2);
    
    print('\n$_brightCyan$_bold$padding╭${'─' * (menuWidth - 2)}╮$_reset');
    print('$_brightCyan$_bold$padding│${' ' * (menuWidth - 2)}│$_reset');
    print('$_brightCyan$_bold$padding│${' ' * ((menuWidth - 'Available Commands'.length) ~/ 2 - 1)}Available Commands${' ' * ((menuWidth - 'Available Commands'.length) ~/ 2 - 1)}│$_reset');
    print('$_brightCyan$_bold$padding│${' ' * (menuWidth - 2)}│$_reset');
    
    for (final cmd in commands) {
      final cmdPadding = ' ' * ((menuWidth - cmd.length) ~/ 2 - 1);
      print('$_brightCyan$_bold$padding│$cmdPadding$_white$cmd$_reset${' ' * (menuWidth - cmd.length - cmdPadding.length - 1)}$_brightCyan$_bold│$_reset');
    }
    
    print('$_brightCyan$_bold$padding│${' ' * (menuWidth - 2)}│$_reset');
    print('$_brightCyan$_bold$padding╰${'─' * (menuWidth - 2)}╯$_reset\n');
  }
  
  /// Print stylish welcome header
  Future<void> _printWelcomeHeader() async {
    final width = _getTerminalWidth();
    final title = '🚀 DCFlight Development Server';
    final subtitle = 'Powered by DCFlight Framework with Flutter Tooling';
    final version = 'v0.0.2';

    print('\n');
    print('$_brightCyan$_bold$_boxTopLeft${_boxHeavyHorizontal * (width - 2)}$_boxTopRight$_reset');
    print('$_brightCyan$_bold$_boxVertical${' ' * ((width - title.length) ~/ 2 - 1)}$_white$title$_reset${' ' * ((width - title.length) ~/ 2 - 1)}$_brightCyan$_bold$_boxVertical$_reset');
    print('$_brightCyan$_bold$_boxVertical${' ' * ((width - subtitle.length) ~/ 2 - 1)}$_dim$subtitle$_reset${' ' * ((width - subtitle.length) ~/ 2 - 1)}$_brightCyan$_bold$_boxVertical$_reset');
    print('$_brightCyan$_bold$_boxVertical${' ' * ((width - version.length) ~/ 2 - 1)}$_dim$version$_reset${' ' * ((width - version.length) ~/ 2 - 1)}$_brightCyan$_bold$_boxVertical$_reset');
    print('$_brightCyan$_bold$_boxBottomLeft${_boxHeavyHorizontal * (width - 2)}$_boxBottomRight$_reset');
    print('');
  }

  /// Setup split terminal layout
  Future<void> _setupSplitTerminal() async {
    final width = _getTerminalWidth();
    final splitPosition = _getSplitPosition();
    final separatorLine = _boxHeavyHorizontal * (width - 2);

    // Create responsive column headers
    final leftHeader = 'DCFApp (Flutter Tooling)';
    final rightHeader = 'Watcher';
    final leftPadding = (splitPosition - leftHeader.length) ~/ 2;
    final rightPadding = (width - splitPosition - rightHeader.length - 2) ~/ 2;

    print('$_brightBlue$_bold$separatorLine$_reset');
    print(
        '$_brightGreen$_bold${' ' * leftPadding}$leftHeader${' ' * (splitPosition - leftHeader.length - leftPadding)}$_brightCyan$_bold${' ' * rightPadding}$rightHeader$_reset');
    print('$_brightBlue$_bold$separatorLine$_reset');
  }

  /// Start Flutter process with custom output handling
  Future<void> _startFlutterProcess(String deviceId) async {
    try {
      final args = [
        'run',
        '-d',
        deviceId,
        '--hot',
        ...additionalArgs,
      ];

      _logWatcher('📦', 'Bundling application...', _brightCyan);
      await Future.delayed(Duration(milliseconds: 500)); // Show bundling state
      
      _logWatcher('🔨', 'Building native components...', _brightCyan);
      await Future.delayed(Duration(milliseconds: 500)); // Show building state
      
      _logWatcher('🚀', 'Starting DCFlight process...', _brightGreen);

      _flutterProcess = await Process.start(
        'flutter',
        args,
        mode: ProcessStartMode.normal,
      );
      
      // Ensure stdin is connected and ready
      _flutterProcess.stdin.done.then((_) {
        // stdin closed
      }).catchError((e) {
        // Ignore stdin errors
      });

      // Handle Flutter stdout (left side of split)
      _flutterProcess.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        // Debug: Log all lines in verbose mode to see what's being captured
        if (verbose && !line.contains('DCFLOG:')) {
          print('🔍 DEBUG: Captured line (not DCFLOG): ${line.substring(0, line.length > 100 ? 100 : line.length)}');
        }
        if (_shouldShowLog(line)) {
        _logFlutter('📱', line);
        }
      });

      // Handle Flutter stderr (left side of split)
      _flutterProcess.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (_shouldShowLog(line)) {
        _logFlutter('⚠️ ', line, _yellow);
        }
      });

      _logWatcher('✅', 'DCFlight process started successfully', _brightGreen);
      _logWatcher('💡', 'App is running! Press keys for commands (see menu above)', _dim);
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
    _printCommandsMenu();
    
    _logWatcher(
        '⌨️ ',
        'User input handler active - press keys for commands',
        _brightCyan);

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
            _flutterProcess.stdin.flush().catchError((e) {
              _logWatcher('❌', 'Failed to send hot restart command: $e', _red);
            });
            break;
          case 'q':
            _normalShutdown = true;
            _logWatcher('👋', 'Quit command sent by user', _red);
            _flutterProcess.stdin.writeln('q');
            _flutterProcess.stdin.flush();
            break;
          case 'h':
            _logWatcher('❓', 'Help command sent by user', _cyan);
            _flutterProcess.stdin.writeln('h');
            _flutterProcess.stdin.flush();
            break;
          case 'c':
            _handleOpenIDE();
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

  /// Trigger hot reload by sending 'r' to Flutter process
  /// Flutter's hot reload automatically triggers reassemble() in _DCFlightHotReloadDetector widget
  /// which notifies VDOM to update - no custom HTTP server needed
  Future<void> _triggerHotReload() async {
    try {
      _logWatcher('🔥', 'Triggering hot reload...', _magenta);

      // Send 'r' to Flutter process - Flutter handles hot reload automatically
      // The _DCFlightHotReloadDetector widget in the framework detects it via reassemble()
      // and notifies VDOM to update
      _flutterProcess.stdin.writeln('r');
      await _flutterProcess.stdin.flush();
      
      _logWatcher('✅', 'Hot reload triggered - Flutter will handle it automatically', _green);
    } catch (e) {
      _logWatcher('❌', 'Failed to trigger hot reload: $e', _red);
    }
  }

  // HTTP server code removed - Flutter's hot reload + reassemble() handles VDOM updates automatically

  /// Select device for Flutter
  Future<String> _selectDevice() async {
    print('\n${'=' * 60}');
    print('🔧 DEVICE SELECTION');
    print('=' * 60);

    final result = await Process.run('flutter', ['devices', '--machine']);
    if (result.exitCode != 0) {
      throw Exception('Failed to get Flutter devices');
    }

    final devices =
        (jsonDecode(result.stdout) as List).cast<Map<String, dynamic>>();

    if (verbose) {
      print('🔍 Debug: Found ${devices.length} devices');
      for (int i = 0; i < devices.length; i++) {
        final device = devices[i];
        print('   Device $i: ${device['name']} (${device['id']})');
      }
    }

    if (devices.isEmpty) {
      throw Exception('No Flutter devices available');
    }

    // Always show device selection menu
    print('\n📱 Available devices:');
    for (int i = 0; i < devices.length; i++) {
      final device = devices[i];
      final name = device['name'] ?? 'Unknown';
      final platform = device['targetPlatform'] ?? 'Unknown';
      final id = device['id'] ?? 'Unknown';
      final isEmulator = device['emulator'] == true;
      final status = !isEmulator ? '📱 Physical' : '🖥️  Simulator';

      print('  ${i + 1}. $name ($platform) - $status');
      if (verbose) {
        print('     ID: $id');
      }
    }

    // Get user selection with clear prompt
    print('\n${'-' * 60}');
    stdout.write('👆 SELECT DEVICE (1-${devices.length}): ');
    stdout.flush(); // Force output immediately

    final input = stdin.readLineSync();

    if (verbose) {
      print('🔍 Debug: User input received: "$input"');
    }

    if (input == null || input.trim().isEmpty) {
      print('❌ No selection made. Exiting...');
      exit(1);
    }

    final selection = int.tryParse(input.trim());
    if (selection == null || selection < 1 || selection > devices.length) {
      print('❌ Invalid selection "$input". Please choose 1-${devices.length}');
      exit(1);
    }

    final selectedDevice = devices[selection - 1];
    final deviceId = selectedDevice['id'] as String;
    final deviceName = selectedDevice['name'] as String;
    final targetPlatform = selectedDevice['targetPlatform'] as String?;

    print('✅ Selected: $deviceName');
    print('=' * 60 + '\n');

    return deviceId;
  }

  /// Check if a log line should be shown.
  /// 
  /// Only show:
  /// - DCFLogger logs (contain "DCFLOG:")
  /// - Syntax/compilation errors
  /// - Everything if verbose mode is enabled
  bool _shouldShowLog(String line) {
    // If verbose mode, show all logs
    if (verbose) {
      return true;
    }
    
    final trimmedLine = line.trim();
    
    // Show DCFLogger logs (they contain "DCFLOG:" - can be prefixed with I/flutter, etc.)
    if (trimmedLine.contains('DCFLOG:')) {
      return true;
    }
    
    // Show syntax/compilation errors
    if (RegExp(r'\bError:', caseSensitive: false).hasMatch(trimmedLine) ||
        RegExp(r'\bException:', caseSensitive: false).hasMatch(trimmedLine) ||
        RegExp(r'^\d+:\d+:\s+error:', caseSensitive: false).hasMatch(trimmedLine)) {
      return true;
    }
    
    // Block everything else (Android logs, Flutter framework logs, etc.)
    return false;
  }

  /// Log DCFlight App output (left side)
  /// For DCFLOG: lines, strip prefixes and print as-is (logger package already formatted them beautifully)
  /// For other lines (errors), show them fully without truncation
  void _logFlutter(String icon, String message, [String color = '']) {
    final trimmed = message.trim();
    
    // If it's a DCFLOG line, strip all prefixes and print as-is
    if (trimmed.contains('DCFLOG:')) {
      String displayMessage = trimmed;
      // Remove Android format: I/flutter (pid): prefix if present
      displayMessage = displayMessage.replaceFirst(RegExp(r'^[VDIWEF]/flutter\s*\(\d+\):\s*'), '');
      // Remove iOS format: @dart (pid) or @dart (pid-pid) prefix if present
      displayMessage = displayMessage.replaceFirst(RegExp(r'^@dart\s*\([^)]+\)\s*'), '');
      // Remove iOS format: flutter: prefix if present (fallback)
      displayMessage = displayMessage.replaceFirst(RegExp(r'^flutter:\s*'), '');
      // Remove DCFLOG: prefix
      displayMessage = displayMessage.replaceFirst(RegExp(r'^DCFLOG:\s*'), '');
      
      // Fix escaped ANSI codes on iOS
      // iOS Flutter sometimes escapes ANSI codes, showing them as literal text
      // We need to convert escaped sequences back to actual ANSI codes
      // Pattern: \^[ followed by [ and numbers/semicolons (ANSI escape sequence)
      displayMessage = displayMessage.replaceAllMapped(
        RegExp(r'\\\^\[(\[[\d;]*[a-zA-Z])'),
        (match) => '\x1B${match.group(1)}',
      );
      
      // Also handle cases where ESC is shown as \033 or \x1B literally
      displayMessage = displayMessage.replaceAll('\\033[', '\x1B[');
      displayMessage = displayMessage.replaceAll('\\x1B[', '\x1B[');
      
      // Use print() - stdout.writeln() causes "StreamSink is bound to a stream" error
      // print() works correctly and ANSI codes are preserved
      print(displayMessage);
      return;
    }
    
    // For syntax errors and other errors, show them fully (don't truncate)
    final timestamp = _getTimestamp();
    print('$color  $icon $timestamp $message$_reset');
  }

  /// Log watcher output (right side)
  void _logWatcher(String icon, String message, [String color = '']) {
    final timestamp = _getTimestamp();
    final splitPosition = _getSplitPosition();
    final width = _getTerminalWidth();

    // Calculate right column position and width
    final rightColumnStart = splitPosition;
    final rightColumnWidth = width - rightColumnStart;
    final maxMessageLength =
        rightColumnWidth - icon.length - timestamp.length - 8; // Extra padding

    // Truncate message if too long
    String displayMessage = message;
    if (message.length > maxMessageLength && maxMessageLength > 10) {
      displayMessage = '${message.substring(0, maxMessageLength - 3)}...';
    }

    final padding = ' ' * rightColumnStart;
    print('$padding$color$icon $timestamp $displayMessage$_reset');
  }

  /// Get formatted timestamp
  String _getTimestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  /// Print shutdown message
  Future<void> _printShutdownMessage(int exitCode) async {
    final width = _getTerminalWidth();
    final separatorLine = _boxHorizontal * (width - 2);

    print(
        '\n$_brightBlue$_bold$_boxBottomLeft$separatorLine$_boxBottomRight$_reset');

    if (exitCode == 0) {
      print('$_brightGreen✅ DCFlight session completed successfully$_reset');
    } else {
      print('$_red❌ DCFlight session ended with exit code: $exitCode$_reset');
    }

    print('$_dim💡 Thanks for using DCFlight Hot Reload System!$_reset\n');
  }

  // ADB port forwarding removed - no longer needed (no custom HTTP server)

  // iproxy forwarding removed - no longer needed (no custom HTTP server)

  // iproxy cleanup removed - no longer needed (no custom HTTP server)

  /// Handle opening IDE (when user presses 'c')
  /// Automatically installs IDE if not already installed
  Future<void> _handleOpenIDE() async {
    _logWatcher('🚀', 'Opening IDE...', _brightCyan);
    
    try {
      // Check if IDE is installed
      final isInstalled = await IDEService.isIDEInstalled();
      
      if (!isInstalled) {
        _logWatcher('📦', 'IDE not detected. Auto-installing...', _yellow);
        _logWatcher('💡', 'This will download dcf-vscode and code-server', _dim);
        _logWatcher('⏳', 'Please wait, this may take a few minutes...', _dim);
        
        // Automatically install IDE with progress updates
        await IDEService.installIDE(onProgress: (message) {
          _logWatcher('📦', message, _cyan);
        });
        
        _logWatcher('✅', 'IDE installation complete!', _green);
      }
      
      // Get current project path
      final projectPath = Directory.current.path;
      
      // Launch IDE
      _logWatcher('🌐', 'Launching IDE in browser...', _brightGreen);
      await IDEService.launchIDE(projectPath);
      
      _logWatcher('✅', 'IDE opened successfully!', _green);
      _logWatcher('💡', 'Your IDE is ready. Happy coding!', _dim);
    } catch (e) {
      _logWatcher('❌', 'Failed to open IDE', _red);
      _logWatcher('🔍', 'Error details: $e', _yellow);
      _logWatcher('💡', 'Try pressing \'c\' again, or run: dcf ide --install', _dim);
    }
  }
  
  // Server health check removed - no longer needed (no custom HTTP server)
}
