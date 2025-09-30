/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

class PackageManager {
  /// Inject a package into the project
  static Future<void> injectPackage({
    required String packageName,
    bool isDev = false,
    String? version,
    bool verbose = false,
  }) async {
    try {
      // 1. Validate project structure
      await _validateProjectStructure();

      // 2. Check if package is already added
      await _checkPackageExists(packageName, isDev);

      // 3. Add package using flutter pub add
      await _addPackage(packageName, isDev, version, verbose);

      // 4. Run pub get
      await _runPubGet(verbose);

      // 5. Log analytics (future-proofing)
      await _logPackageAnalytics('inject', packageName, isDev, version, verbose: verbose);

      if (verbose) {
        print('📊 Package analytics logged for future framework improvements');
      }
    } catch (e) {
      throw Exception('Failed to inject package: $e');
    }
  }

  /// Eject a package from the project
  static Future<void> ejectPackage({
    required String packageName,
    bool isDev = false,
    bool verbose = false,
    bool force = false,
  }) async {
    try {
      // 1. Validate project structure
      await _validateProjectStructure();

      // 2. Check if package exists
      await _checkPackageExistsForRemoval(packageName, isDev);

      // 3. Confirm removal (unless forced)
      if (!force) {
        await _confirmRemoval(packageName);
      }

      // 4. Remove package using flutter pub remove
      await _removePackage(packageName, isDev, verbose);

      // 5. Run pub get
      await _runPubGet(verbose);

      // 6. Log analytics (future-proofing)
      await _logPackageAnalytics('eject', packageName, isDev, null, verbose: verbose);

      if (verbose) {
        print('📊 Package analytics logged for future framework improvements');
      }
    } catch (e) {
      throw Exception('Failed to eject package: $e');
    }
  }

  /// Validate that we're in a DCFlight project
  static Future<void> _validateProjectStructure() async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw Exception('No pubspec.yaml found. Make sure you\'re in a DCFlight project directory.');
    }

    final pubspecContent = await pubspecFile.readAsString();
    if (!pubspecContent.contains('dcflight:')) {
      throw Exception('This doesn\'t appear to be a DCFlight project. Missing dcflight dependency in pubspec.yaml.');
    }
  }

  /// Check if package already exists
  static Future<void> _checkPackageExists(String packageName, bool isDev) async {
    final pubspecFile = File('pubspec.yaml');
    final content = await pubspecFile.readAsString();
    
    final section = isDev ? 'dev_dependencies:' : 'dependencies:';
    final lines = content.split('\n');
    bool inSection = false;
    
    for (final line in lines) {
      if (line.trim().startsWith(section)) {
        inSection = true;
        continue;
      }
      if (inSection && line.trim().startsWith('${packageName}:')) {
        throw Exception('Package $packageName is already added as a ${isDev ? 'dev ' : ''}dependency');
      }
      if (inSection && line.trim().isNotEmpty && !line.startsWith(' ')) {
        break; // End of section
      }
    }
  }

  /// Check if package exists for removal
  static Future<void> _checkPackageExistsForRemoval(String packageName, bool isDev) async {
    final pubspecFile = File('pubspec.yaml');
    final content = await pubspecFile.readAsString();
    
    final section = isDev ? 'dev_dependencies:' : 'dependencies:';
    final lines = content.split('\n');
    bool inSection = false;
    bool found = false;
    
    for (final line in lines) {
      if (line.trim().startsWith(section)) {
        inSection = true;
        continue;
      }
      if (inSection && line.trim().startsWith('${packageName}:')) {
        found = true;
        break;
      }
      if (inSection && line.trim().isNotEmpty && !line.startsWith(' ')) {
        break; // End of section
      }
    }

    if (!found) {
      throw Exception('Package $packageName is not found in ${isDev ? 'dev ' : ''}dependencies');
    }
  }

  /// Add package using flutter pub add
  static Future<void> _addPackage(String packageName, bool isDev, String? version, bool verbose) async {
    final args = ['pub', 'add', packageName];
    
    if (isDev) {
      args.add('--dev');
    }
    
    if (version != null) {
      args.add('--version');
      args.add(version);
    }

    if (verbose) {
      print('🔧 Running: flutter ${args.join(' ')}');
    }

    final result = await Process.run('flutter', args);
    
    if (result.exitCode != 0) {
      throw Exception('Failed to add package: ${result.stderr}');
    }

    if (verbose) {
      print('✅ Package added successfully');
    }
  }

  /// Remove package using flutter pub remove
  static Future<void> _removePackage(String packageName, bool isDev, bool verbose) async {
    final args = ['pub', 'remove', packageName];
    
    if (isDev) {
      args.add('--dev');
    }

    if (verbose) {
      print('🔧 Running: flutter ${args.join(' ')}');
    }

    final result = await Process.run('flutter', args);
    
    if (result.exitCode != 0) {
      throw Exception('Failed to remove package: ${result.stderr}');
    }

    if (verbose) {
      print('✅ Package removed successfully');
    }
  }

  /// Run pub get
  static Future<void> _runPubGet(bool verbose) async {
    if (verbose) {
      print('📦 Running: flutter pub get');
    }

    final result = await Process.run('flutter', ['pub', 'get']);
    
    if (result.exitCode != 0) {
      throw Exception('Failed to run pub get: ${result.stderr}');
    }

    if (verbose) {
      print('✅ Dependencies updated');
    }
  }

  /// Confirm package removal
  static Future<void> _confirmRemoval(String packageName) async {
    print('⚠️  Are you sure you want to remove $packageName? (y/N)');
    
    final input = stdin.readLineSync()?.toLowerCase();
    if (input != 'y' && input != 'yes') {
      print('❌ Package removal cancelled');
      exit(0);
    }
  }

  /// Log package analytics for future framework improvements
  static Future<void> _logPackageAnalytics(String action, String packageName, bool isDev, String? version, {bool verbose = false}) async {
    try {
      // Create analytics directory if it doesn't exist
      final analyticsDir = Directory('.dcflight/analytics');
      if (!await analyticsDir.exists()) {
        await analyticsDir.create(recursive: true);
      }

      // Log package action
      final analyticsFile = File(path.join(analyticsDir.path, 'package_usage.json'));
      final analytics = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'action': action,
        'package': packageName,
        'isDev': isDev,
        'version': version,
        'framework': 'dcflight',
      };

      // Append to analytics file
      final existingData = await analyticsFile.exists() 
          ? jsonDecode(await analyticsFile.readAsString()) as List<dynamic>
          : <dynamic>[];
      
      existingData.add(analytics);
      await analyticsFile.writeAsString(jsonEncode(existingData));
    } catch (e) {
      // Don't fail the operation if analytics logging fails
      if (verbose) {
        print('⚠️  Failed to log analytics: $e');
      }
    }
  }
}
