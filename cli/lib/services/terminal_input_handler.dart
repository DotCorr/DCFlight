// /*
//  * Copyright (c) Dotcorr Studio. and affiliates.
//  *
//  * This source code is licensed under the MIT license found in the
//  * LICENSE file in the root directory of this source tree.
//  */

// import 'dart:io';
// import 'dart:async';

// class TerminalInputHandler {
//   final Process dcfProcess;
//   final bool verbose;

//   StreamSubscription<List<int>>? _inputSubscription;

//   TerminalInputHandler({
//     required this.dcfProcess,
//     this.verbose = false,
//   });

//   Future<void> startForwarding() async {
//     try {
//       // Check if stdin is a terminal before trying to set echo mode
//       if (stdin.hasTerminal) {
//         // Enable raw mode for single character input
//         stdin.echoMode = false;
//         stdin.lineMode = false;

//         _inputSubscription = stdin.listen((List<int> data) {
//           _handleInput(data);
//         });

//         if (verbose) {
//           print('⌨️  Terminal input forwarding started');
//           print('   All commands forwarded to Flutter except "r" (hot reload)');
//         }
//       } else {
//         if (verbose) {
//           print('⌨️  Terminal input forwarding skipped (not a terminal)');
//         }
//       }

//     } catch (e) {
//       if (verbose) {
//         print('⚠️  Could not start terminal input forwarding: $e');
//       }
//       // Don't throw - this is not critical for hydration functionality
//     }
//   }

//   Future<void> stop() async {
//     try {
//       await _inputSubscription?.cancel();
//       _inputSubscription = null;

//       // Restore terminal mode only if we have a terminal
//       if (stdin.hasTerminal) {
//         stdin.echoMode = true;
//         stdin.lineMode = true;
//       }

//       if (verbose) {
//         print('⌨️  Terminal input forwarding stopped');
//       }
//     } catch (e) {
//       if (verbose) {
//         print('⚠️  Error stopping input forwarding: $e');
//       }
//       // Don't throw - this is cleanup
//     }
//   }

//   void _handleInput(List<int> data) {
//     if (data.isEmpty) return;

//     final char = String.fromCharCode(data[0]);

//     switch (char) {
//       case 'r':
//         // Hot reload is disabled in DCFlight - use restart instead
//         print('💡 Hot reload disabled - use R for hot restart');
//         print('   Press R to restart your DCFlight app');
//         break;

//       case 'h':
//         _showHelp();
//         break;

//       case 's':
//         _showStatus();
//         break;

//       default:
//         // Forward ALL other commands to Flutter (q, R, v, etc.)
//         _forwardToDCFlight(data);
//         break;
//     }
//   }

//   void _forwardToDCFlight(List<int> data) {
//     try {
//       dcfProcess.stdin.add(data);
//     } catch (e) {
//       if (verbose) {
//         print('❌ Failed to forward input to DCFlight runtime: $e');
//       }
//     }
//   }

//   void _showHelp() {
//     print('\n📖 DCFlight Development Commands:');
//     print('   q - Quit application');
//     print('   R - Hot restart (full app restart)');
//     print('   v - Open Flutter DevTools');
//     print('   r - Hot reload (disabled in DCFlight)');
//     print('   h - Show this help');
//     print('   s - Show development status');
//     print('   💡 All commands except "r" are forwarded to Flutter\n');
//   }

//   void _showStatus() {
//     print('\n📊 DCFlight Development Status:');
//     print('   🚀 DCFlight runtime: Running');
//     print('   📱 Platform: Ready');
//     print('   🔄 Hot restart: Available (press R)');
//     print('   💡 Make changes and restart to see updates\n');
//   }
// }
