/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';
import 'package:dcflight_cli/services/engine_resolver.dart';

/// `dcf setup`
///
/// Downloads and installs the flutter_zero SDK to ~/.dcflight/sdk/flutter_zero.
///
/// flutter_zero is a barebones Dart embedder that is tooling-compatible with
/// Flutter but uses a stripped engine (no widgets, no Skia) fetched from
/// https://github.com/DotCorr/flutter_zero. DCFlight users never need to install Flutter.
class SetupCommand extends Command<void> {
  static const String _zipUrl =
      'https://github.com/DotCorr/flutter_zero/archive/refs/heads/main.zip';

  @override
  String get name => 'setup';

  @override
  String get description =>
      'Install the flutter_zero SDK required to build and run DCFlight apps';

  SetupCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      defaultsTo: false,
      help: 'Re-install even if already installed',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      defaultsTo: false,
      help: 'Verbose output',
    );
  }

  @override
  Future<void> run() async {
    final force = argResults!['force'] as bool;
    final verbose = argResults!['verbose'] as bool;

    print('');
    print('  DCFlight Setup');
    print('  Installing flutter_zero SDK...');
    print('  (This is a lightweight Dart embedder — not the full Flutter SDK)');
    print('');

    if (EngineResolver.isInstalled && !force) {
      print('  flutter_zero is already installed at:');
      print('    ${EngineResolver.flutterZeroPath}');
      print('');
      print('  Use --force to re-install.');
      return;
    }

    final installDir = Directory(EngineResolver.sdkHome);
    final targetDir = Directory(EngineResolver.flutterZeroPath);

    // Remove existing install if force
    if (force && await targetDir.exists()) {
      if (verbose) print('  Removing existing installation...');
      await targetDir.delete(recursive: true);
    }

    await installDir.create(recursive: true);

    // Prefer git clone (fast, resumable), fall back to HTTP zip download
    final gitAvailable = await _isGitAvailable();

    if (gitAvailable) {
      await _installViaGit(targetDir.path, verbose: verbose);
    } else {
      await _installViaZip(installDir.path, verbose: verbose);
    }

    // Make binary executable
    if (!Platform.isWindows) {
      final binary =
          path.join(EngineResolver.flutterZeroPath, 'bin', 'flutter');
      await Process.run('chmod', ['+x', binary]);
      if (verbose) print('  Made binary executable: $binary');
    }

    // Run `flutter --version` to trigger initial SDK bootstrap.
    // We override FLUTTER_STORAGE_BASE_URL to Google's CDN — the DotCorr
    // flutter_zero fork uses the same tooling-compatible artifact layout.
    print('');
    print('  Bootstrapping flutter_zero (downloads engine artifacts)...');
    print('  This may take a few minutes on first run.');
    print('');

    final bootstrap = await Process.start(
      EngineResolver.flutterBinary,
      ['--version'],
      mode: ProcessStartMode.inheritStdio,
      environment: {
        ...Platform.environment,
        'FLUTTER_STORAGE_BASE_URL': EngineResolver.storageBaseUrl,
      },
    );
    final code = await bootstrap.exitCode;
    if (code != 0) {
      stderr.writeln('  Warning: flutter_zero bootstrap returned exit code $code');
    }

    print('');
    print('  flutter_zero installed at:');
    print('    ${EngineResolver.flutterZeroPath}');
    print('');
    print('  You can now run:');
    print('    dcf go          — run your DCFlight app with hot reload');
    print('    dcf create      — create a new DCFlight project');
    print('');
  }

  Future<bool> _isGitAvailable() async {
    try {
      final result = await Process.run('git', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _installViaGit(String targetPath, {required bool verbose}) async {
    print('  Installing via git (shallow clone)...');
    if (verbose) {
      print('  git clone --depth=1 https://github.com/DotCorr/flutter_zero $targetPath');
    }

    final process = await Process.start(
      'git',
      ['clone', '--depth=1', 'https://github.com/DotCorr/flutter_zero', targetPath],
      mode: ProcessStartMode.inheritStdio,
    );

    final code = await process.exitCode;
    if (code != 0) {
      throw Exception('git clone failed with exit code $code');
    }

    print('  flutter_zero cloned successfully.');
  }

  Future<void> _installViaZip(String installDir, {required bool verbose}) async {
    final zipFile = path.join(installDir, 'flutter_zero.zip');

    print('  git not found — downloading zip archive...');
    print('  Source: $_zipUrl');

    // Stream download with progress
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(_zipUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = File(zipFile).openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && verbose) {
          final pct = (received / total * 100).toStringAsFixed(0);
          stdout.write('\r  Downloading... $pct%');
        }
      }
      await sink.close();
      if (verbose) print('');
    } finally {
      client.close();
    }

    print('  Extracting...');
    final archive = ZipDecoder().decodeBuffer(InputFileStream(zipFile));

    for (final file in archive) {
      // GitHub zips have a top-level folder like flutter_zero-master/
      final filePath = path.join(
        installDir,
        file.name.replaceFirst(RegExp(r'^flutter_zero[^/]*/'), 'flutter_zero/'),
      );

      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }

    // Cleanup zip
    await File(zipFile).delete();
    print('  Extracted successfully.');
  }
}
