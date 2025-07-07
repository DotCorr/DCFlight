/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:dcflight/dcflight.dart';

/// Example showing how to use the enhanced VDom with concurrent processing
void main() async {
  developer.log('🚀 DCFlight Concurrent VDom Example Started');

  // Create a mock platform interface
  final platformInterface = MockPlatformInterface();

  // Create VDom instance (now with concurrent processing built-in)
  final vdom = VDom(platformInterface);
  await vdom.isReady;

  developer.log('✅ VDom initialized with concurrent processing');

  // Check if concurrent processing is enabled
  final stats = vdom.getConcurrentStats();
  developer.log('📊 Concurrent Stats: $stats');

  // Create test components
  final components = await createTestComponents();

  // Register components
  for (final component in components) {
    vdom.registerComponent(component);
  }

  developer.log('📝 Registered ${components.length} components');

  // Test 1: Small batch (should use serial processing)
  developer.log('🔄 Testing small batch (serial processing)...');
  await performSmallBatch(components.take(3).toList());

  // Test 2: Large batch (should use concurrent processing)
  developer.log('🔄 Testing large batch (concurrent processing)...');
  await performLargeBatch(components);

  // Test 3: Mixed priority updates
  developer.log('🔄 Testing mixed priority updates...');
  await performMixedPriorityUpdates(components);

  // Show final statistics
  final finalStats = vdom.getConcurrentStats();
  developer.log('📈 Final Statistics:');
  developer
      .log('  - Concurrent Updates: ${finalStats['totalConcurrentUpdates']}');
  developer.log('  - Serial Updates: ${finalStats['totalSerialUpdates']}');
  developer
      .log('  - Concurrent Efficiency: ${finalStats['concurrentEfficiency']}%');
  developer
      .log('  - Optimal for Concurrent: ${vdom.isConcurrentProcessingOptimal}');

  // Cleanup
  await vdom.shutdownConcurrentProcessing();
  developer.log('🎯 Example completed successfully');
}

/// Create test components with different priorities
Future<List<TestComponent>> createTestComponents() async {
  final components = <TestComponent>[];

  // Create components with different priorities
  final priorities = [
    ComponentPriority.immediate,
    ComponentPriority.high,
    ComponentPriority.normal,
    ComponentPriority.low,
    ComponentPriority.idle,
  ];

  for (int i = 0; i < 10; i++) {
    final priority = priorities[i % priorities.length];
    final component = TestComponent(
      id: 'component_$i',
      priority: priority,
      initialValue: 'Initial value $i',
    );
    components.add(component);
  }

  return components;
}

/// Perform small batch update (should use serial processing)
Future<void> performSmallBatch(List<TestComponent> components) async {
  final startTime = DateTime.now();

  // Update all components
  for (final component in components) {
    component.updateValue(
        'Small batch update ${DateTime.now().millisecondsSinceEpoch}');
  }

  // Wait for processing
  await Future.delayed(Duration(milliseconds: 100));

  final endTime = DateTime.now();
  developer.log(
      '⏱️ Small batch completed in ${endTime.difference(startTime).inMilliseconds}ms');
}

/// Perform large batch update (should use concurrent processing)
Future<void> performLargeBatch(List<TestComponent> components) async {
  final startTime = DateTime.now();

  // Update all components
  for (final component in components) {
    component.updateValue(
        'Large batch update ${DateTime.now().millisecondsSinceEpoch}');
  }

  // Wait for processing
  await Future.delayed(Duration(milliseconds: 200));

  final endTime = DateTime.now();
  developer.log(
      '⏱️ Large batch completed in ${endTime.difference(startTime).inMilliseconds}ms');
}

/// Perform mixed priority updates
Future<void> performMixedPriorityUpdates(List<TestComponent> components) async {
  final startTime = DateTime.now();

  // Update components with different priorities at different times
  for (int i = 0; i < components.length; i++) {
    final component = components[i];
    component.updateValue('Priority update ${i}');

    // Stagger updates to test priority handling
    await Future.delayed(Duration(milliseconds: 5));
  }

  // Wait for processing
  await Future.delayed(Duration(milliseconds: 150));

  final endTime = DateTime.now();
  developer.log(
      '⏱️ Mixed priority updates completed in ${endTime.difference(startTime).inMilliseconds}ms');
}

/// Test component with configurable priority
class TestComponent extends StatefulComponent
    implements ComponentPriorityInterface {
  final String id;
  final ComponentPriority _priority;
  late final StateHook<String> _valueHook;

  TestComponent({
    required this.id,
    required ComponentPriority priority,
    required String initialValue,
  }) : _priority = priority;

  @override
  ComponentPriority get priority => _priority;

  @override
  DCFComponentNode render() {
    _valueHook = useState('Initial value');

    return DCFView(
      layout: LayoutProps(
        padding: 16,
        margin: 8,
        height: 80,
        width: 200,
      ),
      styleSheet: StyleSheet(
        backgroundColor: _getColorForPriority(_priority),
        borderRadius: 8,
      ),
      children: [
        DCFText(
          content: 'Component: $id',
          textProps: DCFTextProps(
            fontSize: 14,
            fontWeight: DCFFontWeight.bold,
            color: Colors.white,
          ),
        ),
        DCFText(
          content: 'Priority: ${_priority.name}',
          textProps: DCFTextProps(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
        DCFText(
          content: 'Value: ${_valueHook.state}',
          textProps: DCFTextProps(
            fontSize: 10,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void updateValue(String newValue) {
    _valueHook.setState(newValue);
  }

  Color _getColorForPriority(ComponentPriority priority) {
    switch (priority) {
      case ComponentPriority.immediate:
        return Colors.red;
      case ComponentPriority.high:
        return Colors.orange;
      case ComponentPriority.normal:
        return Colors.blue;
      case ComponentPriority.low:
        return Colors.green;
      case ComponentPriority.idle:
        return Colors.grey;
    }
  }
}

/// Mock platform interface for testing
class MockPlatformInterface implements PlatformInterface {
  @override
  Future<bool> initialize() async {
    await Future.delayed(Duration(milliseconds: 50));
    return true;
  }

  @override
  void setEventHandler(
      Function(String, String, Map<dynamic, dynamic>) handler) {
    // Mock implementation
  }

  @override
  Future<String> createView(String type, Map<String, dynamic> props,
      {String? parentId, int? index}) async {
    await Future.delayed(Duration(milliseconds: 1));
    return 'mock_view_${Random().nextInt(10000)}';
  }

  @override
  Future<void> updateView(String viewId, Map<String, dynamic> props) async {
    await Future.delayed(Duration(milliseconds: 1));
  }

  @override
  Future<void> deleteView(String viewId) async {
    await Future.delayed(Duration(milliseconds: 1));
  }

  @override
  Future<void> moveView(String viewId, String newParentId, int index) async {
    await Future.delayed(Duration(milliseconds: 1));
  }

  @override
  Future<void> startBatchUpdate() async {
    await Future.delayed(Duration(milliseconds: 2));
  }

  @override
  Future<void> commitBatchUpdate() async {
    await Future.delayed(Duration(milliseconds: 3));
  }

  @override
  Future<void> cancelBatchUpdate() async {
    await Future.delayed(Duration(milliseconds: 1));
  }
}
