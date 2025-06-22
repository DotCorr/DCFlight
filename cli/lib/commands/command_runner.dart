/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:args/command_runner.dart';
import 'package:dcflight_cli/commands/create_command.dart';
import 'package:dcflight_cli/commands/add_command.dart';
import 'package:dcflight_cli/commands/run_command.dart';

class DCFlightCommandRunner extends CommandRunner<void> {
  DCFlightCommandRunner()
      : super(
          'dcf',
          'DCFlight CLI - Development tools for DCFlight framework',
        ) {
    addCommand(CreateCommand());
    addCommand(AddCommand());
    addCommand(RunCommand());
  }

  @override
  void printUsage() {
    print('DCFlight CLI - Development tools for DCFlight framework\n');
    print('Usage: dcf <command> [options]\n');
    print('Available commands:');
    print('  create    Create new DCFlight projects or modules');
    print('  add       Add packages to your DCFlight project');
    print('  run       Run DCFlight app');
    print('\nRun "dcf help <command>" for more information about a command.');
  }
}
