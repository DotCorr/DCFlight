#!/usr/bin/env dart
// Sync workspace dependencies from root pubspec.yaml to all packages
// Reads framework_paths from root pubspec.yaml and generates pubspec_overrides.yaml for each package

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

void main() async {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final workspaceRoot = scriptDir.parent;
  
  print('🔄 Syncing workspace dependencies from root pubspec.yaml...');
  
  // Read root pubspec.yaml
  final rootPubspec = File(path.join(workspaceRoot.path, 'pubspec.yaml'));
  if (!await rootPubspec.exists()) {
    print('❌ Root pubspec.yaml not found');
    exit(1);
  }
  
  final rootContent = await rootPubspec.readAsString();
  final rootYaml = loadYaml(rootContent);
  
  // Extract framework_paths
  final frameworkPaths = rootYaml['framework_paths'] as Map?;
  if (frameworkPaths == null) {
    print('❌ framework_paths not found in root pubspec.yaml');
    exit(1);
  }
  
  // Find all packages (directories with pubspec.yaml)
  final packages = <Directory>[];
  await _findPackages(workspaceRoot, packages);
  
  print('📦 Found ${packages.length} packages');
  
  // Generate pubspec_overrides.yaml for each package
  for (final packageDir in packages) {
    final relativePath = path.relative(packageDir.path, from: workspaceRoot.path);
    final overridesFile = File(path.join(packageDir.path, 'pubspec_overrides.yaml'));
    
    // Calculate relative paths from package to framework packages
    final dependencyOverrides = <String, Map<String, String>>{};
    
    for (final entry in frameworkPaths.entries) {
      final packageName = entry.key as String;
      final packagePath = entry.value as String;
      
      // Calculate relative path from this package to the framework package
      final frameworkPackagePath = path.join(workspaceRoot.path, packagePath);
      final relativeToPackage = path.relative(frameworkPackagePath, from: packageDir.path);
      
      dependencyOverrides[packageName] = {'path': relativeToPackage};
    }
    
    // Generate YAML content
    final yamlContent = StringBuffer();
    yamlContent.writeln('# Auto-generated workspace dependency overrides');
    yamlContent.writeln('# Generated from root pubspec.yaml - DO NOT EDIT MANUALLY');
    yamlContent.writeln('# Run: dart run scripts/sync_workspace_deps.dart');
    yamlContent.writeln('');
    yamlContent.writeln('dependency_overrides:');
    
    for (final entry in dependencyOverrides.entries) {
      yamlContent.writeln('  ${entry.key}:');
      yamlContent.writeln('    path: ${entry.value['path']}');
    }
    
    await overridesFile.writeAsString(yamlContent.toString());
    print('  ✅ ${path.basename(packageDir.path)}');
  }
  
  print('✅ Workspace dependencies synced!');
  print('');
  print('📦 Running flutter pub get in all packages...');
  
  // Run pub get in root first
  print('  🔧 Root workspace...');
  final rootPubGet = await Process.run('flutter', ['pub', 'get'],
      workingDirectory: workspaceRoot.path);
  if (rootPubGet.exitCode != 0) {
    print('  ⚠️  Root pub get had warnings');
  }
  
  // Run pub get in all packages
  for (final packageDir in packages) {
    final packageName = path.basename(packageDir.path);
    print('  📦 $packageName...');
    
    final pubGet = await Process.run('flutter', ['pub', 'get'],
        workingDirectory: packageDir.path);
    if (pubGet.exitCode != 0) {
      print('  ⚠️  $packageName had warnings');
    }
  }
  
  // Also run in cli if it exists
  final cliDir = Directory(path.join(workspaceRoot.path, 'cli'));
  if (await cliDir.exists()) {
    final cliPubspec = File(path.join(cliDir.path, 'pubspec.yaml'));
    if (await cliPubspec.exists()) {
      print('  📦 cli...');
      final cliPubGet = await Process.run('dart', ['pub', 'get'],
          workingDirectory: cliDir.path);
      if (cliPubGet.exitCode != 0) {
        print('  ⚠️  cli had warnings');
      }
    }
  }
  
  print('');
  print('✅ All dependencies installed!');
}

Future<void> _findPackages(Directory dir, List<Directory> packages) async {
  await for (final entity in dir.list()) {
    if (entity is Directory) {
      final dirName = path.basename(entity.path);
      
      // Skip hidden dirs, build dirs, and known non-package dirs
      if (dirName.startsWith('.') || 
          dirName == 'build' || 
          dirName == 'scripts' ||
          dirName == 'docs' ||
          dirName == 'experiments' ||
          dirName == 'ide' ||
          dirName == 'vscode-extension') {
        continue;
      }
      
      // Check if this directory has a pubspec.yaml
      final pubspec = File(path.join(entity.path, 'pubspec.yaml'));
      if (await pubspec.exists()) {
        packages.add(entity);
      } else {
        // Recursively search subdirectories
        await _findPackages(entity, packages);
      }
    }
  }
}

