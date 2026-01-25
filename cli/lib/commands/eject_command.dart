/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:dcflight_cli/services/package_manager.dart';

class EjectCommand extends Command<void> {
  @override
  String get name => 'eject';

  @override
  String get description => 'Eject a package from your DCFlight project';

  EjectCommand() {
    argParser
      ..addFlag(
        'dev',
        abbr: 'd',
        defaultsTo: false,
        help: 'Remove from dev dependencies',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        defaultsTo: false,
        help: 'Verbose output',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        defaultsTo: false,
        help: 'Force removal without confirmation',
      );
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      print('❌ Error: Package name is required');
      printUsage();
      exit(1);
    }

    final packageName = argResults!.rest.first;
    final isDev = argResults!['dev'] as bool;
    final verbose = argResults!['verbose'] as bool;
    final force = argResults!['force'] as bool;

    try {
      print('🗑️  Ejecting package: $packageName');
      if (isDev) {
        print('   Type: Dev dependency');
      }

      await PackageManager.ejectPackage(
        packageName: packageName,
        isDev: isDev,
        verbose: verbose,
        force: force,
      );

      print('✅ Package $packageName ejected successfully!');
      print('💡 Run "dcf go" to restart your app');
    } catch (e) {
      print('❌ Error ejecting package: $e');
      exit(1);
    }
  }

  @override
  void printUsage() {
    print('Eject a package from your DCFlight project\n');
    print('Usage:');
    print('  dcf eject <package_name> [options]');
    print('\nOptions:');
    print('  -d, --dev        Remove from dev dependencies');
    print('  -v, --verbose    Verbose output');
    print('  -f, --force      Force removal without confirmation');
    print('\nExamples:');
    print('  dcf eject http');
    print('  dcf eject lints --dev');
    print('  dcf eject dio --force');
  }
}
