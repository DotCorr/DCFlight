/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:args/command_runner.dart';
import 'package:dcflight_cli/commands/run_command.dart';
import 'package:dcflight_cli/commands/create_command.dart';
import 'package:dcflight_cli/commands/inject_command.dart';
import 'package:dcflight_cli/commands/eject_command.dart';

class DCFlightCommandRunner extends CommandRunner<void> {
  DCFlightCommandRunner()
      : super(
          'dcf',
          'DCFlight CLI - Development tools for DCFlight framework',
        ) {
    addCommand(RunCommand());
    addCommand(CreateCommand());
    addCommand(InjectCommand());
    addCommand(EjectCommand());
  }
}

