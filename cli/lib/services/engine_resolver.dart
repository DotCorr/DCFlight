/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'dart:io';
import 'package:path/path.dart' as path;

/// Resolves the flutter_zero binary path for DCFlight CLI.
///
/// DCFlight uses flutter_zero (github.com/DotCorr/flutter_zero) — a barebones
/// Dart embedder that is tooling-compatible with Flutter but has no widgets or
/// Skia dependency. Users only need the Dart SDK; they never install Flutter.
///
/// Resolution order:
///   1. DCFLIGHT_FLUTTER_PATH env var  (for DCFlight contributors with a local fork)
///   2. ~/.dcflight/sdk/flutter_zero/bin/flutter  (installed via `dcf setup`)
///   3. Throws [EngineNotInstalledException] with actionable message
class EngineResolver {
  static const String _envVar = 'DCFLIGHT_FLUTTER_PATH';
  static const String _repoName = 'flutter_zero';

  /// Engine artifact CDN. Overrides the URL baked into flutter_zero's bin/flutter
  /// script (which defaulted to the now-defunct engine.flutter0.dev).
  /// The DotCorr fork uses the same artifact layout as standard Flutter,
  /// so Google's CDN works as-is.
  static const String storageBaseUrl = 'https://storage.googleapis.com';

  /// The root directory where DCFlight stores its SDK and tools.
  static String get sdkHome {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/tmp';
    return path.join(home, '.dcflight', 'sdk');
  }

  /// The local path where flutter_zero is installed.
  static String get flutterZeroPath => path.join(sdkHome, _repoName);

  /// Returns true if the flutter_zero SDK is installed.
  static bool get isInstalled {
    try {
      flutterBinary;
      return true;
    } on EngineNotInstalledException {
      return false;
    }
  }

  /// Returns the absolute path to the flutter_zero binary.
  ///
  /// Throws [EngineNotInstalledException] if not found.
  static String get flutterBinary {
    // 1. Escape hatch for DCFlight contributors developing the framework itself.
    final envPath = Platform.environment[_envVar];
    if (envPath != null && envPath.isNotEmpty) {
      return envPath;
    }

    // 2. Installed via `dcf setup`.
    final binary = Platform.isWindows
        ? path.join(flutterZeroPath, 'bin', 'flutter.bat')
        : path.join(flutterZeroPath, 'bin', 'flutter');

    if (!File(binary).existsSync()) {
      throw EngineNotInstalledException();
    }

    return binary;
  }

  /// Ensures the binary is executable (no-op on Windows).
  static Future<void> ensureExecutable() async {
    if (Platform.isWindows) return;
    final binary = flutterBinary;
    await Process.run('chmod', ['+x', binary]);
  }

  /// Prints a clear message when the engine is missing, then exits.
  /// No-op if already installed.
  static void requireInstalled() {
    if (!isInstalled) {
      stderr.writeln('');
      stderr.writeln('  DCFlight SDK (flutter_zero) is not installed.');
      stderr.writeln('  Run:  dcf setup');
      stderr.writeln('');
      stderr.writeln('  flutter_zero is a lightweight Dart embedder used by DCFlight.');
      stderr.writeln('  It replaces the Flutter SDK — you do NOT need to install Flutter.');
      stderr.writeln('');
      exit(1);
    }
  }
}

class EngineNotInstalledException implements Exception {
  @override
  String toString() =>
      'DCFlight SDK not found. Run "dcf setup" to install the flutter_zero engine.';
}

