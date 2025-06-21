/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dcflight_cli/services/user_input.dart';
import 'package:dcflight_cli/services/template_copier.dart';
import 'package:dcflight_cli/services/package_renamer.dart';
import 'package:dcflight_cli/models/project_config.dart';

class ProjectCreator {
  Future<void> createApp() async {
    try {
      // 1. Collect user input
      final config = await _collectUserInput();
      
      // 2. Validate project doesn't exist
      await _validateProject(config);
      
      // 3. Copy template
      await TemplateCopier.copyTemplate(config);
      
      // 4. Run package rename
      await PackageRenamer.renameProject(config);
      
      // 5. Run flutter pub get
      await _runPubGet(config);
      
      // 6. Success message
      _printSuccessMessage(config);
      
    } catch (e) {
      exit(1);
    }
  }

  Future<ProjectConfig> _collectUserInput() async {
    
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
      throw Exception('Directory "${config.projectDirectoryName}" already exists');
    }
    
    // Validate configuration
    config.validate();
  }

  /// Run pub get in the new project
  Future<void> _runPubGet(ProjectConfig config) async {
    final projectPath = path.join(Directory.current.path, config.projectDirectoryName);
    final originalDir = Directory.current;
    
    try {
      // Change to project directory
      Directory.current = projectPath;
      
      // Run flutter pub get (DCFlight projects use Flutter's pub system)
      final result = await Process.run('flutter', ['pub', 'get']);
      
      if (result.exitCode != 0) {
        if (result.stderr.toString().isNotEmpty) {
        }
      } else {
      }
    } finally {
      // Restore original directory
      Directory.current = originalDir;
    }
  }

  void _printSuccessMessage(ProjectConfig config) {
  }
}
