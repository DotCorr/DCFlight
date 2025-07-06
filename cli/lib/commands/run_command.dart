/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:dcflight_cli/services/dcflight_runner.dart';

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
        help: 'Additional DCFlight run arguments',
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
    final dcfArgs = argResults!['dcf-args'] as List<String>;

    print('🚀 Starting DCFlight app...');

    // Validate project structure
    await _validateProjectStructure();

    // Start DCFlight app
    print('🎯 Launching DCFlight runtime...');
    final dcfRunner = DCFlightRunner(
      additionalArgs: dcfArgs,
      verbose: verbose,
    );

    final dcfProcess = await dcfRunner.start();

    print('✅ DCFlight app launched successfully!');
    print('💡 Make changes to your code and restart to see updates');

    // Wait for the process to complete
    await dcfProcess.exitCode;
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
