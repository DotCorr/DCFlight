/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


import 'dart:io';
import 'dart:convert';

class DCFlightRunner {
  final List<String> additionalArgs;
  final bool verbose;
  
  DCFlightRunner({
    this.additionalArgs = const [],
    this.verbose = false,
  });

  Future<Process> start() async {
    try {
      // First, get available devices
      final deviceId = await _selectDevice();
      
      // Simple DCFlight run arguments
      final args = [
        'run',
        '-d', deviceId,
        ...additionalArgs,
      ];
      
      if (verbose) {
        print('🎯 Starting DCFlight app: ${args.join(' ')}');
      }
      
      // Start DCFlight runtime (powered by Flutter engine)
      final process = await Process.start(
        'flutter',
        args,
        mode: ProcessStartMode.inheritStdio,
      );
      
      if (verbose) {
        print('✅ DCFlight runtime started');
      }
      
      return process;
      
    } catch (e) {
      throw Exception('Failed to start DCFlight app: $e');
    }
  }
  
  Future<String> _selectDevice() async {
    try {
      if (verbose) {
        print('🔍 Getting available devices...');
      }
      
      // Get list of available devices
      final result = await Process.run('flutter', ['devices', '--machine']);
      
      if (result.exitCode != 0) {
        throw Exception('Failed to get devices: ${result.stderr}');
      }

      // Parse device list
      final devices = <Map<String, dynamic>>[];
      final jsonOutput = result.stdout.toString().trim();
      
      if (jsonOutput.isEmpty) {
        throw Exception('No devices found. Make sure you have iOS Simulator or Android emulator running.');
      }
      
      try {
        final deviceList = jsonDecode(jsonOutput) as List;
        for (final device in deviceList) {
          if (device is Map<String, dynamic>) {
            devices.add(device);
          }
        }
      } catch (e) {
        throw Exception('Failed to parse device list: $e');
      }
      
      if (devices.isEmpty) {
        throw Exception('No devices found. Make sure you have iOS Simulator or Android emulator running.');
      }
      
      // Display available devices
      print('\n📱 Available devices:');
      for (int i = 0; i < devices.length; i++) {
        final device = devices[i];
        final name = device['name'] ?? 'Unknown';
        final platform = device['targetPlatform'] ?? 'Unknown';
        final id = device['id'] ?? 'Unknown';
        final isEmulator = device['emulator'] == true;
        final status = !isEmulator ? '📱 Physical' : '🖥️  Simulator';
        
        print('  ${i + 1}. $name ($platform) - $status');
        if (verbose) {
          print('     ID: $id');
        }
      }
      
      // Get user selection
      stdout.write('\nSelect device (1-${devices.length}): ');
      final input = stdin.readLineSync();
      
      if (input == null || input.trim().isEmpty) {
        throw Exception('No device selected');
      }
      
      final selection = int.tryParse(input.trim());
      if (selection == null || selection < 1 || selection > devices.length) {
        throw Exception('Invalid selection. Please choose 1-${devices.length}');
      }
      
      final selectedDevice = devices[selection - 1];
      final deviceId = selectedDevice['id'] as String;
      final deviceName = selectedDevice['name'] as String;
      
      print('✅ Selected: $deviceName');
      return deviceId;
      
    } catch (e) {
      throw Exception('Device selection failed: $e');
    }
  }
}
