/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight_cli/commands/command_runner.dart';

void main(List<String> arguments) async {
  final runner = DCFlightCommandRunner();
  await runner.run(arguments);
}
