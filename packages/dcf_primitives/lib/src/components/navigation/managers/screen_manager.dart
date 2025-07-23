class DCFScreenManager {
  static final DCFScreenManager _instance = DCFScreenManager._();
  static DCFScreenManager get instance => _instance;

  DCFScreenManager._();

  /// Currently active screens by name  
  final Map<String, ScreenState> _screenStates = {};

  /// Screen activation callbacks
  final Map<String, List<Function()>> _activationCallbacks = {};
  
  /// Screen rendering callbacks  
  final Map<String, List<Function(bool)>> _renderCallbacks = {};

  /// Performance metrics
  final Map<String, DateTime> _renderTimes = {};
  final Map<String, int> _renderCounts = {};

  /// Automatic screen activation
  void activateScreen(String screenName, {bool shouldRender = true}) {
    final currentState = _screenStates[screenName] ?? ScreenState();
    final newState = currentState.copyWith(
      isActive: true,
      shouldRender: shouldRender,
      lastActivated: DateTime.now(),
    );
    
    _screenStates[screenName] = newState;
    
    // Track performance
    _renderTimes[screenName] = DateTime.now();
    _renderCounts[screenName] = (_renderCounts[screenName] ?? 0) + 1;
    
    // Notify callbacks
    _notifyActivation(screenName);
    _notifyRenderChange(screenName, shouldRender);
  }

  /// Automatic screen deactivation
  void deactivateScreen(String screenName, {bool keepRendered = true}) {
    final currentState = _screenStates[screenName] ?? ScreenState();
    final newState = currentState.copyWith(
      isActive: false,
      shouldRender: keepRendered,
      lastDeactivated: DateTime.now(),
    );
    
    _screenStates[screenName] = newState;
    
    // Notify callbacks
    _notifyDeactivation(screenName);
    if (!keepRendered) {
      _notifyRenderChange(screenName, false);
    }
  }

  /// Trigger screen rendering
  void triggerScreenRender(String screenName) {
    final currentState = _screenStates[screenName] ?? ScreenState();
    final newState = currentState.copyWith(
      shouldRender: true,
      lastRendered: DateTime.now(),
    );
    
    _screenStates[screenName] = newState;
    _notifyRenderChange(screenName, true);
  }

  /// Cleanup screen rendering
  void cleanupScreenRender(String screenName) {
    final currentState = _screenStates[screenName] ?? ScreenState();
    final newState = currentState.copyWith(
      shouldRender: false,
      lastCleaned: DateTime.now(),
    );
    
    _screenStates[screenName] = newState;
    _notifyRenderChange(screenName, false);
  }

  /// Batch operations
  void batchScreenUpdates(Map<String, ScreenUpdateAction> updates) {
    for (final entry in updates.entries) {
      final screenName = entry.key;
      final action = entry.value;
      
      switch (action) {
        case ScreenUpdateAction.activate:
          activateScreen(screenName);
          break;
        case ScreenUpdateAction.deactivate:
          deactivateScreen(screenName);
          break;
        case ScreenUpdateAction.render:
          triggerScreenRender(screenName);
          break;
        case ScreenUpdateAction.cleanup:
          cleanupScreenRender(screenName);
          break;
      }
    }
  }

  /// Tab navigation support
  void switchTab(String newTabScreen, String? oldTabScreen) {
    final updates = <String, ScreenUpdateAction>{};
    
    // Deactivate old tab
    if (oldTabScreen != null) {
      updates[oldTabScreen] = ScreenUpdateAction.deactivate;
    }
    
    // Activate new tab
    updates[newTabScreen] = ScreenUpdateAction.activate;
    
    batchScreenUpdates(updates);
  }

  /// Memory optimization
  void performMemoryCleanup({Duration threshold = const Duration(minutes: 5)}) {
    final now = DateTime.now();
    final screensToCleanup = <String>[];
    
    for (final entry in _screenStates.entries) {
      final screenName = entry.key;
      final state = entry.value;
      
      // Skip active screens
      if (state.isActive) continue;
      
      // Skip recently used screens
      if (state.lastDeactivated != null && 
          now.difference(state.lastDeactivated!).inMinutes < threshold.inMinutes) {
        continue;
      }
      
      // Mark for cleanup if still rendered but unused
      if (state.shouldRender) {
        screensToCleanup.add(screenName);
      }
    }
    
    for (final screenName in screensToCleanup) {
      cleanupScreenRender(screenName);
    }
  }

  /// Check if a screen is active
  bool isScreenActive(String screenName) {
    return _screenStates[screenName]?.isActive ?? false;
  }

  /// Check if a screen should render
  bool shouldScreenRender(String screenName) {
    return _screenStates[screenName]?.shouldRender ?? false;
  }

  /// Get screen state
  ScreenState? getScreenState(String screenName) {
    return _screenStates[screenName];
  }

  /// Register callback for screen activation
  void onScreenActivated(String screenName, Function() callback) {
    _activationCallbacks.putIfAbsent(screenName, () => []).add(callback);
  }

  /// Register callback for render state changes
  void onScreenRenderChanged(String screenName, Function(bool shouldRender) callback) {
    _renderCallbacks.putIfAbsent(screenName, () => []).add(callback);
  }

  /// Remove activation callback
  void removeActivationCallback(String screenName, Function() callback) {
    _activationCallbacks[screenName]?.remove(callback);
  }

  /// Remove render callback
  void removeRenderCallback(String screenName, Function(bool) callback) {
    _renderCallbacks[screenName]?.remove(callback);
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'screenStates': _screenStates.map((k, v) => MapEntry(k, v.toMap())),
      'renderCounts': _renderCounts,
      'renderTimes': _renderTimes.map((k, v) => MapEntry(k, v.toIso8601String())),
    };
  }

  /// Get all active screens
  List<String> get activeScreens {
    return _screenStates.entries
        .where((entry) => entry.value.isActive)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get all rendered screens
  List<String> get renderedScreens {
    return _screenStates.entries
        .where((entry) => entry.value.shouldRender)
        .map((entry) => entry.key)
        .toList();
  }

  void _notifyActivation(String screenName) {
    _activationCallbacks[screenName]?.forEach((callback) => callback());
  }

  void _notifyDeactivation(String screenName) {
    // Future: Add deactivation callbacks if needed
  }

  void _notifyRenderChange(String screenName, bool shouldRender) {
    _renderCallbacks[screenName]?.forEach((callback) => callback(shouldRender));
  }
}

/// Screen state tracking
class ScreenState {
  final bool isActive;
  final bool shouldRender;
  final DateTime? lastActivated;
  final DateTime? lastDeactivated;
  final DateTime? lastRendered;
  final DateTime? lastCleaned;

  const ScreenState({
    this.isActive = false,
    this.shouldRender = false,
    this.lastActivated,
    this.lastDeactivated,
    this.lastRendered,
    this.lastCleaned,
  });

  ScreenState copyWith({
    bool? isActive,
    bool? shouldRender,
    DateTime? lastActivated,
    DateTime? lastDeactivated,
    DateTime? lastRendered,
    DateTime? lastCleaned,
  }) {
    return ScreenState(
      isActive: isActive ?? this.isActive,
      shouldRender: shouldRender ?? this.shouldRender,
      lastActivated: lastActivated ?? this.lastActivated,
      lastDeactivated: lastDeactivated ?? this.lastDeactivated,
      lastRendered: lastRendered ?? this.lastRendered,
      lastCleaned: lastCleaned ?? this.lastCleaned,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'shouldRender': shouldRender,
      'lastActivated': lastActivated?.toIso8601String(),
      'lastDeactivated': lastDeactivated?.toIso8601String(),
      'lastRendered': lastRendered?.toIso8601String(),
      'lastCleaned': lastCleaned?.toIso8601String(),
    };
  }
}

/// Screen update actions for batch operations
enum ScreenUpdateAction {
  activate,
  deactivate,
  render,
  cleanup,
}