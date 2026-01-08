#!/usr/bin/env dart
/*
 * Worklet Code Generation Script
 * 
 * This script writes all compiled worklets to native source files.
 * Run this before building native apps to include generated worklets.
 * 
 * Usage:
 *   dart scripts/generate_worklets.dart
 * 
 * Or add to your build process:
 *   flutter pub run scripts/generate_worklets.dart
 */

import 'dart:io';
import 'package:dcflight/framework/worklets/compiler/build_hook.dart';

void main() async {
  print('🚀 Generating worklet code for native platforms...');
  print('');
  
  try {
    await WorkletBuildHook.writeGeneratedCode();
    print('');
    print('✅ Worklet code generation complete!');
    print('');
    print('Next steps:');
    print('  1. Include generated files in your native build:');
    print('     - Android: android/src/main/kotlin/com/dotcorr/dcflight/worklets/GeneratedWorklets.kt');
    print('     - iOS: ios/Classes/Worklets/GeneratedWorklets.swift');
    print('  2. Rebuild your native app');
    print('');
  } catch (e) {
    print('');
    print('❌ Error generating worklet code: $e');
    exit(1);
  }
}

