/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// Type-safe command classes for TextInput imperative control
/// These commands are passed as props and trigger native text input actions without callbacks

/// Base class for all TextInput commands
abstract class TextInputCommand {
  const TextInputCommand();
  
  /// Convert command to a serializable map for native bridge
  Map<String, dynamic> toMap();
  
  /// Command type identifier for native side
  String get type;
}

/// Command to focus the text input (show keyboard)
class FocusTextInputCommand extends TextInputCommand {
  const FocusTextInputCommand();
  
  @override
  String get type => 'focus';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusTextInputCommand;
  }
  
  @override
  int get hashCode => type.hashCode;
  
  @override
  String toString() => 'FocusTextInputCommand()';
}

/// Command to blur the text input (hide keyboard)
class BlurTextInputCommand extends TextInputCommand {
  const BlurTextInputCommand();
  
  @override
  String get type => 'blur';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BlurTextInputCommand;
  }
  
  @override
  int get hashCode => type.hashCode;
  
  @override
  String toString() => 'BlurTextInputCommand()';
}

/// Command to clear the text input content
class ClearTextInputCommand extends TextInputCommand {
  const ClearTextInputCommand();
  
  @override
  String get type => 'clear';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClearTextInputCommand;
  }
  
  @override
  int get hashCode => type.hashCode;
  
  @override
  String toString() => 'ClearTextInputCommand()';
}

/// Command to select all text in the input
class SelectAllTextCommand extends TextInputCommand {
  const SelectAllTextCommand();
  
  @override
  String get type => 'selectAll';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectAllTextCommand;
  }
  
  @override
  int get hashCode => type.hashCode;
  
  @override
  String toString() => 'SelectAllTextCommand()';
}

/// Command to set text selection range
class SetSelectionCommand extends TextInputCommand {
  final int start;
  final int end;
  
  const SetSelectionCommand({
    required this.start,
    required this.end,
  });
  
  @override
  String get type => 'setSelection';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'start': start,
      'end': end,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SetSelectionCommand && 
           other.start == start &&
           other.end == end;
  }
  
  @override
  int get hashCode => Object.hash(start, end);
  
  @override
  String toString() => 'SetSelectionCommand(start: $start, end: $end)';
}

/// Command to scroll to a specific position in the text input
class TextInputScrollToPositionCommand extends TextInputCommand {
  final int position;
  final bool animated;
  
  const TextInputScrollToPositionCommand({
    required this.position,
    this.animated = true,
  });
  
  @override
  String get type => 'scrollToPosition';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'position': position,
      'animated': animated,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextInputScrollToPositionCommand && 
           other.position == position &&
           other.animated == animated;
  }
  
  @override
  int get hashCode => Object.hash(position, animated);
  
  @override
  String toString() => 'TextInputScrollToPositionCommand(position: $position, animated: $animated)';
}

/// Command to insert text at the current cursor position
class InsertTextCommand extends TextInputCommand {
  final String text;
  
  const InsertTextCommand({
    required this.text,
  });
  
  @override
  String get type => 'insertText';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'text': text,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InsertTextCommand && 
           other.text == text;
  }
  
  @override
  int get hashCode => text.hashCode;
  
  @override
  String toString() => 'InsertTextCommand(text: $text)';
}

/// Command to replace text in a specific range
class ReplaceTextCommand extends TextInputCommand {
  final int start;
  final int end;
  final String text;
  
  const ReplaceTextCommand({
    required this.start,
    required this.end,
    required this.text,
  });
  
  @override
  String get type => 'replaceText';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'start': start,
      'end': end,
      'text': text,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReplaceTextCommand && 
           other.start == start &&
           other.end == end &&
           other.text == text;
  }
  
  @override
  int get hashCode => Object.hash(start, end, text);
  
  @override
  String toString() => 'ReplaceTextCommand(start: $start, end: $end, text: $text)';
}
