/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dcflight_cli/services/user_input.dart';

class ModuleCreator {
  /// Creates a new DCFlight module.
  /// 
  /// Collects user input, validates the module name, copies the template,
  /// and configures the module with the provided information.
  static Future<void> createModule() async {
    try {
      final moduleName = await UserInput.promptModuleName();
      final moduleDescription = await UserInput.promptModuleDescription();
      
      _validateModuleName(moduleName);
      
      print('📁 Copying module template...');
      await _copyModuleTemplate(moduleName, moduleDescription);
      
      _printSuccessMessage(moduleName);
      
    } catch (e) {
      print('❌ Error creating module: $e');
      exit(1);
    }
  }

  /// Validates module name format.
  /// 
  /// Module names must be lowercase, contain only letters, numbers, and underscores,
  /// and cannot start or end with an underscore.
  /// 
  /// - [name]: Module name to validate
  /// - Throws: [ArgumentError] if the name is invalid
  static void _validateModuleName(String name) {
    if (name.isEmpty) {
      throw ArgumentError('Module name cannot be empty');
    }
    
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      throw ArgumentError('Module name must be lowercase and contain only letters, numbers, and underscores');
    }
    
    if (name.startsWith('_') || name.endsWith('_')) {
      throw ArgumentError('Module name cannot start or end with underscore');
    }
  }

  /// Copies module template and configures it with the provided information.
  /// 
  /// - [moduleName]: Name of the module to create
  /// - [description]: Description of the module
  static Future<void> _copyModuleTemplate(String moduleName, String description) async {
    final templatePath = await _getModuleTemplatePath();
    
    final currentDir = Directory.current;
    final targetPath = path.join(currentDir.path, 'lib', 'modules', moduleName);
    final targetDir = Directory(targetPath);
    
    if (await targetDir.exists()) {
      throw Exception('Module $moduleName already exists');
    }
    
    await targetDir.create(recursive: true);
    await _copyDirectoryWithRenaming(templatePath, targetPath, moduleName);
    await _replaceModulePlaceholders(moduleName, description, targetPath);
  }

  /// Gets the path to the module template directory.
  /// 
  /// Tries multiple possible locations and returns the first one that exists.
  static Future<String> _getModuleTemplatePath() async {
    final possiblePaths = await _getPossibleModuleTemplatePaths();
    
    for (final templatePath in possiblePaths) {
      final templateDir = Directory(templatePath);
      if (await templateDir.exists()) {
        return templatePath;
      }
    }
    
    throw Exception('DCFlight module template not found. Tried paths:\n${possiblePaths.join('\n')}\n\nMake sure DCFlight is properly installed.');
  }

  /// Get possible module template paths to check
  static Future<List<String>> _getPossibleModuleTemplatePaths() async {
    final paths = <String>[];
    
    // 1. Try to resolve template path relative to the CLI script location
    // This works when running: dart run /path/to/DCFlight/cli/bin/dcflight_cli.dart
    try {
      final scriptPath = Platform.script.toFilePath();
      final scriptDir = path.dirname(scriptPath);
      
      // If script is in cli/bin/, go up to cli/, then to repo root
      if (path.basename(scriptDir) == 'bin' && path.basename(path.dirname(scriptDir)) == 'cli') {
        final cliDir = path.dirname(scriptDir);
        final repoRoot = path.dirname(cliDir);
        paths.add(path.join(repoRoot, 'packages', 'template', 'dcf_module'));
      }
      // If script is directly in cli/, go up to repo root
      else if (path.basename(scriptDir) == 'cli') {
        final repoRoot = path.dirname(scriptDir);
        paths.add(path.join(repoRoot, 'packages', 'template', 'dcf_module'));
      }
    } catch (e) {
      // Ignore errors when trying to get script path
    }
    
    // 2. Try current working directory (development mode - when running from repo root)
    final currentDir = Directory.current.path;
    if (path.basename(currentDir) == 'cli') {
      final repoRoot = path.dirname(currentDir);
      paths.add(path.join(repoRoot, 'packages', 'template', 'dcf_module'));
    }
    paths.add(path.join(currentDir, 'packages', 'template', 'dcf_module'));
    
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
              paths.add(path.join(repoRoot, 'packages', 'template', 'dcf_module'));
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors when trying to get global installation path
    }
    
    return paths;
  }

  /// Copy directory recursively with file renaming
  static Future<void> _copyDirectoryWithRenaming(String sourcePath, String targetPath, String moduleName) async {
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
      
      final targetEntityName = _renameEntity(entityName, moduleName);
      final targetEntityPath = path.join(targetPath, targetEntityName);
      
      if (entity is Directory) {
        await _copyDirectoryWithRenaming(entity.path, targetEntityPath, moduleName);
      } else if (entity is File) {
        await entity.copy(targetEntityPath);
      }
    }
  }

  /// Renames entity if it matches template patterns.
  /// 
  /// - [entityName]: Original entity name
  /// - [moduleName]: Module name to use in renamed files
  /// - Returns: Renamed entity name or original if no match
  static String _renameEntity(String entityName, String moduleName) {
    final renamingMap = {
      'dcf_module.dart': '$moduleName.dart',
      'dcf_module.podspec': '$moduleName.podspec',
      'dcf_module.swift': '$moduleName.swift',
      'dcf_module_plugin.dart': '${moduleName}_plugin.dart',
    };
    
    return renamingMap[entityName] ?? entityName;
  }

  /// Checks if an entity should be skipped during copying.
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
      '.gitignore',
      '.DS_Store',
      'Thumbs.db',
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

  /// Replaces module placeholders in copied files.
  /// 
  /// - [moduleName]: Name of the module
  /// - [description]: Description of the module
  /// - [modulePath]: Path to the module directory
  static Future<void> _replaceModulePlaceholders(String moduleName, String description, String modulePath) async {
    final className = _toPascalCase(moduleName);
    
    // Refactor Android package structure
    await _refactorAndroidPackageStructure(modulePath, moduleName);
    
    // Replace all text placeholders
    final replacements = {
      'dcf_module': moduleName,
      'DcfModule': className,
      'Example Module': description,
      'dcf_module_plugin': '${moduleName}_plugin',
      'DcfModulePlugin': '${className}Plugin',
      'com.dotcorr.dcf_module': 'com.dotcorr.$moduleName',
      'com/dotcorr/dcf_module': 'com/dotcorr/$moduleName',
      'package com.dotcorr.dcf_module': 'package com.dotcorr.$moduleName',
      'import com.dotcorr.dcf_module': 'import com.dotcorr.$moduleName',
      'com.dotcorr.dcf_module.R': 'com.dotcorr.$moduleName.R',
      'com.dotcorr.dcf_module.components': 'com.dotcorr.$moduleName.components',
      'package com.dotcorr.dcf_module.components': 'package com.dotcorr.$moduleName.components',
      "group 'com.dotcorr.dcf_module'": "group 'com.dotcorr.$moduleName'",
      "namespace 'com.dotcorr.dcf_module'": "namespace 'com.dotcorr.$moduleName'",
      'name: dcf_module': 'name: $moduleName',
    };

    await _processDirectory(Directory(modulePath), replacements);
  }

  /// Refactors Android package structure by renaming directories.
  /// 
  /// Moves files from com/dotcorr/dcf_module to com/dotcorr/{moduleName}
  /// 
  /// - [modulePath]: Path to the module directory
  /// - [moduleName]: Name of the module
  static Future<void> _refactorAndroidPackageStructure(String modulePath, String moduleName) async {
    final androidKotlinPath = path.join(modulePath, 'android', 'src', 'main', 'kotlin', 'com', 'dotcorr');
    final oldPackageDir = Directory(path.join(androidKotlinPath, 'dcf_module'));
    final newPackageDir = Directory(path.join(androidKotlinPath, moduleName));
    
    if (await oldPackageDir.exists()) {
      // Move the entire directory
      await oldPackageDir.rename(newPackageDir.path);
    }
    
    // Also handle the components subdirectory if it exists
    final oldComponentsDir = Directory(path.join(newPackageDir.path, 'components'));
    if (await oldComponentsDir.exists()) {
      // Components directory is already moved with the parent, no action needed
    }
  }

  /// Processes directory recursively to replace placeholders.
  /// 
  /// - [dir]: Directory to process
  /// - [replacements]: Map of placeholder to replacement value
  static Future<void> _processDirectory(Directory dir, Map<String, String> replacements) async {
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        await _processDirectory(entity, replacements);
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
    
    final textExtensions = {'.dart', '.yaml', '.yml', '.md', '.txt', '.json', '.podspec', '.swift', '.kt', '.gradle', '.xml'};
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

  /// Converts snake_case to PascalCase.
  /// 
  /// - [input]: Input string in snake_case
  /// - Returns: String in PascalCase
  static String _toPascalCase(String input) {
    return input.split('_').map((word) => 
        word.substring(0, 1).toUpperCase() + word.substring(1).toLowerCase()
    ).join('');
  }

  /// Print success message
  static void _printSuccessMessage(String moduleName) {
    final className = _toPascalCase(moduleName);
    
    print('\n✅ Module created successfully!');
    print('📁 Location: lib/modules/$moduleName/');
    print('🏗️  Module: $className');
    print('\n📖 Next steps:');
    print('   1. Import the module: import \'modules/$moduleName/$moduleName.dart\';');
    print('   2. Use the module in your app');
    print('\n🎉 Happy coding with DCFlight!');
  }
}
