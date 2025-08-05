
import 'dart:math' as math;
import 'package:dcflight/dcflight.dart';
import 'package:dcflight/framework/renderer/engine/core/mutator/engine_mutator_extension_reg.dart';

/// Suspension-aware reconciliation handler for SuspensionView components
class SuspensionReconciliationHandler extends VDomReconciliationHandler {
  @override
  bool shouldHandle(DCFComponentNode oldNode, DCFComponentNode newNode) {
    // Handle if either node is a suspension container
    return (oldNode is DCFElement && oldNode.props['suspensionContainer'] == true) ||
           (newNode is DCFElement && newNode.props['suspensionContainer'] == true);
  }

  @override
  Future<void> reconcile(
    DCFComponentNode oldNode, 
    DCFComponentNode newNode,
    VDomReconciliationContext context,
  ) async {
    print("🎭 SuspensionReconciliation: Handling suspension container reconciliation");
    
    if (oldNode is! DCFElement || newNode is! DCFElement) {
      // Fallback to default reconciliation
      await context.defaultReconcile(oldNode, newNode);
      return;
    }
    
    final oldSuspended = oldNode.props['isSuspended'] as bool? ?? false;
    final newSuspended = newNode.props['isSuspended'] as bool? ?? false;
    final oldMode = oldNode.props['suspensionMode'] as String? ?? 'full';
    final newMode = newNode.props['suspensionMode'] as String? ?? 'full';
    
    // Check if suspension state changed
    if (oldSuspended != newSuspended || oldMode != newMode) {
      print("🎭 SuspensionReconciliation: Suspension state changed - $oldSuspended->$newSuspended, $oldMode->$newMode");
      
      // Handle suspension state transition
      if (oldNode.nativeViewId != null) {
        // Copy the native view ID
        newNode.nativeViewId = oldNode.nativeViewId;
        
        // Update suspension timestamp
        if (newSuspended && !oldSuspended) {
          newNode.props['suspendedSince'] = DateTime.now();
        } else if (!newSuspended && oldSuspended) {
          newNode.props.remove('suspendedSince');
        }
      }
    }
    
    // Handle children reconciliation based on suspension mode
    if (newSuspended) {
      await _reconcileSuspendedChildren(oldNode, newNode, context);
    } else {
      await _reconcileActiveChildren(oldNode, newNode, context);
    }
  }
  
  /// Reconcile children when suspended
  Future<void> _reconcileSuspendedChildren(
    DCFElement oldNode,
    DCFElement newNode,
    VDomReconciliationContext context,
  ) async {
    final mode = newNode.props['suspensionMode'] as String? ?? 'full';
    
    switch (mode) {
      case 'full':
        // In full suspension, only reconcile if pre-rendering is enabled
        final preRender = newNode.props['preRender'] as bool? ?? false;
        if (preRender) {
          await _reconcileChildrenNormally(oldNode, newNode, context);
        }
        break;
        
      case 'placeholder':
        // Only reconcile placeholder children
        await _reconcileChildrenNormally(oldNode, newNode, context);
        break;
        
      case 'background':
      case 'memory':
        // Reconcile all children (they exist but are hidden/in memory)
        await _reconcileChildrenNormally(oldNode, newNode, context);
        break;
    }
  }
  
  /// Reconcile children when active
  Future<void> _reconcileActiveChildren(
    DCFElement oldNode,
    DCFElement newNode,
    VDomReconciliationContext context,
  ) async {
    // Normal reconciliation for active state
    await _reconcileChildrenNormally(oldNode, newNode, context);
  }
  
  /// Helper to reconcile children normally
  Future<void> _reconcileChildrenNormally(
    DCFElement oldNode,
    DCFElement newNode,
    VDomReconciliationContext context,
  ) async {
    // Reconcile each child
    final commonLength = math.min(oldNode.children.length, newNode.children.length);
    
    for (int i = 0; i < commonLength; i++) {
      await context.defaultReconcile(oldNode.children[i], newNode.children[i]);
    }
    
    // Handle length differences
    if (newNode.children.length > oldNode.children.length) {
      // New children added - mount them
      for (int i = commonLength; i < newNode.children.length; i++) {
        context.mountNode(newNode.children[i]);
      }
    } else if (oldNode.children.length > newNode.children.length) {
      // Children removed - unmount them
      for (int i = commonLength; i < oldNode.children.length; i++) {
        context.unmountNode(oldNode.children[i]);
      }
    }
  }
}

/// Lifecycle interceptor for suspension views
class SuspensionLifecycleInterceptor extends VDomLifecycleInterceptor {
  @override
  void beforeMount(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is DCFElement && node.props['suspensionContainer'] == true) {
      final isSuspended = node.props['isSuspended'] as bool? ?? false;
      print("🎭 SuspensionLifecycle: Before mount - suspended: $isSuspended");
      
      if (isSuspended) {
        node.props['suspendedSince'] = DateTime.now();
      }
    }
  }

  @override
  void afterMount(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is DCFElement && node.props['suspensionContainer'] == true) {
      final isSuspended = node.props['isSuspended'] as bool? ?? false;
      final mode = node.props['suspensionMode'] as String? ?? 'full';
      print("🎭 SuspensionLifecycle: After mount - suspended: $isSuspended, mode: $mode");
    }
  }

  @override
  void beforeUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is DCFElement && node.props['suspensionContainer'] == true) {
      print("🎭 SuspensionLifecycle: Before update");
    }
  }

  @override
  void afterUpdate(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is DCFElement && node.props['suspensionContainer'] == true) {
      final isSuspended = node.props['isSuspended'] as bool? ?? false;
      print("🎭 SuspensionLifecycle: After update - suspended: $isSuspended");
    }
  }

  @override
  void beforeUnmount(DCFComponentNode node, VDomLifecycleContext context) {
    if (node is DCFElement && node.props['suspensionContainer'] == true) {
      print("🎭 SuspensionLifecycle: Before unmount - cleaning up suspension");
    }
  }
}

/// State change handler for suspension components
class SuspensionStateChangeHandler extends VDomStateChangeHandler {
  @override
  bool shouldHandle(StatefulComponent component, dynamic newState) {
    // Handle if this is a suspension-related component
    return component.runtimeType.toString().contains('Suspension');
  }

  @override
  void handleStateChange(
    StatefulComponent component, 
    dynamic oldState, 
    dynamic newState,
    VDomStateChangeContext context,
  ) {
    print("🎭 SuspensionStateChange: Handling state change for ${component.runtimeType}");
    
    // Check if this is a suspension state change that should be optimized
    if (newState is bool && oldState != newState) {
      // This might be a suspension state toggle
      print("🎭 SuspensionStateChange: Suspension state toggled: $oldState -> $newState");
      
      // For suspension state changes, we can do a partial update instead of full re-render
      context.partialUpdate(component);
    } else {
      // Normal state change - schedule regular update
      context.scheduleUpdate();
    }
  }
}

/// Initialize suspension support in VDOM
void initializeSuspensionSupport() {
  print("🎭 SuspensionSupport: Initializing VDOM suspension extensions");
  
  // Register custom reconciliation handler
  VDomExtensionRegistry.instance.registerReconciliationHandler<DCFElement>(
    SuspensionReconciliationHandler()
  );
  
  // Register lifecycle interceptor
  VDomExtensionRegistry.instance.registerLifecycleInterceptor<DCFElement>(
    SuspensionLifecycleInterceptor()
  );
  
  // Register state change handler for suspension components
  VDomExtensionRegistry.instance.registerStateChangeHandler<StatefulComponent>(
    SuspensionStateChangeHandler()
  );
  
  print("🎭 SuspensionSupport: All VDOM suspension extensions registered successfully");
}

/// Helper to check if a component should be suspended
bool shouldSuspendComponent(DCFComponentNode component, {
  required String screenName,
  String? reason,
}) {
  // Check various conditions for suspension
  
  // 1. Check if explicitly suspended via manager
  if (DCFSuspensionManager.isSuspended(screenName)) {
    return true;
  }
  
  // 2. Check component type for auto-suspension
  final typeName = component.runtimeType.toString().toLowerCase();
  if (typeName.contains('animation') || 
      typeName.contains('heavy') ||
      typeName.contains('video') ||
      typeName.contains('3d')) {
    print("🎭 Auto-suspending heavy component: ${component.runtimeType}");
    return true;
  }
  
  // 3. Check memory pressure (simplified)
  final stats = DCFSuspensionManager.getStats();
  if (stats['activeCount'] > 5) {
    print("🎭 Auto-suspending due to memory pressure");
    return true;
  }
  
  return false;
}

/// Smart suspension scheduler for background optimization
class SuspensionScheduler {
  static Timer? _optimizationTimer;
  
  /// Start background optimization
  static void startOptimization({Duration interval = const Duration(seconds: 30)}) {
    _optimizationTimer?.cancel();
    
    _optimizationTimer = Timer.periodic(interval, (timer) {
      _performOptimization();
    });
    
    print("🎭 SuspensionScheduler: Started optimization with ${interval.inSeconds}s interval");
  }
  
  /// Stop background optimization
  static void stopOptimization() {
    _optimizationTimer?.cancel();
    _optimizationTimer = null;
    print("🎭 SuspensionScheduler: Stopped optimization");
  }
  
  /// Perform optimization cycle
  static void _performOptimization() {
    final stats = DCFSuspensionManager.getStats();
    print("🎭 SuspensionScheduler: Optimization cycle - ${stats['suspendedCount']} suspended, ${stats['activeCount']} active");
    
    // Auto-suspend screens that haven't been used recently
    if (stats['activeCount'] > 3) {
      final activeScreens = stats['active'] as List<String>;
      if (activeScreens.isNotEmpty) {
        // In a real implementation, you'd track last usage time
        final screenToSuspend = activeScreens.last;
        DCFSuspensionManager.suspend(screenToSuspend, reason: "Auto-optimization");
      }
    }
  }
}

/// Extension methods for easier suspension integration
extension SuspensionViewExtensions on DCFElement {
  /// Check if this element is a suspension container
  bool get isSuspensionContainer => props['suspensionContainer'] == true;
  
  /// Check if this suspension container is suspended
  bool get isSuspended => props['isSuspended'] as bool? ?? false;
  
  /// Get the suspension mode
  String get suspensionMode => props['suspensionMode'] as String? ?? 'full';
  
  /// Get suspension duration if suspended
  Duration? get suspensionDuration {
    final startTime = props['suspendedSince'] as DateTime?;
    if (startTime != null && isSuspended) {
      return DateTime.now().difference(startTime);
    }
    return null;
  }
}

/// Suspension statistics tracker
class SuspensionStatsTracker {
  static final Map<String, SuspensionStats> _stats = {};
  
  /// Record suspension state change
  static void recordStateChange(String screenName, bool suspended, String mode) {
    final stats = _stats[screenName] ?? SuspensionStats(screenName);
    
    if (suspended) {
      stats.suspensionCount++;
      stats.lastSuspended = DateTime.now();
      stats.currentMode = mode;
    } else {
      stats.activationCount++;
      stats.lastActivated = DateTime.now();
      if (stats.lastSuspended != null) {
        final duration = DateTime.now().difference(stats.lastSuspended!);
        stats.totalSuspensionTime += duration;
      }
    }
    
    _stats[screenName] = stats;
  }
  
  /// Get statistics for all screens
  static Map<String, SuspensionStats> getAllStats() => Map.from(_stats);
  
  /// Get statistics for a specific screen
  static SuspensionStats? getStats(String screenName) => _stats[screenName];
  
  /// Clear all statistics
  static void clearStats() => _stats.clear();
  
  /// Print summary
  static void printSummary() {
    print("🎭 Suspension Statistics Summary:");
    for (final entry in _stats.entries) {
      final screenName = entry.key;
      final stats = entry.value;
      print("  $screenName: ${stats.suspensionCount} suspensions, ${stats.activationCount} activations");
      print("    Total suspension time: ${stats.totalSuspensionTime.inSeconds}s");
    }
  }
}

/// Statistics data class
class SuspensionStats {
  final String screenName;
  int suspensionCount = 0;
  int activationCount = 0;
  Duration totalSuspensionTime = Duration.zero;
  DateTime? lastSuspended;
  DateTime? lastActivated;
  String currentMode = 'full';
  
  SuspensionStats(this.screenName);
  
  Map<String, dynamic> toMap() {
    return {
      'screenName': screenName,
      'suspensionCount': suspensionCount,
      'activationCount': activationCount,
      'totalSuspensionTimeMs': totalSuspensionTime.inMilliseconds,
      'lastSuspended': lastSuspended?.toIso8601String(),
      'lastActivated': lastActivated?.toIso8601String(),
      'currentMode': currentMode,
    };
  }
}