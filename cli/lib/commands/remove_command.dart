/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:io';
import 'package:args/command_runner.dart';

class RemoveCommand extends Command {
  @override
  String get name => 'remove';

  @override
  List<String> get aliases => ['rm'];

  @override
  String get description => 'Remove packages from your DCFlight project';

  RemoveCommand() {
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      defaultsTo: false,
      help: 'Verbose output',
    );
  }

  @override
  Future<void> run() async {
    final packageNames = argResults!.rest;
    
    if (packageNames.isEmpty) {
      print('❌ Error: No packages specified to remove');
      print('Usage: dcf remove <package_name> [package_name2] ...');
      print('Example: dcf remove http shared_preferences');
      return;
    }

    // Check if we're in a DCFlight project
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      print('❌ Error: pubspec.yaml not found. Make sure you\'re in a DCFlight project root directory.');
      return;
    }

    // Check if this is a DCFlight project
    final pubspecContent = await pubspecFile.readAsString();
    if (!pubspecContent.contains('dcflight:')) {
      print('❌ Error: This doesn\'t appear to be a DCFlight project. No dcflight dependency found in pubspec.yaml.');
      return;
    }

    print('🗑️  Removing packages from DCFlight project...');
    
    final verbose = argResults!['verbose'] as bool;
    
    if (verbose) {
      print('📋 Packages to remove: ${packageNames.join(', ')}');
    }

    // Use dart pub remove to remove packages
    final result = await Process.run(
      'dart',
      ['pub', 'remove', ...packageNames],
      workingDirectory: Directory.current.path,
    );

    if (result.exitCode == 0) {
      print('✅ Successfully removed packages: ${packageNames.join(', ')}');
      if (verbose && result.stdout.toString().isNotEmpty) {
        print('📄 Output:');
        print(result.stdout);
      }
    } else {
      print('❌ Failed to remove packages');
      print('Error: ${result.stderr}');
      if (verbose && result.stdout.toString().isNotEmpty) {
        print('Output: ${result.stdout}');
      }
    }
  }
}

