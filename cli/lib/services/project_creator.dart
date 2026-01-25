/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dcflight_cli/services/user_input.dart';
import 'package:dcflight_cli/services/template_copier.dart';
import 'package:dcflight_cli/services/package_renamer.dart';
import 'package:dcflight_cli/models/project_config.dart';
import 'package:dcflight_cli/models/platform.dart';

class ProjectCreator {
  /// Creates a new DCFlight app project.
  /// 
  /// Collects user input, validates configuration, copies template,
  /// configures the project, and installs dependencies.
  Future<void> createApp() async {
    try {
      final config = await _collectUserInput();
      await _validateProject(config);

      print('📁 Copying template...');
      await TemplateCopier.copyTemplate(config);

      print('🔧 Configuring project...');
      await PackageRenamer.renameProject(config);

      print('📦 Installing dependencies...');
      await _runPubGet(config);

      _printSuccessMessage(config);
    } catch (e) {
      print('❌ Error creating project: $e');
      exit(1);
    }
  }

  Future<ProjectConfig> _collectUserInput() async {
    print('Please provide the following information:\n');

    final projectName = await UserInput.promptProjectName();
    final appName = await UserInput.promptAppName();
    final packageName = await UserInput.promptPackageName();
    final platforms = await UserInput.promptPlatforms();
    final description = await UserInput.promptDescription();
    final organization = await UserInput.promptOrganization();

    return ProjectConfig(
      projectName: projectName,
      appName: appName,
      packageName: packageName,
      platforms: platforms,
      description: description,
      organization: organization,
    );
  }

  Future<void> _validateProject(ProjectConfig config) async {
    final projectDir = Directory(config.projectDirectoryName);
    if (await projectDir.exists()) {
      throw Exception(
          'Directory "${config.projectDirectoryName}" already exists');
    }

    // Validate configuration
    config.validate();
  }

  /// Runs pub get in the new project to install dependencies.
  /// Also runs pod install for iOS projects.
  /// 
  /// - [config]: Project configuration
  Future<void> _runPubGet(ProjectConfig config) async {
    final projectPath =
        path.join(Directory.current.path, config.projectDirectoryName);
    final originalDir = Directory.current;

    try {
      Directory.current = projectPath;
      
      // Run flutter pub get
      print('   Running flutter pub get...');
      final pubGetResult = await Process.run('flutter', ['pub', 'get']);

      if (pubGetResult.exitCode != 0) {
        print('⚠️  Warning: Failed to install dependencies');
        if (pubGetResult.stderr.toString().isNotEmpty) {
          print('   Error: ${pubGetResult.stderr}');
        }
        print('   You may need to run "flutter pub get" manually');
      } else {
        print('   ✅ Flutter dependencies installed');
      }

      // Run pod install for iOS projects
      if (config.platforms.contains(Platform.ios)) {
        final iosPath = path.join(projectPath, 'ios');
        final iosDir = Directory(iosPath);
        
        if (await iosDir.exists()) {
          print('   Installing iOS CocoaPods dependencies...');
          Directory.current = iosPath;
          
          final podResult = await Process.run('pod', ['install'], 
            runInShell: true);
          
          if (podResult.exitCode != 0) {
            print('⚠️  Warning: Failed to install CocoaPods dependencies');
            if (podResult.stderr.toString().isNotEmpty) {
              print('   Error: ${podResult.stderr}');
            }
            print('   You may need to run "cd ios && pod install" manually');
          } else {
            print('   ✅ iOS CocoaPods installed');
          }
          
          Directory.current = projectPath;
        }
      }
      
        print('✅ Dependencies installed successfully');
    } catch (e) {
      print('⚠️  Warning: Error during dependency installation: $e');
      print('   You may need to run "flutter pub get" manually');
      if (config.platforms.contains(Platform.ios)) {
        print('   For iOS: "cd ios && pod install"');
      }
    } finally {
      Directory.current = originalDir;
    }
  }

  void _printSuccessMessage(ProjectConfig config) {
    print('\n🎉 Project "${config.appName}" created successfully!\n');
    print('📁 Location: ${path.absolute(config.projectDirectoryName)}');
    print('📱 App Name: ${config.appName}');
    print('📦 Package: ${config.packageName}');
    print(
        '🎯 Platforms: ${config.platforms.map((p) => p.displayName).join(', ')}\n');
    print('🚀 Next steps:');
    print('   cd ${config.projectDirectoryName}');
    print('   dcf run');
    print('\n✨ Happy coding with DCFlight!');
  }
}
