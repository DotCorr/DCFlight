/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:io';
import 'package:args/command_runner.dart';

class RunCommandSimple extends Command {
  @override
  String get name => 'run';

  @override
  String get description => 'Run DCFlight app with live code hydration (simple)';

  RunCommandSimple() {
    argParser.addOption(
      'port',
      abbr: 'p',
      defaultsTo: '8080',
      help: 'Hydration server port',
    );
  }

  @override
  Future<void> run() async {
    final port = argResults!['port'] as String;
    print('🚀 DCFlight: Starting hydration server on port $port...');
    print('📁 Current directory: ${Directory.current.path}');
    print('✅ Simple run command works!');
  }
}
