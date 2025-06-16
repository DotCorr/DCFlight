/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dcflight_cli/models/project_config.dart';

class TemplateCopier {
  /// Copy template files to create a new project
  static Future<void> copyTemplate(ProjectConfig config) async {
    final templatePath = await _getTemplatePath();
    final targetPath = path.join(Directory.current.path, config.projectDirectoryName);
    
    // Create target directory
    final targetDir = Directory(targetPath);
    if (await targetDir.exists()) {
      throw Exception('Directory ${config.projectDirectoryName} already exists');
    }
    
    await targetDir.create(recursive: true);
    
    // Copy template files
    await _copyDirectory(templatePath, targetPath);
    
    // Process platform-specific files
    await _processPlatformFiles(config, targetPath);
  }

  /// Get the path to the template directory
  static Future<String> _getTemplatePath() async {
    // Try to find the template path in multiple locations
    final possiblePaths = await _getPossibleTemplatePaths();
    
    for (final templatePath in possiblePaths) {
      final templateDir = Directory(templatePath);
      if (await templateDir.exists()) {
        return templatePath;
      }
    }
    
    throw Exception('DCFlight template not found. Tried paths:\n${possiblePaths.join('\n')}\n\nMake sure DCFlight is properly installed.');
  }

  /// Get possible template paths to check
  static Future<List<String>> _getPossibleTemplatePaths() async {
    final currentDir = Directory.current.path;
    final paths = <String>[];
    
    // 1. If we're in the cli subfolder, go up one level (development mode)
    if (path.basename(currentDir) == 'cli') {
      final repoRoot = path.dirname(currentDir);
      paths.add(path.join(repoRoot, 'packages', 'template', 'dcf_go'));
    }
    
    // 2. Try current directory (development mode)
    paths.add(path.join(currentDir, 'packages', 'template', 'dcf_go'));
    
    // 3. Try to find the CLI installation path (global mode)
    try {
      final result = await Process.run('dart', ['pub', 'global', 'list']);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.contains('dcflight_cli') && line.contains('at path')) {
            final pathMatch = RegExp(r'at path "([^"]+)"').firstMatch(line);
            if (pathMatch != null) {
              final cliPath = pathMatch.group(1)!;
              final repoRoot = path.dirname(cliPath);
              paths.add(path.join(repoRoot, 'packages', 'template', 'dcf_go'));
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors when trying to get global installation path
    }
    
    return paths;
  }

  /// Copy directory recursively
  static Future<void> _copyDirectory(String sourcePath, String targetPath) async {
    final sourceDir = Directory(sourcePath);
    final targetDir = Directory(targetPath);
    
    if (!await sourceDir.exists()) {
      throw Exception('Template directory not found: $sourcePath');
    }
    
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    
    await for (final entity in sourceDir.list(recursive: false)) {
      final entityName = path.basename(entity.path);
      
      // Skip build artifacts and other files we don't want to copy
      if (_shouldSkipEntity(entityName)) {
        continue;
      }
      
      final targetEntityPath = path.join(targetPath, entityName);
      
      if (entity is Directory) {
        await _copyDirectory(entity.path, targetEntityPath);
      } else if (entity is File) {
        await entity.copy(targetEntityPath);
      }
    }
  }

  /// Check if an entity should be skipped during copying
  static bool _shouldSkipEntity(String name) {
    final skipList = {
      // Build artifacts
      'build',
      '.dart_tool',
      '.packages',
      'pubspec.lock',
      
      // IDE files
      '.idea',
      '.vscode',
      '*.iml',
      
      // Version control
      '.git',
      // '.gitignore',
      
      // OS files
      '.DS_Store',
      'Thumbs.db',
      
      // Logs
      '*.log',
    };

    // Check exact matches
    if (skipList.contains(name)) {
      return true;
    }

    // Check pattern matches
    for (final pattern in skipList) {
      if (pattern.contains('*')) {
        final regex = RegExp(pattern.replaceAll('*', '.*'));
        if (regex.hasMatch(name)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Process platform-specific files
  static Future<void> _processPlatformFiles(ProjectConfig config, String projectPath) async {
    // Remove platform directories that are not selected
    final platformDirs = ['ios', 'android', 'web', 'macos', 'windows', 'linux'];
    final selectedPlatforms = config.platforms.map((p) => p.name).toSet();
    
    for (final platformDir in platformDirs) {
      if (!selectedPlatforms.contains(platformDir)) {
        final platformPath = path.join(projectPath, platformDir);
        final dir = Directory(platformPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    }
  }
}
