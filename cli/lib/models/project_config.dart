/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'package:dcflight_cli/models/platform.dart';

class ProjectConfig {
  final String projectName;
  final String appName;
  final String packageName;
  final List<Platform> platforms;
  final String description;
  final String organization;

  ProjectConfig({
    required this.projectName,
    required this.appName,
    required this.packageName,
    required this.platforms,
    required this.description,
    required this.organization,
  });

  /// Validate the project configuration
  void validate() {
    if (projectName.isEmpty) {
      throw ArgumentError('Project name cannot be empty');
    }
    
    if (appName.isEmpty) {
      throw ArgumentError('App name cannot be empty');
    }
    
    if (packageName.isEmpty) {
      throw ArgumentError('Package name cannot be empty');
    }
    
    if (!_isValidPackageName(packageName)) {
      throw ArgumentError('Invalid package name format. Use format: com.example.app');
    }
    
    if (platforms.isEmpty) {
      throw ArgumentError('At least one platform must be selected');
    }
  }

  /// Check if package name follows valid format
  bool _isValidPackageName(String packageName) {
    final regex = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$');
    return regex.hasMatch(packageName);
  }

  /// Get the project directory name (kebab-case)
  String get projectDirectoryName {
    return projectName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  /// Get the app class name (PascalCase)
  String get appClassName {
    return appName.split(' ').map((word) => 
        word.substring(0, 1).toUpperCase() + word.substring(1).toLowerCase()
    ).join('');
  }

  @override
  String toString() {
    return 'ProjectConfig(name: $projectName, package: $packageName, platforms: ${platforms.map((p) => p.name).join(', ')})';
  }
}
