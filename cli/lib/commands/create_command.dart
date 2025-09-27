/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:dcflight_cli/services/project_creator.dart';
import 'package:dcflight_cli/services/module_creator.dart';

class CreateCommand extends Command<void> {
  @override
  String get name => 'create';

  @override
  String get description => 'Create new DCFlight projects or modules';

  CreateCommand() {
    // No need to add help flag - CommandRunner provides it automatically
  }

  @override
  Future<void> run() async {
    final subcommand = argResults!.rest.isNotEmpty ? argResults!.rest.first : null;

    switch (subcommand) {
      case 'app':
        await _createApp();
        break;
      case 'module':
        await _createModule();
        break;
      default:
        print('❌ Invalid subcommand. Use: dcf create app or dcf create module');
        printUsage();
        exit(1);
    }
  }

  Future<void> _createApp() async {
    print('🚀 Creating new DCFlight app...\n');
    
    final creator = ProjectCreator();
    await creator.createApp();
  }

  Future<void> _createModule() async {
    print('📦 Creating new DCFlight module...\n');
    
    await ModuleCreator.createModule();
  }

  @override
  void printUsage() {
    print('Create new DCFlight projects or modules\n');
    print('Usage:');
    print('  dcf create app      Create a new DCFlight app');
    print('  dcf create module   Create a new DCFlight module');
    print('\nExamples:');
    print('  dcf create app');
    print('  dcf create module');
  }
}
