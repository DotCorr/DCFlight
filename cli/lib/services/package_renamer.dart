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
  /// Renames and configures the project based on user input.
  /// 
  /// Replaces template placeholders, configures the package, and updates pubspec.yaml.
  /// 
  /// - [config]: Project configuration containing naming information
  static Future<void> renameProject(ProjectConfig config) async {
    final projectPath = path.join(Directory.current.path, config.projectDirectoryName);
    
    final originalDir = Directory.current;
    Directory.current = projectPath;
    
    try {
      await _replaceTemplatePlaceholders(config, projectPath);
      await _configurePackage(config);
      await _updatePubspec(config, projectPath);
    } finally {
      Directory.current = originalDir;
    }
  }

  /// Replaces template placeholders in all files.
  /// 
  /// - [config]: Project configuration
  /// - [projectPath]: Path to the project directory
  static Future<void> _replaceTemplatePlaceholders(ProjectConfig config, String projectPath) async {
    final replacements = {
      '{{PROJECT_NAME}}': config.projectDirectoryName,
      '{{APP_NAME}}': config.appName,
      '{{APP_CLASS}}': config.appClassName,
      '{{PACKAGE_NAME}}': config.packageName,
      '{{DESCRIPTION}}': config.description,
      '{{ORGANIZATION}}': config.organization,
      'dcf_go': config.projectDirectoryName,
      'package:dcf_go': 'package:${config.projectDirectoryName}',
    };

    await _processDirectory(Directory(projectPath), replacements);
  }

  /// Processes directory recursively to replace placeholders.
  /// 
  /// Skips build and hidden directories.
  /// 
  /// - [dir]: Directory to process
  /// - [replacements]: Map of placeholder to replacement value
  static Future<void> _processDirectory(Directory dir, Map<String, String> replacements) async {
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final dirName = path.basename(entity.path);
        if (!dirName.startsWith('.') && dirName != 'build') {
          await _processDirectory(entity, replacements);
        }
      } else if (entity is File) {
        await _processFile(entity, replacements);
      }
    }
  }

  /// Processes individual file to replace placeholders.
  /// 
  /// Only processes text files with supported extensions.
  /// 
  /// - [file]: File to process
  /// - [replacements]: Map of placeholder to replacement value
  static Future<void> _processFile(File file, Map<String, String> replacements) async {
    final fileName = path.basename(file.path);
    final extension = path.extension(fileName);
    
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
      print('Warning: Could not process file ${file.path}: $e');
    }
  }

  /// Configures package using basic file replacement.
  /// 
  /// This can be enhanced later with proper package_rename integration.
  /// 
  /// - [config]: Project configuration
  static Future<void> _configurePackage(ProjectConfig config) async {
    try {
      print('✅ Package configuration completed via template replacement');
    } catch (e) {
      print('Warning: Could not configure package: $e');
    }
  }

  /// Updates pubspec.yaml with correct project information.
  /// 
  /// Replaces project name, description, and fixes dependency paths.
  /// 
  /// - [config]: Project configuration
  /// - [projectPath]: Path to the project directory
  static Future<void> _updatePubspec(ProjectConfig config, String projectPath) async {
    final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
    
    if (await pubspecFile.exists()) {
      String content = await pubspecFile.readAsString();
      
      content = content.replaceAll('name: dcf_go', 'name: ${config.projectDirectoryName}');
      content = content.replaceAll('name: {{PROJECT_NAME}}', 'name: ${config.projectDirectoryName}');
      content = content.replaceAll('description: "A new DCFlight project."', 'description: "${config.description}"');
      content = content.replaceAll('description: {{DESCRIPTION}}', 'description: "${config.description}"');
      
      content = content.replaceAll('path: ../../dcflight', 'path: ../packages/dcflight');
      content = content.replaceAll('path: ../../dcf_primitives', 'path: ../packages/dcf_primitives');
      
      await pubspecFile.writeAsString(content);
    }
  }
}
