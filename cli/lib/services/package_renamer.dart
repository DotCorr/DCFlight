/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dcflight_cli/models/project_config.dart';

class PackageRenamer {
  /// Rename and configure the project based on user input
  static Future<void> renameProject(ProjectConfig config) async {
    final projectPath = path.join(Directory.current.path, config.projectDirectoryName);
    
    // Change to project directory
    final originalDir = Directory.current;
    Directory.current = projectPath;
    
    try {
      // 1. Replace template placeholders in files
      await _replaceTemplatePlaceholders(config, projectPath);
      
      // 2. Use package_rename to configure the project
      await _configurePackage(config);
      
      // 3. Update pubspec.yaml with correct name and description
      await _updatePubspec(config, projectPath);
      
    } finally {
      // Restore original directory
      Directory.current = originalDir;
    }
  }

  /// Replace template placeholders in all files
  static Future<void> _replaceTemplatePlaceholders(ProjectConfig config, String projectPath) async {
    final replacements = {
      '{{PROJECT_NAME}}': config.projectDirectoryName,
      '{{APP_NAME}}': config.appName,
      '{{APP_CLASS}}': config.appClassName,
      '{{PACKAGE_NAME}}': config.packageName,
      '{{DESCRIPTION}}': config.description,
      '{{ORGANIZATION}}': config.organization,
      // Also replace the template app name directly
      'dcf_go': config.projectDirectoryName,
      'package:dcf_go': 'package:${config.projectDirectoryName}',
    };

    // Find all text files and replace placeholders
    await _processDirectory(Directory(projectPath), replacements);
  }

  /// Process directory recursively to replace placeholders
  static Future<void> _processDirectory(Directory dir, Map<String, String> replacements) async {
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        // Skip build and hidden directories
        final dirName = path.basename(entity.path);
        if (!dirName.startsWith('.') && dirName != 'build') {
          await _processDirectory(entity, replacements);
        }
      } else if (entity is File) {
        await _processFile(entity, replacements);
      }
    }
  }

  /// Process individual file to replace placeholders
  static Future<void> _processFile(File file, Map<String, String> replacements) async {
    final fileName = path.basename(file.path);
    final extension = path.extension(fileName);
    
    // Only process text files
    final textExtensions = {'.dart', '.yaml', '.yml', '.md', '.txt', '.json', '.xml', '.gradle', '.swift', '.kt'};
    if (!textExtensions.contains(extension)) {
      return;
    }

    try {
      String content = await file.readAsString();
      bool modified = false;

      for (final entry in replacements.entries) {
        if (content.contains(entry.key)) {
          content = content.replaceAll(entry.key, entry.value);
          modified = true;
        }
      }

      if (modified) {
        await file.writeAsString(content);
      }
    } catch (e) {
      // Skip files that can't be read as text
    }
  }

  /// Configure package using basic file replacement
  static Future<void> _configurePackage(ProjectConfig config) async {
    try {
      // For now, we'll use simple file replacement instead of package_rename
      // This can be enhanced later with proper package_rename integration
    } catch (e) {
      // Continue anyway as this is not critical for basic functionality
    }
  }

  /// Update pubspec.yaml with correct project information
  static Future<void> _updatePubspec(ProjectConfig config, String projectPath) async {
    final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
    
    if (await pubspecFile.exists()) {
      String content = await pubspecFile.readAsString();
      
      // Replace project name, description and other placeholders
      content = content.replaceAll('name: dcf_go', 'name: ${config.projectDirectoryName}');
      content = content.replaceAll('name: {{PROJECT_NAME}}', 'name: ${config.projectDirectoryName}');
      content = content.replaceAll('description: "A new DCFlight project."', 'description: "${config.description}"');
      content = content.replaceAll('description: {{DESCRIPTION}}', 'description: "${config.description}"');
      
      // Fix dependency paths - they should point to ../packages/ from the project root
      content = content.replaceAll('path: ../../dcflight', 'path: ../packages/dcflight');
      content = content.replaceAll('path: ../../dcf_primitives', 'path: ../packages/dcf_primitives');
      
      await pubspecFile.writeAsString(content);
    }
  }
}
