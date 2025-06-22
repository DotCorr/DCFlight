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
  /// Create a new DCFlight module
  static Future<void> createModule() async {
    try {
      // 1. Collect module information
      final moduleName = await UserInput.promptModuleName();
      final moduleDescription = await UserInput.promptModuleDescription();
      
      // 2. Validate module name
      _validateModuleName(moduleName);
      
      // 3. Copy module template
      print('📁 Copying module template...');
      await _copyModuleTemplate(moduleName, moduleDescription);
      
      // 4. Success message
      _printSuccessMessage(moduleName);
      
    } catch (e) {
      print('❌ Error creating module: $e');
      exit(1);
    }
  }

  /// Validate module name format
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

  /// Copy module template and configure it
  static Future<void> _copyModuleTemplate(String moduleName, String description) async {
    // Get template path
    final templatePath = await _getModuleTemplatePath();
    
    // Create target directory in lib/modules/
    final currentDir = Directory.current;
    final targetPath = path.join(currentDir.path, 'lib', 'modules', moduleName);
    final targetDir = Directory(targetPath);
    
    if (await targetDir.exists()) {
      throw Exception('Module $moduleName already exists');
    }
    
    await targetDir.create(recursive: true);
    
    // Copy template files with renaming
    await _copyDirectoryWithRenaming(templatePath, targetPath, moduleName);
    
    // Replace placeholders in file contents
    await _replaceModulePlaceholders(moduleName, description, targetPath);
  }

  /// Get the path to the module template directory
  static Future<String> _getModuleTemplatePath() async {
    // Try to find the template path in multiple locations
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
    final currentDir = Directory.current.path;
    final paths = <String>[];
    
    // 1. If we're in the cli subfolder, go up one level (development mode)
    if (path.basename(currentDir) == 'cli') {
      final repoRoot = path.dirname(currentDir);
      paths.add(path.join(repoRoot, 'packages', 'template', 'dcf_module'));
    }
    
    // 2. Try current directory (development mode)
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
      
      // Skip build artifacts and other files we don't want to copy
      if (_shouldSkipEntity(entityName)) {
        continue;
      }
      
      // Determine target entity name (rename if needed)
      final targetEntityName = _renameEntity(entityName, moduleName);
      final targetEntityPath = path.join(targetPath, targetEntityName);
      
      if (entity is Directory) {
        await _copyDirectoryWithRenaming(entity.path, targetEntityPath, moduleName);
      } else if (entity is File) {
        await entity.copy(targetEntityPath);
      }
    }
  }

  /// Rename entity if it matches template patterns
  static String _renameEntity(String entityName, String moduleName) {
    // Define file renaming patterns
    final renamingMap = {
      'dcf_module.dart': '$moduleName.dart',
      'dcf_module.podspec': '$moduleName.podspec',
      'dcf_module.swift': '$moduleName.swift',
      'dcf_module_plugin.dart': '${moduleName}_plugin.dart',
    };
    
    return renamingMap[entityName] ?? entityName;
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
      '.gitignore',
      
      // OS files
      '.DS_Store',
      'Thumbs.db',
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

  /// Replace module placeholders in copied files
  static Future<void> _replaceModulePlaceholders(String moduleName, String description, String modulePath) async {
    final className = _toPascalCase(moduleName);
    final replacements = {
      'dcf_module': moduleName,
      'DcfModule': className,
      'Example Module': description,
      'dcf_module_plugin': '${moduleName}_plugin',
      'DcfModulePlugin': '${className}Plugin',
    };

    // Process all files in the module directory
    await _processDirectory(Directory(modulePath), replacements);
  }

  /// Process directory recursively to replace placeholders
  static Future<void> _processDirectory(Directory dir, Map<String, String> replacements) async {
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        await _processDirectory(entity, replacements);
      } else if (entity is File) {
        await _processFile(entity, replacements);
      }
    }
  }

  /// Process individual file to replace placeholders
  static Future<void> _processFile(File file, Map<String, String> replacements) async {
    final fileName = path.basename(file.path);
    final extension = path.extension(fileName);
    
    // Process text files and specific file types
    final textExtensions = {'.dart', '.yaml', '.yml', '.md', '.txt', '.json', '.podspec', '.swift'};
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
      print('Warning: Could not process file ${file.path}: $e');
    }
  }

  /// Convert snake_case to PascalCase
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
    print('   1. Import the module: import \'modules/$moduleName/${moduleName}.dart\';');
    print('   2. Use the module in your app');
    print('\n🎉 Happy coding with DCFlight!');
  }
}
