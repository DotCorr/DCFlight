/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */


import 'dart:io';
import 'dart:isolate';
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
    
    // Method 1: Try to resolve from Platform.script (works for dart run and compiled executables)
    try {
      final scriptUri = Platform.script;
      String? scriptPath;
      
      if (scriptUri.scheme == 'file') {
        scriptPath = scriptUri.toFilePath();
      } else if (scriptUri.scheme == 'package') {
        // For package: URIs, try to resolve the actual file location
        // This happens when running via 'dart run' from pub cache
        try {
          final resolved = await Isolate.resolvePackageUri(scriptUri);
          if (resolved != null && resolved.scheme == 'file') {
            scriptPath = resolved.toFilePath();
          }
        } catch (e) {
          // Ignore resolution errors
        }
      } else if (scriptUri.scheme == 'data') {
        // For data: URIs (snapshots), try to use Platform.resolvedExecutable
        // and work backwards, but this is complex - skip for now
      }
      
      if (scriptPath != null && scriptPath.isNotEmpty) {
        // Normalize the path (resolve symlinks, etc.)
        String? normalizedPath = scriptPath;
        try {
          normalizedPath = await File(scriptPath).resolveSymbolicLinks();
        } catch (e) {
          // If it's not a file or doesn't exist, use the original path
        }
        
        if (normalizedPath != null && normalizedPath.isNotEmpty) {
          scriptPath = normalizedPath;
          
          final scriptDir = path.dirname(scriptPath);
          final scriptDirName = path.basename(scriptDir);
          final parentDirName = path.basename(path.dirname(scriptDir));
          
          // Check if we're in cli/bin/ structure (most common case)
          if (scriptDirName == 'bin' && parentDirName == 'cli') {
            final cliDir = path.dirname(scriptDir);
            final repoRoot = path.dirname(cliDir);
            final templatePath = path.join(repoRoot, 'packages', 'template', 'dcf_go');
            if (!paths.contains(templatePath)) {
              paths.add(templatePath);
            }
          } 
          // Check if script is directly in cli/ directory
          else if (scriptDirName == 'cli') {
            final repoRoot = path.dirname(scriptDir);
            final templatePath = path.join(repoRoot, 'packages', 'template', 'dcf_go');
            if (!paths.contains(templatePath)) {
              paths.add(templatePath);
            }
          }
          // Walk up the directory tree to find 'cli' directory
          else {
            var currentDir = scriptDir;
            for (int i = 0; i < 10; i++) { // Limit to 10 levels up
              final dirName = path.basename(currentDir);
              if (dirName == 'cli') {
                final repoRoot = path.dirname(currentDir);
                final templatePath = path.join(repoRoot, 'packages', 'template', 'dcf_go');
                if (!paths.contains(templatePath)) {
                  paths.add(templatePath);
                }
                break;
              }
              final parent = path.dirname(currentDir);
              if (parent == currentDir) break; // Reached root
              currentDir = parent;
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors when trying to get script path
    }
    
    // Method 2: Check current working directory (for development)
    final currentDir = Directory.current.path;
    if (path.basename(currentDir) == 'cli') {
      final repoRoot = path.dirname(currentDir);
      paths.add(path.join(repoRoot, 'packages', 'template', 'dcf_go'));
    }
    // Also check if we're in the repo root
    paths.add(path.join(currentDir, 'packages', 'template', 'dcf_go'));
    // Check if we're in DCFlight root
    if (path.basename(currentDir) == 'DCFlight') {
      paths.add(path.join(currentDir, 'packages', 'template', 'dcf_go'));
    }
    
    // Method 3: Try to find via environment variable (if set)
    final envPath = Platform.environment['DCFLIGHT_PATH'];
    if (envPath != null) {
      paths.add(path.join(envPath, 'packages', 'template', 'dcf_go'));
    }
    
    // Method 4: Check global installation path
    try {
      final result = await Process.run('dart', ['pub', 'global', 'list']);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.contains('dcflight_cli') && line.contains('at path')) {
            final pathMatch = RegExp(r'at path "([^"]+)"').firstMatch(line);
            if (pathMatch != null) {
              final cliPath = pathMatch.group(1)!;
              // For global installs, the path might point to the package cache
              // Try to find the actual repo root
              var checkPath = cliPath;
              for (int i = 0; i < 5; i++) {
                final templatePath = path.join(checkPath, 'packages', 'template', 'dcf_go');
                if (await Directory(templatePath).exists()) {
                  paths.add(templatePath);
                  break;
                }
                final parent = path.dirname(checkPath);
                if (parent == checkPath) break;
                checkPath = parent;
              }
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
