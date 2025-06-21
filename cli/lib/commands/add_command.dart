/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:io';
import 'package:args/command_runner.dart';

class AddCommand extends Command<void> {
  @override
  String get name => 'add';

  @override
  String get description => 'Add packages to your DCFlight project';

  AddCommand() {
    argParser.addFlag(
      'dev',
      help: 'Add as dev dependency',
      negatable: false,
    );
  }

  @override
  Future<void> run() async {
    final packages = argResults!.rest;
    if (packages.isEmpty) {
      printUsage();
      exit(1);
    }

    final isDev = argResults!['dev'] == true;
    
    print('📦 Adding packages: ${packages.join(', ')}${isDev ? ' (dev dependencies)' : ''}');
    
    await _addPackages(packages, isDev);
  }

  Future<void> _addPackages(List<String> packages, bool isDev) async {
    try {
      // Build flutter pub add command
      final args = ['pub', 'add'];
      
      if (isDev) {
        args.add('--dev');
      }
      
      args.addAll(packages);
      
      print('🔄 Running: flutter ${args.join(' ')}');
      
      final result = await Process.run('flutter', args);
      
      if (result.exitCode == 0) {
        if (result.stdout.toString().isNotEmpty) {
        }
      } else {
        if (result.stderr.toString().isNotEmpty) {
        }
        exit(result.exitCode);
      }
    } catch (e) {
      exit(1);
    }
  }

  @override
  void printUsage() {
  }
}
