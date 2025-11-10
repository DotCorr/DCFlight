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
  /// Copies template files to create a new project.
  /// 
  /// Creates the target directory, copies all template files, and processes
  /// platform-specific files based on the selected platforms.
  /// 
  /// - [config]: Project configuration containing directory name and platform selections
  static Future<void> copyTemplate(ProjectConfig config) async {
    final templatePath = await _getTemplatePath();
    final targetPath = path.join(Directory.current.path, config.projectDirectoryName);
    
    final targetDir = Directory(targetPath);
    if (await targetDir.exists()) {
      throw Exception('Directory ${config.projectDirectoryName} already exists');
    }
    
    await targetDir.create(recursive: true);
    await _copyDirectory(templatePath, targetPath);
    await _processPlatformFiles(config, targetPath);
  }

  /// Gets the path to the template directory.
  /// 
  /// Tries multiple possible locations and returns the first one that exists.
  /// Throws an exception if no template directory is found.
  static Future<String> _getTemplatePath() async {
    final possiblePaths = await _getPossibleTemplatePaths();
    
    for (final templatePath in possiblePaths) {
      final templateDir = Directory(templatePath);
      if (await templateDir.exists()) {
        return templatePath;
      }
    }
    
    throw Exception('DCFlight template not found. Tried paths:\n${possiblePaths.join('\n')}\n\nMake sure DCFlight is properly installed.');
  }

  /// Gets possible template paths to check.
  /// 
  /// Checks multiple locations in order:
  /// 1. Relative to CLI script location (works when running from any directory)
  /// 2. Current working directory (development mode)
  /// 3. Global installation path (if CLI is globally installed)
  static Future<List<String>> _getPossibleTemplatePaths() async {
    final paths = <String>[];
    
    try {
      final scriptPath = Platform.script.toFilePath();
      final scriptDir = path.dirname(scriptPath);
      
      if (path.basename(scriptDir) == 'bin' && path.basename(path.dirname(scriptDir)) == 'cli') {
        final cliDir = path.dirname(scriptDir);
        final repoRoot = path.dirname(cliDir);
        paths.add(path.join(repoRoot, 'packages', 'template', 'dcf_go'));
      } else if (path.basename(scriptDir) == 'cli') {
        final repoRoot = path.dirname(scriptDir);
        paths.add(path.join(repoRoot, 'packages', 'template', 'dcf_go'));
      }
    } catch (e) {
      // Ignore errors when trying to get script path
    }
    
    final currentDir = Directory.current.path;
    if (path.basename(currentDir) == 'cli') {
      final repoRoot = path.dirname(currentDir);
      paths.add(path.join(repoRoot, 'packages', 'template', 'dcf_go'));
    }
    paths.add(path.join(currentDir, 'packages', 'template', 'dcf_go'));
    
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

  /// Copies a directory recursively to the target path.
  /// 
  /// Skips build artifacts, IDE files, and version control directories.
  /// 
  /// - [sourcePath]: Source directory to copy from
  /// - [targetPath]: Target directory to copy to
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

  /// Checks if an entity should be skipped during copying.
  /// 
  /// Skips build artifacts, IDE files, version control directories, OS files, and logs.
  /// 
  /// - [name]: Name of the entity to check
  /// - Returns: `true` if the entity should be skipped, `false` otherwise
  static bool _shouldSkipEntity(String name) {
    final skipList = {
      'build',
      '.dart_tool',
      '.packages',
      'pubspec.lock',
      '.idea',
      '.vscode',
      '*.iml',
      '.git',
      '.DS_Store',
      'Thumbs.db',
      '*.log',
    };

    if (skipList.contains(name)) {
      return true;
    }

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

  /// Processes platform-specific files by removing directories for unselected platforms.
  /// 
  /// - [config]: Project configuration containing selected platforms
  /// - [projectPath]: Path to the project directory
  static Future<void> _processPlatformFiles(ProjectConfig config, String projectPath) async {
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
