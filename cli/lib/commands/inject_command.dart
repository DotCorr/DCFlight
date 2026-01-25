/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:dcflight_cli/services/package_manager.dart';

class InjectCommand extends Command<void> {
  @override
  String get name => 'inject';

  @override
  String get description => 'Inject a package into your DCFlight project';

  InjectCommand() {
    argParser
      ..addFlag(
        'dev',
        abbr: 'd',
        defaultsTo: false,
        help: 'Add as dev dependency',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        defaultsTo: false,
        help: 'Verbose output',
      )
      ..addOption(
        'version',
        help: 'Specify package version (e.g., ^1.0.0)',
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
    final version = argResults!['version'] as String?;
    final verbose = argResults!['verbose'] as bool;

    try {
      print('📦 Injecting package: $packageName');
      if (version != null) {
        print('   Version: $version');
      }
      if (isDev) {
        print('   Type: Dev dependency');
      }

      await PackageManager.injectPackage(
        packageName: packageName,
        isDev: isDev,
        version: version,
        verbose: verbose,
      );

      print('✅ Package $packageName injected successfully!');
      print('💡 Run "dcf go" to start your app with the new package');
    } catch (e) {
      print('❌ Error injecting package: $e');
      exit(1);
    }
  }

  @override
  void printUsage() {
    print('Inject a package into your DCFlight project\n');
    print('Usage:');
    print('  dcf inject <package_name> [options]');
    print('\nOptions:');
    print('  -d, --dev        Add as dev dependency');
    print('  -v, --verbose    Verbose output');
    print('  --version        Specify package version');
    print('\nExamples:');
    print('  dcf inject http');
    print('  dcf inject dio --version ^5.0.0');
    print('  dcf inject lints --dev');
  }
}
