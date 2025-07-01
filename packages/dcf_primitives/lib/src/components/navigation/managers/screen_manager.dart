/// Screen manager for coordinating screen lifecycle
class DCFScreenManager {
  static final DCFScreenManager _instance = DCFScreenManager._();
  static DCFScreenManager get instance => _instance;

  DCFScreenManager._();

  /// Currently active screens by name
  final Map<String, bool> _activeScreens = {};

  /// Screen activation callbacks
  final Map<String, List<Function()>> _activationCallbacks = {};

  /// Register a screen as active
  void activateScreen(String screenName) {
    _activeScreens[screenName] = true;
    _notifyActivation(screenName);
  }

  /// Register a screen as inactive
  void deactivateScreen(String screenName) {
    _activeScreens[screenName] = false;
    _notifyDeactivation(screenName);
  }

  /// Check if a screen is active
  bool isScreenActive(String screenName) {
    return _activeScreens[screenName] ?? false;
  }

  /// Register callback for screen activation
  void onScreenActivated(String screenName, Function() callback) {
    _activationCallbacks.putIfAbsent(screenName, () => []).add(callback);
  }

  /// Remove activation callback
  void removeActivationCallback(String screenName, Function() callback) {
    _activationCallbacks[screenName]?.remove(callback);
  }

  void _notifyActivation(String screenName) {
    _activationCallbacks[screenName]?.forEach((callback) => callback());
  }

  void _notifyDeactivation(String screenName) {
    // Could add deactivation callbacks in the future
  }

  /// Get all active screens
  List<String> get activeScreens {
    return _activeScreens.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }
}
