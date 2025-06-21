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
        printUsage();
        exit(1);
    }
  }

  Future<void> _createApp() async {
    
    final creator = ProjectCreator();
    await creator.createApp();
  }

  Future<void> _createModule() async {
    
    await ModuleCreator.createModule();
  }

  @override
  void printUsage() {
  }
}
