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
  bool _isAndroidDevice = false;
  String? _selectedDeviceId;

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
    await _printShutdownMessage(exitCode);
  }

  /// Print stylish welcome header
  Future<void> _printWelcomeHeader() async {
    final width = 80;
    final title = '� DCFlight Hot Reload System';
    final subtitle = 'Powered by DCFlight Framework with Flutter Tooling';

    print(
        '\n$_brightCyan$_bold$_boxTopLeft${_boxHeavyHorizontal * (width - 2)}$_boxTopRight$_reset');
    print(
        '$_brightCyan$_bold$_boxVertical${' ' * ((width - title.length) ~/ 2 - 1)}$_white$title$_reset${' ' * ((width - title.length) ~/ 2 - 1)}$_brightCyan$_bold$_boxVertical$_reset');
    print(
        '$_brightCyan$_bold$_boxVertical${' ' * ((width - subtitle.length) ~/ 2 - 1)}$_dim$subtitle$_reset${' ' * ((width - subtitle.length) ~/ 2 - 1)}$_brightCyan$_bold$_boxVertical$_reset');
    print(
        '$_brightCyan$_bold$_boxBottomLeft${_boxHeavyHorizontal * (width - 2)}$_boxBottomRight$_reset');
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
    _logWatcher(
        '⌨️ ',
        'User input handler active - press keys for Flutter commands',
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
    const int maxRetries = 3;
    const Duration retryDelay = Duration(milliseconds: 500);
    
    // First check if server is healthy
    final isHealthy = await _checkServerHealth();
    if (!isHealthy) {
      _logWatcher('⚠️', 'Skipping DCFlight hot reload - server not healthy', _yellow);
      return;
    }
    
    final possibleIPs = ['localhost', '127.0.0.1', '10.0.2.2'];
    
    for (final ip in possibleIPs) {
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          print('🔥 WATCHER: Trying hot reload at http://$ip:8765/hot-reload (attempt $attempt, timestamp: $timestamp)');
          final client = HttpClient();
          final request = await client.postUrl(Uri.parse('http://$ip:8765/hot-reload?t=$timestamp'));
          request.headers.set('Content-Type', 'application/json');
          request.headers.set('X-Timestamp', timestamp.toString());

          // Send the request
          final response = await request.close();

          if (response.statusCode == 200) {
            // Read response body to see instance ID
            final responseBody = await response.transform(utf8.decoder).join();
            try {
              final responseData = jsonDecode(responseBody);
              final instanceId = responseData['instanceId'];
              final responseTimestamp = responseData['timestamp'];
              print('✅ WATCHER: Hot reload successful at $ip - Instance: $instanceId, ResponseTime: $responseTimestamp, RequestTime: $timestamp');
            } catch (e) {
              print('✅ WATCHER: Hot reload successful at $ip (could not parse response: $e)');
            }
            _logWatcher('✅', 'DCFlight VDOM hot reload triggered at $ip (attempt $attempt)', _green);
            client.close();
            return;
          } else {
            print('⚠️ WATCHER: Server at $ip returned status ${response.statusCode}');
          }

          client.close();
          
          // If not the last attempt, wait before retrying
          if (attempt < maxRetries) {
            await Future.delayed(retryDelay);
          }
        } catch (e) {
          print('⚠️ WATCHER: Hot reload attempt $attempt at $ip failed: $e');
          
          // If not the last attempt, wait before retrying
          if (attempt < maxRetries) {
            await Future.delayed(retryDelay);
          }
        }
      }
    }
    
    // All attempts failed
    _logWatcher('❌', 'DCFlight hot reload failed on all IPs after $maxRetries attempts each', _red);
  }

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

    // Store device info
    _isAndroidDevice = targetPlatform?.toLowerCase().contains('android') ?? false;
    _selectedDeviceId = deviceId; // Store for ADB port forwarding

    print('✅ Selected: $deviceName');
    if (verbose && _isAndroidDevice) {
      print('🤖 Android device detected - will use ADB port forwarding');
    }
    print('=' * 60 + '\n');

    return deviceId;
  }

  /// Log DCFlight App output (left side)
  void _logFlutter(String icon, String message, [String color = '']) {
    final timestamp = _getTimestamp();
    final splitPosition = _getSplitPosition();
    final maxMessageLength =
        splitPosition - icon.length - timestamp.length - 8; // Extra padding

    // Truncate message if too long
    String displayMessage = message;
    if (message.length > maxMessageLength && maxMessageLength > 10) {
      displayMessage = '${message.substring(0, maxMessageLength - 3)}...';
    }

    print('$color  $icon $timestamp $displayMessage$_reset');
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

  /// Setup ADB port forwarding for Android devices
  Future<void> _setupAdbForwarding() async {
    if (!_isAndroidDevice || _selectedDeviceId == null) return;

    print('🔧 Setting up ADB port forwarding for Android device: $_selectedDeviceId...');
    
    try {
      // Remove any existing forwarding first (for this specific device)
      await Process.run('adb', ['-s', _selectedDeviceId!, 'forward', '--remove', 'tcp:8765']);
      
      // Wait a moment for the port to be released
      await Future.delayed(Duration(milliseconds: 100));
      
      // Setup new forwarding: host:8765 -> emulator:8765
      // adb forward maps HOST port to EMULATOR port
      // Use -s flag to target specific device when multiple devices are connected
      final result = await Process.run('adb', ['-s', _selectedDeviceId!, 'forward', 'tcp:8765', 'tcp:8765']);
      
      if (result.exitCode == 0) {
        print('✅ ADB port forwarding active: host:8765 → device:8765 (device: $_selectedDeviceId)');
        
        // Verify the forwarding
        final verifyResult = await Process.run('adb', ['-s', _selectedDeviceId!, 'forward', '--list']);
        if (verifyResult.exitCode == 0) {
          print('📋 Active port forwards: ${verifyResult.stdout.toString().trim()}');
        }
      } else {
        final error = result.stderr.toString();
        print('⚠️  ADB port forwarding failed: $error');
      }
    } catch (e) {
      print('⚠️  Could not setup ADB forwarding: $e');
    }
  }

  /// Check if DCFlight hot reload server is healthy
  Future<bool> _checkServerHealth() async {
    // Setup ADB forwarding for Android devices
    await _setupAdbForwarding();
    
    final possibleIPs = ['localhost', '127.0.0.1'];
    
    for (final ip in possibleIPs) {
      try {
        print('🔍 WATCHER: Trying to connect to http://$ip:8765/health');
        final client = HttpClient();
        client.connectionTimeout = Duration(seconds: 3);
        
        final request = await client.getUrl(Uri.parse('http://$ip:8765/health'));
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        
        client.close();
        
        if (response.statusCode == 200) {
          final healthData = jsonDecode(responseBody);
          final instanceId = healthData['instanceId'];
          print('💚 WATCHER: Server healthy at $ip - Instance: $instanceId');
          _logWatcher('💚', 'DCFlight server healthy at $ip (Instance: $instanceId)', _green);
          return true;
        }
      } catch (e) {
        print('� WATCHER: Failed to connect to $ip: $e');
        continue;
      }
    }
    
    _logWatcher('💔', 'DCFlight server not reachable on any IP', _yellow);
    return false;
  }
}

