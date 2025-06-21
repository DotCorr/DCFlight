/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:io';
import 'package:dcflight_cli/models/platform.dart';

class UserInput {
  static Future<String> promptProjectName() async {
    while (true) {
      stdout.write('? Project folder name: ');
      final input = stdin.readLineSync()?.trim() ?? '';
      
      if (input.isEmpty) {
        continue;
      }
      
      if (!_isValidProjectName(input)) {
        continue;
      }
      
      return input;
    }
  }

  static Future<String> promptAppName() async {
    stdout.write('? App display name: ');
    final input = stdin.readLineSync()?.trim() ?? '';
    return input.isNotEmpty ? input : 'My DCF App';
  }

  static Future<String> promptPackageName() async {
    while (true) {
      stdout.write('? Bundle ID/Package name (e.g., com.company.app): ');
      final input = stdin.readLineSync()?.trim() ?? '';
      
      if (input.isEmpty) {
        continue;
      }
      
      if (!_isValidPackageName(input)) {
        print('❌ Invalid package name. Use reverse domain notation (e.g., com.company.app)');
        continue;
      }
      
      return input;
    }
  }

  static Future<List<Platform>> promptPlatforms() async {
    print('? Select target platforms (enter numbers separated by commas):');
    
    stdout.write('Selected platforms (default: 1,2,3): ');
    final input = stdin.readLineSync()?.trim() ?? '';
    
    if (input.isEmpty) {
      return [Platform.android, Platform.ios, Platform.web];
    }
    
    final selectedNumbers = input.split(',').map((s) => int.tryParse(s.trim())).where((n) => n != null).toList();
    final platforms = <Platform>[];
    
    for (final number in selectedNumbers) {
      switch (number) {
        case 1:
          platforms.add(Platform.android);
          break;
        case 2:
          platforms.add(Platform.ios);
          break;
        case 3:
          platforms.add(Platform.web);
          break;
        case 4:
          platforms.add(Platform.macos);
          break;
        case 5:
          platforms.add(Platform.windows);
          break;
        case 6:
          platforms.add(Platform.linux);
          break;
      }
    }
    
    return platforms.isNotEmpty ? platforms : [Platform.android, Platform.ios, Platform.web];
  }

  static Future<String> promptDescription() async {
    stdout.write('? App description (optional): ');
    final input = stdin.readLineSync()?.trim() ?? '';
    return input.isNotEmpty ? input : 'A new DCFlight application';
  }

  static Future<String> promptOrganization() async {
    stdout.write('? Organization name: ');
    final input = stdin.readLineSync()?.trim() ?? '';
    return input.isNotEmpty ? input : 'My Company';
  }

  // Module creation methods
  static Future<String> promptModuleName() async {
    while (true) {
      stdout.write('? Module name (snake_case): ');
      final input = stdin.readLineSync()?.trim() ?? '';
      
      if (input.isEmpty) {
        continue;
      }
      
      if (!_isValidModuleName(input)) {
        continue;
      }
      
      return input;
    }
  }

  static Future<String> promptModuleDescription() async {
    stdout.write('? Module description: ');
    final input = stdin.readLineSync()?.trim() ?? '';
    return input.isNotEmpty ? input : 'A new DCFlight module';
  }

  // Package management methods
  static Future<String> promptPackageToAdd() async {
    while (true) {
      stdout.write('? Package name: ');
      final input = stdin.readLineSync()?.trim() ?? '';
      
      if (input.isEmpty) {
        continue;
      }
      
      return input;
    }
  }

  static Future<bool> promptDevDependency() async {
    stdout.write('? Add as dev dependency? (y/N): ');
    final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    return input == 'y' || input == 'yes';
  }

  // Validation methods
  static bool _isValidProjectName(String name) {
    final regex = RegExp(r'^[a-z][a-z0-9_]*$');
    return regex.hasMatch(name);
  }

  static bool _isValidPackageName(String name) {
    final regex = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');
    return regex.hasMatch(name);
  }

  static bool _isValidModuleName(String name) {
    final regex = RegExp(r'^[a-z][a-z0-9_]*$');
    return regex.hasMatch(name) && !name.startsWith('_') && !name.endsWith('_');
  }
}
