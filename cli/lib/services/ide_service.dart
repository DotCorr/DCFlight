/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

/// Service for managing DCFlight IDE (dcf-vscode + code-server)
class IDEService {
  static const String _ideDirName = '.dcf-ide';
  static const String _codeServerDirName = 'code-server';
  static const String _dcfVscodeDirName = 'dcf-vscode';
  static const String _dcfCodeServerReleasesUrl = 'https://api.github.com/repos/DotCorr/dcf-code-server/releases/latest';
  static const String _dcfVscodeReleasesUrl = 'https://api.github.com/repos/DotCorr/dcf-vscode/releases/latest';
  static const String _codeServerReleasesUrl = 'https://api.github.com/repos/coder/code-server/releases/latest';
  
  /// Get the IDE directory path in user's home
  static String get _ideBasePath {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    if (homeDir.isEmpty) {
      throw Exception('Could not determine home directory');
    }
    return path.join(homeDir, _ideDirName);
  }
  
  /// Get code-server directory path
  static String get _codeServerPath => path.join(_ideBasePath, _codeServerDirName);
  
  /// Get dcf-vscode directory path
  static String get _dcfVscodePath => path.join(_ideBasePath, _dcfVscodeDirName);
  
  /// Get user settings directory (preserved across updates)
  static String get _userSettingsPath => path.join(_ideBasePath, 'user-settings');
  
  /// Check if IDE is installed
  static Future<bool> isIDEInstalled() async {
    final codeServerExists = await Directory(_codeServerPath).exists();
    
    // Check if code-server binary exists
    if (codeServerExists) {
      final binary = await _findCodeServerBinary();
      if (binary == null) {
        return false;
      }
    }
    
    // At minimum, code-server must be installed
    // dcf-vscode is optional - code-server works standalone
    return codeServerExists;
  }
  
  /// Install IDE components (code-server and dcf-vscode)
  static Future<void> installIDE({void Function(String)? onProgress, bool forceUpdate = false}) async {
    onProgress?.call('📦 Checking IDE installation...');
    
    // Create base directory
    final baseDir = Directory(_ideBasePath);
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
      onProgress?.call('✅ Created IDE directory: $_ideBasePath');
    }
    
    // Create user settings directory (preserved across updates)
    final userSettingsDir = Directory(_userSettingsPath);
    if (!await userSettingsDir.exists()) {
      await userSettingsDir.create(recursive: true);
    }
    
    // Install code-server
    await _installCodeServer(onProgress: onProgress, forceUpdate: forceUpdate);
    
    // Install dcf-vscode
    await _installDcfVscode(onProgress: onProgress, forceUpdate: forceUpdate);
    
    onProgress?.call('✅ IDE installation complete!');
  }
  
  /// Install code-server from GitHub releases
  /// Tries dcf-code-server first, falls back to standard code-server
  static Future<void> _installCodeServer({void Function(String)? onProgress, bool forceUpdate = false}) async {
    final codeServerDir = Directory(_codeServerPath);
    final binaryName = Platform.isWindows ? 'code-server.exe' : 'code-server';
    final binaryPath = path.join(_codeServerPath, binaryName);
    
    // Check if already installed
    if (await codeServerDir.exists() && await File(binaryPath).exists() && !forceUpdate) {
      onProgress?.call('✅ code-server already installed');
      return;
    }
    
    // Try dcf-code-server first (your custom build)
    onProgress?.call('📥 Checking for dcf-code-server release...');
    
    try {
      final dcfCodeServerResponse = await http.get(Uri.parse(_dcfCodeServerReleasesUrl));
      
      if (dcfCodeServerResponse.statusCode == 200) {
        // Use dcf-code-server (your custom build)
        onProgress?.call('🔧 Found dcf-code-server release - using custom build');
        await _installCodeServerFromRelease(
          _dcfCodeServerReleasesUrl,
          onProgress: onProgress,
          forceUpdate: forceUpdate,
          isCustom: true,
        );
        return;
      } else if (dcfCodeServerResponse.statusCode == 404) {
        // Fall back to standard code-server
        onProgress?.call('📥 No dcf-code-server release found, using standard code-server');
      } else {
        onProgress?.call('⚠️  Could not check dcf-code-server releases, trying standard code-server');
      }
    } catch (e) {
      onProgress?.call('⚠️  Error checking dcf-code-server: $e, trying standard code-server');
    }
    
    // Fall back to standard code-server
    onProgress?.call('📥 Fetching latest standard code-server release...');
    
    try {
      // Get latest release info from standard code-server
      await _installCodeServerFromRelease(
        _codeServerReleasesUrl,
        onProgress: onProgress,
        forceUpdate: forceUpdate,
        isCustom: false,
      );
    } catch (e) {
      onProgress?.call('❌ Failed to install code-server: $e');
      onProgress?.call('💡 You can install manually: curl -fsSL https://code-server.dev/install.sh | sh');
      rethrow;
    }
  }
  
  /// Install code-server from a specific release URL
  static Future<void> _installCodeServerFromRelease(
    String releasesUrl, {
    void Function(String)? onProgress,
    bool forceUpdate = false,
    bool isCustom = false,
  }) async {
    final codeServerDir = Directory(_codeServerPath);
    final binaryName = Platform.isWindows ? 'code-server.exe' : 'code-server';
    final binaryPath = path.join(_codeServerPath, binaryName);
    
    try {
      // Get latest release info
      final response = await http.get(Uri.parse(releasesUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch code-server releases: ${response.statusCode}');
      }
      
      final releaseData = jsonDecode(response.body) as Map<String, dynamic>;
      final version = releaseData['tag_name'] as String;
      final assets = releaseData['assets'] as List;
      
      if (isCustom) {
        onProgress?.call('🔧 Found dcf-code-server version: $version (custom build)');
      } else {
        onProgress?.call('📦 Found code-server version: $version');
      }
      
      // Determine platform and architecture
      String platform;
      String arch;
      String extension = '.tar.gz';
      
      if (Platform.isWindows) {
        platform = 'windows';
        arch = Platform.environment['PROCESSOR_ARCHITECTURE']?.contains('64') == true ? 'x64' : 'x86';
        extension = '.zip';
      } else if (Platform.isMacOS) {
        platform = 'macos';
        // Check for Apple Silicon
        final result = await Process.run('uname', ['-m']);
        arch = result.stdout.toString().trim() == 'arm64' ? 'arm64' : 'x64';
      } else if (Platform.isLinux) {
        platform = 'linux';
        final result = await Process.run('uname', ['-m']);
        final unameArch = result.stdout.toString().trim();
        arch = unameArch.contains('aarch64') || unameArch.contains('arm64') ? 'arm64' : 'x64';
      } else {
        throw Exception('Unsupported platform: ${Platform.operatingSystem}');
      }
      
      // Find matching asset
      // code-server releases use format: code-server-VERSION-OS-ARCH.tar.gz
      // e.g., code-server-4.104.1-darwin-x64.tar.gz
      String? downloadUrl;
      String? assetName;
      
      // Normalize platform name for matching (code-server uses 'darwin' not 'macos')
      final normalizedPlatform = platform == 'macos' ? 'darwin' : platform;
      
      for (final asset in assets) {
        final name = asset['name'] as String;
        // Match: code-server-*-OS-ARCH.tar.gz or code-server-*-OS-ARCH.zip
        if (name.startsWith('code-server-') && 
            (name.contains(normalizedPlatform) || (normalizedPlatform == 'darwin' && name.contains('macos'))) &&
            name.contains(arch) && 
            name.endsWith(extension)) {
          downloadUrl = asset['browser_download_url'] as String;
          assetName = name;
          break;
        }
      }
      
      // Also try without platform name (just arch)
      if (downloadUrl == null) {
        for (final asset in assets) {
          final name = asset['name'] as String;
          if (name.startsWith('code-server-') && 
              name.contains(arch) && 
              name.endsWith(extension)) {
            downloadUrl = asset['browser_download_url'] as String;
            assetName = name;
            break;
          }
        }
      }
      
      if (downloadUrl == null || assetName == null) {
        throw Exception('No matching code-server release found for $platform/$arch. Available assets: ${assets.map((a) => a['name']).join(', ')}');
      }
      
      onProgress?.call('📥 Downloading code-server ($assetName)...');
      
      // Remove old installation if updating
      if (await codeServerDir.exists()) {
        await codeServerDir.delete(recursive: true);
      }
      await codeServerDir.create(recursive: true);
      
      // Download with progress
      final downloadResponse = await http.get(Uri.parse(downloadUrl));
      if (downloadResponse.statusCode != 200) {
        throw Exception('Failed to download code-server: ${downloadResponse.statusCode}');
      }
      
      onProgress?.call('📦 Extracting code-server...');
      
      // Extract archive
      final archivePath = path.join(_codeServerPath, assetName);
      await File(archivePath).writeAsBytes(downloadResponse.bodyBytes);
      
      if (extension == '.zip') {
        // Extract ZIP
        final archive = ZipDecoder().decodeBytes(downloadResponse.bodyBytes);
        for (final file in archive) {
          final filePath = path.join(_codeServerPath, file.name);
          if (file.isFile) {
            final outFile = File(filePath);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          } else {
            await Directory(filePath).create(recursive: true);
          }
        }
      } else {
        // Extract TAR.GZ
        final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(downloadResponse.bodyBytes));
        for (final file in archive) {
          final filePath = path.join(_codeServerPath, file.name);
          if (file.isFile) {
            final outFile = File(filePath);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          } else {
            await Directory(filePath).create(recursive: true);
          }
        }
      }
      
      // Clean up archive file
      await File(archivePath).delete();
      
      // Make binary executable on Unix
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', binaryPath]);
      }
      
      onProgress?.call('✅ code-server installed successfully');
    } catch (e) {
      onProgress?.call('❌ Failed to install code-server: $e');
      onProgress?.call('💡 You can install manually: curl -fsSL https://code-server.dev/install.sh | sh');
      rethrow;
    }
  }
  
  /// Install dcf-vscode (custom extensions or custom code-server build)
  /// 
  /// Architecture options:
  /// 1. If dcf-vscode provides custom extensions → download extensions only
  /// 2. If dcf-vscode provides custom code-server build → download that binary
  /// 3. If dcf-vscode provides VS Code fork → would need custom code-server build
  static Future<void> _installDcfVscode({void Function(String)? onProgress, bool forceUpdate = false}) async {
    final dcfVscodeDir = Directory(_dcfVscodePath);
    
    // Check if already installed
    if (await dcfVscodeDir.exists() && !forceUpdate) {
      onProgress?.call('✅ dcf-vscode already installed');
      onProgress?.call('💡 To update, use: dcf ide --update');
      return;
    }
    
    onProgress?.call('📥 Checking for dcf-vscode releases...');
    
    try {
      // Check for GitHub releases
      final releasesResponse = await http.get(Uri.parse(_dcfVscodeReleasesUrl));
      
      if (releasesResponse.statusCode == 200) {
        final releaseData = jsonDecode(releasesResponse.body) as Map<String, dynamic>;
        final assets = releaseData['assets'] as List;
        
        // Check what type of release it is:
        // 1. Custom code-server binary (code-server-*.tar.gz or code-server-*.zip)
        // 2. VS Code fork binary (code-*.tar.gz or code-*.zip) 
        // 3. Extensions package (extensions-*.zip)
        
        bool foundCodeServer = false;
        bool foundVSCode = false;
        bool foundExtensions = false;
        
        for (final asset in assets) {
          final name = asset['name'] as String;
          if (name.contains('code-server')) {
            foundCodeServer = true;
            break;
          } else if (name.startsWith('code-') && (name.endsWith('.zip') || name.endsWith('.tar.gz'))) {
            foundVSCode = true;
            break;
          } else if (name.contains('extensions')) {
            foundExtensions = true;
            break;
          }
        }
        
        if (foundCodeServer) {
          // Custom code-server build - download and use instead of standard code-server
          onProgress?.call('🔧 Found custom code-server build in dcf-vscode');
          await _installCustomCodeServerFromRelease(assets, onProgress: onProgress, forceUpdate: forceUpdate);
        } else if (foundVSCode) {
          // VS Code fork binary - would need custom code-server, but for now just download
          onProgress?.call('📦 Found VS Code fork binary (requires custom code-server build)');
          await _installDcfVscodeFromRelease(onProgress: onProgress, forceUpdate: forceUpdate);
          onProgress?.call('⚠️  Note: VS Code fork requires custom code-server build to use');
        } else if (foundExtensions) {
          // Just extensions - download and extract to extensions folder
          onProgress?.call('📦 Found dcf-vscode extensions package');
          await _installDcfVscodeExtensions(assets, onProgress: onProgress, forceUpdate: forceUpdate);
        } else {
          // Unknown format - try standard VS Code format
          onProgress?.call('📦 Trying standard VS Code release format...');
          await _installDcfVscodeFromRelease(onProgress: onProgress, forceUpdate: forceUpdate);
        }
      } else if (releasesResponse.statusCode == 404) {
        // No releases - code-server works standalone
        onProgress?.call('⚠️  No dcf-vscode releases found');
        onProgress?.call('💡 code-server will work standalone');
        onProgress?.call('💡 dcf-vscode is optional');
        
        if (!await dcfVscodeDir.exists()) {
          await dcfVscodeDir.create(recursive: true);
        }
      } else {
        throw Exception('Failed to check dcf-vscode releases: ${releasesResponse.statusCode}');
      }
    } catch (e) {
      onProgress?.call('⚠️  Could not install dcf-vscode: $e');
      onProgress?.call('💡 code-server will work standalone');
      
      if (!await dcfVscodeDir.exists()) {
        await dcfVscodeDir.create(recursive: true);
      }
    }
  }
  
  /// Install custom code-server build from dcf-vscode release
  /// This replaces the standard code-server with your custom build
  static Future<void> _installCustomCodeServerFromRelease(
    List assets, {
    void Function(String)? onProgress,
    bool forceUpdate = false,
  }) async {
    final codeServerDir = Directory(_codeServerPath);
    
    onProgress?.call('🔧 Installing custom code-server from dcf-vscode...');
    
    // Determine platform and architecture
    String platform;
    String arch;
    String extension = '.tar.gz';
    
    if (Platform.isWindows) {
      platform = 'windows';
      arch = Platform.environment['PROCESSOR_ARCHITECTURE']?.contains('64') == true ? 'x64' : 'x86';
      extension = '.zip';
    } else if (Platform.isMacOS) {
      platform = 'macos';
      final result = await Process.run('uname', ['-m']);
      arch = result.stdout.toString().trim() == 'arm64' ? 'arm64' : 'x64';
    } else if (Platform.isLinux) {
      platform = 'linux';
      final result = await Process.run('uname', ['-m']);
      final unameArch = result.stdout.toString().trim();
      arch = unameArch.contains('aarch64') || unameArch.contains('arm64') ? 'arm64' : 'x64';
    } else {
      throw Exception('Unsupported platform: ${Platform.operatingSystem}');
    }
    
    // Find matching asset (code-server-*-platform-arch.tar.gz or .zip)
    String? downloadUrl;
    String? assetName;
    
    for (final asset in assets) {
      final name = asset['name'] as String;
      if (name.contains('code-server') && 
          (name.contains(platform) || name.contains('darwin') && platform == 'macos') &&
          name.contains(arch) && 
          name.endsWith(extension)) {
        downloadUrl = asset['browser_download_url'] as String;
        assetName = name;
        break;
      }
    }
    
    // Also try without platform name (just arch)
    if (downloadUrl == null) {
      for (final asset in assets) {
        final name = asset['name'] as String;
        if (name.contains('code-server') && 
            name.contains(arch) && 
            name.endsWith(extension)) {
          downloadUrl = asset['browser_download_url'] as String;
          assetName = name;
          break;
        }
      }
    }
    
    if (downloadUrl == null || assetName == null) {
      throw Exception('No matching custom code-server found for $platform/$arch');
    }
    
    onProgress?.call('📥 Downloading custom code-server ($assetName)...');
    
    // Remove old installation
    if (await codeServerDir.exists()) {
      await codeServerDir.delete(recursive: true);
    }
    await codeServerDir.create(recursive: true);
    
    // Download
    final downloadResponse = await http.get(Uri.parse(downloadUrl));
    if (downloadResponse.statusCode != 200) {
      throw Exception('Failed to download custom code-server: ${downloadResponse.statusCode}');
    }
    
    onProgress?.call('📦 Extracting custom code-server...');
    
    // Extract archive (same logic as standard code-server)
    final archivePath = path.join(_codeServerPath, assetName);
    await File(archivePath).writeAsBytes(downloadResponse.bodyBytes);
    
    if (extension == '.zip') {
      final archive = ZipDecoder().decodeBytes(downloadResponse.bodyBytes);
      for (final file in archive) {
        final filePath = path.join(_codeServerPath, file.name);
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }
    } else {
      final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(downloadResponse.bodyBytes));
      for (final file in archive) {
        final filePath = path.join(_codeServerPath, file.name);
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }
    }
    
    // Clean up archive
    await File(archivePath).delete();
    
    // Make binary executable
    final binaryPath = await _findCodeServerBinary();
    if (binaryPath != null && !Platform.isWindows) {
      await Process.run('chmod', ['+x', binaryPath]);
    }
    
    onProgress?.call('✅ Custom code-server installed successfully');
  }
  
  /// Install dcf-vscode extensions only
  static Future<void> _installDcfVscodeExtensions(
    List assets, {
    void Function(String)? onProgress,
    bool forceUpdate = false,
  }) async {
    final extensionsDir = path.join(_dcfVscodePath, 'extensions');
    
    // Find extensions asset
    String? downloadUrl;
    String? assetName;
    
    for (final asset in assets) {
      final name = asset['name'] as String;
      if (name.contains('extensions') && (name.endsWith('.zip') || name.endsWith('.tar.gz'))) {
        downloadUrl = asset['browser_download_url'] as String;
        assetName = name;
        break;
      }
    }
    
    if (downloadUrl == null) {
      throw Exception('No extensions package found in release');
    }
    
    onProgress?.call('📥 Downloading dcf-vscode extensions...');
    
    final downloadResponse = await http.get(Uri.parse(downloadUrl));
    if (downloadResponse.statusCode != 200) {
      throw Exception('Failed to download extensions: ${downloadResponse.statusCode}');
    }
    
    // Extract to extensions directory
    await Directory(extensionsDir).create(recursive: true);
    
    if (assetName!.endsWith('.zip')) {
      final archive = ZipDecoder().decodeBytes(downloadResponse.bodyBytes);
      for (final file in archive) {
        final filePath = path.join(extensionsDir, file.name);
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }
    } else {
      final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(downloadResponse.bodyBytes));
      for (final file in archive) {
        final filePath = path.join(extensionsDir, file.name);
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }
    }
    
    onProgress?.call('✅ dcf-vscode extensions installed');
  }
  
  /// Install dcf-vscode from GitHub release (built binary)
  static Future<void> _installDcfVscodeFromRelease({void Function(String)? onProgress, bool forceUpdate = false}) async {
    final dcfVscodeDir = Directory(_dcfVscodePath);
    
    onProgress?.call('📥 Fetching latest dcf-vscode release...');
    
    // Get latest release info
    final response = await http.get(Uri.parse(_dcfVscodeReleasesUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch dcf-vscode releases: ${response.statusCode}');
    }
    
    final releaseData = jsonDecode(response.body) as Map<String, dynamic>;
    final version = releaseData['tag_name'] as String;
    final assets = releaseData['assets'] as List;
    
    onProgress?.call('📦 Found dcf-vscode version: $version');
    
    // Determine platform and architecture
    String platform;
    String arch;
    String extension = '.tar.gz';
    
    if (Platform.isWindows) {
      platform = 'win32';
      arch = Platform.environment['PROCESSOR_ARCHITECTURE']?.contains('64') == true ? 'x64' : 'ia32';
      extension = '.zip';
    } else if (Platform.isMacOS) {
      platform = 'darwin';
      final result = await Process.run('uname', ['-m']);
      arch = result.stdout.toString().trim() == 'arm64' ? 'arm64' : 'x64';
      extension = '.zip';
    } else if (Platform.isLinux) {
      platform = 'linux';
      final result = await Process.run('uname', ['-m']);
      final unameArch = result.stdout.toString().trim();
      arch = unameArch.contains('aarch64') || unameArch.contains('arm64') ? 'arm64' : 'x64';
      extension = '.tar.gz';
    } else {
      throw Exception('Unsupported platform: ${Platform.operatingSystem}');
    }
    
    // Find matching asset (VS Code releases use format like: code-1.80.0-darwin-x64.zip)
    String? downloadUrl;
    String? assetName;
    
    for (final asset in assets) {
      final name = asset['name'] as String;
      // VS Code format: code-VERSION-PLATFORM-ARCH.zip or .tar.gz
      if (name.contains(platform) && name.contains(arch) && name.endsWith(extension)) {
        downloadUrl = asset['browser_download_url'] as String;
        assetName = name;
        break;
      }
    }
    
    if (downloadUrl == null || assetName == null) {
      throw Exception('No matching dcf-vscode release found for $platform/$arch');
    }
    
    onProgress?.call('📥 Downloading dcf-vscode ($assetName)...');
    
    // Remove old installation if updating
    if (await dcfVscodeDir.exists()) {
      await dcfVscodeDir.delete(recursive: true);
    }
    await dcfVscodeDir.create(recursive: true);
    
    // Download with progress
    final downloadResponse = await http.get(Uri.parse(downloadUrl));
    if (downloadResponse.statusCode != 200) {
      throw Exception('Failed to download dcf-vscode: ${downloadResponse.statusCode}');
    }
    
    onProgress?.call('📦 Extracting dcf-vscode...');
    
    // Extract archive
    final archivePath = path.join(_dcfVscodePath, assetName);
    await File(archivePath).writeAsBytes(downloadResponse.bodyBytes);
    
    if (extension == '.zip') {
      // Extract ZIP
      final archive = ZipDecoder().decodeBytes(downloadResponse.bodyBytes);
      for (final file in archive) {
        final filePath = path.join(_dcfVscodePath, file.name);
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }
    } else {
      // Extract TAR.GZ
      final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(downloadResponse.bodyBytes));
      for (final file in archive) {
        final filePath = path.join(_dcfVscodePath, file.name);
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }
    }
    
    // Clean up archive file
    await File(archivePath).delete();
    
    onProgress?.call('✅ dcf-vscode installed successfully');
  }
  
  /// Update IDE components
  static Future<void> updateIDE({void Function(String)? onProgress}) async {
    onProgress?.call('🔄 Updating IDE components...');
    await installIDE(onProgress: onProgress, forceUpdate: true);
  }
  
  /// Find code-server binary (may be in subdirectory after extraction)
  static Future<String?> _findCodeServerBinary() async {
    final codeServerDir = Directory(_codeServerPath);
    if (!await codeServerDir.exists()) {
      return null;
    }
    
    final binaryName = Platform.isWindows ? 'code-server.exe' : 'code-server';
    
    // Check root directory first
    final rootBinary = path.join(_codeServerPath, binaryName);
    if (await File(rootBinary).exists()) {
      return rootBinary;
    }
    
    // Search in subdirectories (code-server extracts to a versioned folder)
    try {
      await for (final entity in codeServerDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith(binaryName)) {
          return entity.path;
        }
      }
    } catch (e) {
      // Directory listing failed
    }
    
    return null;
  }
  
  /// Launch IDE in browser
  static Future<void> launchIDE(String projectPath, {int port = 8080}) async {
    if (!await isIDEInstalled()) {
      throw Exception('IDE is not installed. Run installIDE() first.');
    }
    
    // Find code-server binary (may be in subdirectory)
    final codeServerBinary = await _findCodeServerBinary();
    if (codeServerBinary == null) {
      throw Exception('code-server binary not found. Expected at: ${path.join(_codeServerPath, Platform.isWindows ? "code-server.exe" : "code-server")}');
    }
    
    // Make sure binary is executable
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['+x', codeServerBinary]);
      } catch (e) {
        // Ignore chmod errors
      }
    }
    
    // Start code-server
    // If dcf-vscode is installed, we can use its extensions, but code-server works standalone
    final args = [
      '--bind-addr', '0.0.0.0:$port',
      '--auth', 'none', // For development, in production use proper auth
      '--open', // Open browser automatically
      projectPath,
    ];
    
    // Optionally add extensions directory if dcf-vscode is installed
    final dcfVscodeExtensions = path.join(_dcfVscodePath, 'extensions');
    if (await Directory(dcfVscodeExtensions).exists()) {
      args.insert(args.length - 1, '--extensions-dir');
      args.insert(args.length - 1, dcfVscodeExtensions);
    }
    
    try {
      // Start code-server process (detached, don't wait for it)
      final process = await Process.start(
        codeServerBinary,
        args,
        mode: ProcessStartMode.normal, // Changed to normal to catch errors
      );
      
      // Wait a moment and check if process is still running
      await Future.delayed(Duration(seconds: 1));
      
      // Check if process died immediately (error)
      try {
        final exitCode = await process.exitCode.timeout(Duration(milliseconds: 100));
        // If we got here, process died = error
        final stderr = await process.stderr.transform(utf8.decoder).join();
        throw Exception('code-server failed to start (exit code: $exitCode). Error: ${stderr.isEmpty ? "Unknown error" : stderr}');
      } catch (e) {
        if (e is TimeoutException) {
          // Timeout means process is still running = success
          // Process is running, continue
        } else {
          rethrow;
        }
      }
      
      // Wait a bit more for server to fully start
      await Future.delayed(Duration(seconds: 2));
      
      // Open browser
      final url = 'http://localhost:$port';
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('start', [url], runInShell: true);
      }
      
      print('✅ IDE launched at: $url');
    } catch (e) {
      throw Exception('Failed to launch IDE: $e');
    }
  }
  
  /// Get code-server binary path
  static String? getCodeServerPath() {
    String codeServerBinary;
    if (Platform.isWindows) {
      codeServerBinary = path.join(_codeServerPath, 'code-server.exe');
    } else {
      codeServerBinary = path.join(_codeServerPath, 'code-server');
    }
    
    if (File(codeServerBinary).existsSync()) {
      return codeServerBinary;
    }
    return null;
  }
}
