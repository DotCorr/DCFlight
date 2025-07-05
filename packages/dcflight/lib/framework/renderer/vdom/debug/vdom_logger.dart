// ignore_for_file: avoid_print

import 'package:dcflight/dcflight.dart';

class VDomDebugLogger {
  /// Toggle this to enable/disable all VDOM logging
  static bool enabled = false;
  
  static int _logId = 0;
  static final Map<String, int> _componentCounts = {};
  static final Map<String, List<String>> _reconcileHistory = {};
  
  /// Log any VDOM operation
  static void log(String operation, String details, {String? component, Map<String, dynamic>? extra}) {
    if (!enabled) return;
    
    final id = ++_logId;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    print('🔍 VDOM[$id] $operation @ $timestamp: $details');
    
    if (component != null) {
      print('  🧩 Component: $component');
    }
    
    if (extra != null) {
      extra.forEach((key, value) {
        print('  📋 $key: $value');
      });
    }
  }
  
  /// Log reconciliation decisions
  static void logReconcile(String decision, DCFComponentNode oldNode, DCFComponentNode newNode, {String? reason}) {
    if (!enabled) return;
    
    final oldDesc = _describeNode(oldNode);
    final newDesc = _describeNode(newNode);
    
    log('RECONCILE_$decision', reason ?? 'No reason provided', extra: {
      'OLD': oldDesc,
      'NEW': newDesc,
      'TypeMatch': oldNode.runtimeType == newNode.runtimeType,
      'KeyMatch': oldNode.key == newNode.key,
      'OldKey': oldNode.key ?? 'null',
      'NewKey': newNode.key ?? 'null',
    });
    
    // Track reconciliation history
    final type = newNode.runtimeType.toString();
    _reconcileHistory[type] = (_reconcileHistory[type] ?? [])..add(decision);
  }
  
  /// Log component mounting
  static void logMount(DCFComponentNode node, {String? context}) {
    if (!enabled) return;
    
    final type = node.runtimeType.toString();
    _componentCounts[type] = (_componentCounts[type] ?? 0) + 1;
    
    log('MOUNT', _describeNode(node), extra: {
      'Context': context ?? 'unknown',
      'MountCount': _componentCounts[type],
      'IsFirstMount': _componentCounts[type] == 1,
      'IsDuplicate': _componentCounts[type]! > 1,
    });
    
    if (_componentCounts[type]! > 1) {
      print('  ⚠️  DUPLICATE MOUNT: $type mounted ${_componentCounts[type]} times!');
    }
  }
  
  /// Log component unmounting
  static void logUnmount(DCFComponentNode node, {String? context}) {
    if (!enabled) return;
    
    log('UNMOUNT', _describeNode(node), extra: {
      'Context': context ?? 'unknown',
    });
  }
  
  /// Log render operations
  static void logRender(String phase, DCFComponentNode node, {String? viewId, String? parentId, String? error}) {
    if (!enabled) return;
    
    final extra = <String, dynamic>{
      'ViewId': viewId ?? 'unknown',
      'ParentId': parentId ?? 'unknown',
    };
    
    if (error != null) {
      extra['Error'] = error;
    }
    
    log('RENDER_$phase', _describeNode(node), extra: extra);
  }
  
  /// Log component updates
  static void logUpdate(DCFComponentNode component, String reason) {
    if (!enabled) return;
    
    log('UPDATE', _describeNode(component), extra: {
      'Reason': reason,
      'IsMounted': component is StatefulComponent ? component.isMounted : 
                   (component is StatelessComponent ? component.isMounted : 'N/A'),
    });
  }
  
  /// Log native bridge operations
  static void logBridge(String operation, String viewId, {Map<String, dynamic>? data}) {
    if (!enabled) return;
    
    log('BRIDGE_$operation', 'ViewId: $viewId', extra: data);
  }
  
  /// Describe a component node for logging
  static String _describeNode(DCFComponentNode node) {
    final type = node.runtimeType.toString();
    final key = node.key ?? 'null';
    final nativeId = node.effectiveNativeViewId ?? 'null';
    
    String desc = '$type(key:$key, id:$nativeId';
    
    if (node is DCFElement) {
      desc += ', elementType:${node.type}';
      
      // Log important props
      final props = <String>[];
      if (node.props.containsKey('selectedValue')) {
        props.add('selectedValue:${node.props['selectedValue']}');
      }
      if (node.props.containsKey('visible')) {
        props.add('visible:${node.props['visible']}');
      }
      if (props.isNotEmpty) {
        desc += ', ${props.join(', ')}';
      }
    }
    
    if (node is StatefulComponent) {
      desc += ', instanceId:${node.instanceId}';
    }
    
    desc += ')';
    return desc;
  }
  
  /// Print comprehensive statistics
  static void printStats() {
    if (!enabled) return;
    
    print('\n📊 VDOM DEBUG STATISTICS:');
    print('🆕 COMPONENT MOUNT COUNTS:');
    _componentCounts.forEach((type, count) {
      final status = count > 1 ? '⚠️  MULTIPLE' : '✅ SINGLE';
      print('  $status $type: $count mounts');
    });
    
    print('\n🔄 RECONCILIATION HISTORY:');
    _reconcileHistory.forEach((type, decisions) {
      print('  $type: ${decisions.join(' → ')}');
    });
    
    print('\n🔍 Total operations logged: $_logId\n');
  }
  
  /// Reset all statistics
  static void reset() {
    _logId = 0;
    _componentCounts.clear();
    _reconcileHistory.clear();
    print('🔄 VDOM Debug Logger reset');
  }
}