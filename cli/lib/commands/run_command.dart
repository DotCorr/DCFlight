/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:dcflight_cli/services/engine_resolver.dart';

class RunCommand extends Command {
  @override
  String get name => 'go';

  @override
  String get description => 'Run DCFlight app';

  RunCommand() {
    argParser
      ..addFlag(
        'verbose',
        abbr: 'v',
        defaultsTo: false,
        help: 'Verbose output',
      )
      ..addMultiOption(
        'dcf-args',
        help: 'Additional Flutter run arguments',
      );
  }

  @override
  Future<void> run() async {
    try {
      await _runDCFlightApp();
    } catch (e) {
      print('❌ Error running DCFlight app: $e');
      exit(1);
    }
  }

  Future<void> _runDCFlightApp() async {
    final verbose = argResults!['verbose'];
    final dcfArgs = argResults!['dcf-args'] as List<String>? ?? [];

    print('🚀 Starting DCFlight app...');

    // Validate project structure
    await _validateProjectStructure();

    // Use Flutter's built-in hot reload - no custom watcher needed
    print('🎯 Launching Flutter app with hot reload support...');
    
    EngineResolver.requireInstalled();

    final args = ['run', ...dcfArgs];
    if (verbose) {
      args.add('--verbose');
    }

    final process = await Process.start(
      EngineResolver.flutterBinary,
      args,
      mode: ProcessStartMode.inheritStdio,
      environment: {
        ...Platform.environment,
        'FLUTTER_STORAGE_BASE_URL': EngineResolver.storageBaseUrl,
      },
    );
    
    print('✅ DCFlight app launched!');
    print('💡 Press "r" in the terminal for hot reload, "R" for hot restart');

    // Wait for the process to complete
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      exit(exitCode);
    }
  }

  Future<void> _validateProjectStructure() async {
    // Check if we're in a DCFlight project
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw Exception(
          'No pubspec.yaml found. Make sure you\'re in a DCFlight project directory.');
    }

    final pubspecContent = await pubspecFile.readAsString();
    if (!pubspecContent.contains('dcflight:')) {
      throw Exception(
          'This doesn\'t appear to be a DCFlight project. Missing dcflight dependency in pubspec.yaml.');
    }

    // Check if main.dart exists
    final mainFile = File('lib/main.dart');
    if (!await mainFile.exists()) {
      throw Exception(
          'No lib/main.dart found. Make sure you have a main.dart file.');
    }

    print('✅ DCFlight project structure validated');
  }
}

