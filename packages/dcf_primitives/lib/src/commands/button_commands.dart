/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Type-safe command classes for Button imperative control
/// These commands are passed as props and trigger native button actions without callbacks

/// Base class for all Button commands
abstract class ButtonCommand {
  const ButtonCommand();
  
  /// Convert command to a serializable map for native bridge
  Map<String, dynamic> toMap();
  
  /// Command type identifier for native side
  String get type;
}

/// Command to set the button's highlighted state
class SetHighlightedCommand extends ButtonCommand {
  final bool highlighted;
  
  const SetHighlightedCommand({
    required this.highlighted,
  });
  
  @override
  String get type => 'setHighlighted';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'highlighted': highlighted,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetHighlightedCommand && 
           other.highlighted == highlighted;
  }
  
  @override
  int get hashCode => highlighted.hashCode;
  
  @override
  String toString() => 'SetHighlightedCommand(highlighted: $highlighted)';
}

/// Command to programmatically trigger a button click
class PerformClickCommand extends ButtonCommand {
  const PerformClickCommand();
  
  @override
  String get type => 'performClick';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PerformClickCommand;
  }
  
  @override
  int get hashCode => type.hashCode;
  
  @override
  String toString() => 'PerformClickCommand()';
}

/// Command to set the button's enabled state
class SetEnabledCommand extends ButtonCommand {
  final bool enabled;
  
  const SetEnabledCommand({
    required this.enabled,
  });
  
  @override
  String get type => 'setEnabled';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'enabled': enabled,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetEnabledCommand && 
           other.enabled == enabled;
  }
  
  @override
  int get hashCode => enabled.hashCode;
  
  @override
  String toString() => 'SetEnabledCommand(enabled: $enabled)';
}

/// Command to update the button's title
class SetTitleCommand extends ButtonCommand {
  final String title;
  
  const SetTitleCommand({
    required this.title,
  });
  
  @override
  String get type => 'setTitle';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetTitleCommand && 
           other.title == title;
  }
  
  @override
  int get hashCode => title.hashCode;
  
  @override
  String toString() => 'SetTitleCommand(title: $title)';
}
