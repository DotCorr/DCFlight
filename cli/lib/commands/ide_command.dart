/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:dcflight_cli/services/ide_service.dart';

class IdeCommand extends Command {
  @override
  String get name => 'ide';

  @override
  String get description => 'Manage DCFlight IDE (dcf-vscode + code-server)';

  IdeCommand() {
    argParser
      ..addFlag(
        'update',
        abbr: 'u',
        defaultsTo: false,
        help: 'Update IDE components',
      )
      ..addFlag(
        'install',
        abbr: 'i',
        defaultsTo: false,
        help: 'Install IDE components',
      );
  }

  @override
  Future<void> run() async {
    final update = argResults!['update'] as bool;
    final install = argResults!['install'] as bool;

    if (update) {
      await _updateIDE();
    } else if (install) {
      await _installIDE();
    } else {
      print('💡 Use --install to install IDE or --update to update');
      print('   dcf ide --install');
      print('   dcf ide --update');
    }
  }

  Future<void> _installIDE() async {
    print('🚀 Installing DCFlight IDE...\n');
    
    try {
      await IDEService.installIDE(onProgress: (message) {
        print('   $message');
      });
      
      print('\n✅ IDE installation complete!');
      print('💡 Press \'c\' in the dev server to launch the IDE');
    } catch (e) {
      print('\n❌ Failed to install IDE: $e');
      exit(1);
    }
  }

  Future<void> _updateIDE() async {
    print('🔄 Updating DCFlight IDE...\n');
    
    try {
      await IDEService.updateIDE(onProgress: (message) {
        print('   $message');
      });
      
      print('\n✅ IDE update complete!');
      print('💡 Your settings have been preserved');
    } catch (e) {
      print('\n❌ Failed to update IDE: $e');
      exit(1);
    }
  }
}

