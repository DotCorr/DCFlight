/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Type-safe command classes for GestureDetector imperative control
/// These commands are passed as props and trigger native gesture actions without callbacks

/// Base class for all GestureDetector commands
abstract class GestureDetectorCommand {
  const GestureDetectorCommand();
  
  /// Convert command to a serializable map for native bridge
  Map<String, dynamic> toMap();
  
  /// Command type identifier for native side
  String get type;
}

/// Command to enable gesture recognition
class EnableGesturesCommand extends GestureDetectorCommand {
  final List<String>? gestureTypes; // Specific gesture types to enable (optional)
  
  const EnableGesturesCommand({
    this.gestureTypes,
  });
  
  @override
  String get type => 'enableGestures';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (gestureTypes != null) 'gestureTypes': gestureTypes,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnableGesturesCommand && 
           other.gestureTypes == gestureTypes;
  }
  
  @override
  int get hashCode => gestureTypes.hashCode;
  
  @override
  String toString() => 'EnableGesturesCommand(gestureTypes: $gestureTypes)';
}

/// Command to disable gesture recognition
class DisableGesturesCommand extends GestureDetectorCommand {
  final List<String>? gestureTypes; // Specific gesture types to disable (optional)
  
  const DisableGesturesCommand({
    this.gestureTypes,
  });
  
  @override
  String get type => 'disableGestures';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (gestureTypes != null) 'gestureTypes': gestureTypes,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DisableGesturesCommand && 
           other.gestureTypes == gestureTypes;
  }
  
  @override
  int get hashCode => gestureTypes.hashCode;
  
  @override
  String toString() => 'DisableGesturesCommand(gestureTypes: $gestureTypes)';
}

/// Command to reset gesture state
class ResetGestureStateCommand extends GestureDetectorCommand {
  const ResetGestureStateCommand();
  
  @override
  String get type => 'resetGestureState';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResetGestureStateCommand;
  }
  
  @override
  int get hashCode => type.hashCode;
  
  @override
  String toString() => 'ResetGestureStateCommand()';
}

/// Command to set gesture recognition sensitivity
class SetGestureSensitivityCommand extends GestureDetectorCommand {
  final double sensitivity; // Sensitivity value (0.0 to 1.0)
  final String? gestureType; // Specific gesture type (optional)
  
  const SetGestureSensitivityCommand({
    required this.sensitivity,
    this.gestureType,
  });
  
  @override
  String get type => 'setGestureSensitivity';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'sensitivity': sensitivity,
      if (gestureType != null) 'gestureType': gestureType,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetGestureSensitivityCommand && 
           other.sensitivity == sensitivity &&
           other.gestureType == gestureType;
  }
  
  @override
  int get hashCode => Object.hash(sensitivity, gestureType);
  
  @override
  String toString() => 'SetGestureSensitivityCommand(sensitivity: $sensitivity, gestureType: $gestureType)';
}

/// Command to configure long press gesture
class ConfigureLongPressCommand extends GestureDetectorCommand {
  final double minimumPressDuration; // Duration in seconds
  final double allowableMovement; // Allowable movement in points
  
  const ConfigureLongPressCommand({
    required this.minimumPressDuration,
    this.allowableMovement = 10.0,
  });
  
  @override
  String get type => 'configureLongPress';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'minimumPressDuration': minimumPressDuration,
      'allowableMovement': allowableMovement,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfigureLongPressCommand && 
           other.minimumPressDuration == minimumPressDuration &&
           other.allowableMovement == allowableMovement;
  }
  
  @override
  int get hashCode => Object.hash(minimumPressDuration, allowableMovement);
  
  @override
  String toString() => 'ConfigureLongPressCommand(minimumPressDuration: $minimumPressDuration, allowableMovement: $allowableMovement)';
}
