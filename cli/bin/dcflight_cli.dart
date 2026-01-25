/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */


import 'package:dcflight_cli/commands/command_runner.dart';

void main(List<String> arguments) async {
  final runner = DCFlightCommandRunner();
  await runner.run(arguments);
}
