/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:args/command_runner.dart';
import 'package:dcflight_cli/commands/run_command.dart';
import 'package:dcflight_cli/commands/create_command.dart';
import 'package:dcflight_cli/commands/inject_command.dart';
import 'package:dcflight_cli/commands/eject_command.dart';
import 'package:dcflight_cli/commands/ide_command.dart';

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
    addCommand(IdeCommand());
  }
}

