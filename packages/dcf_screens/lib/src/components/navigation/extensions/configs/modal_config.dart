import 'package:dcflight/dcflight.dart';
import 'package:equatable/equatable.dart';

/// Configuration for modal presentation
class DCFModalConfig extends Equatable {
  /// List of available detents (standard enum values)
  final List<DCFModalDetent>? detents;

  /// Initially selected detent index
  final int? selectedDetentIndex;

  /// Whether to show the drag indicator (grabber)
  final bool showDragIndicator;

  /// Corner radius for the modal
  final double? cornerRadius;

  /// Whether the modal can be dismissed
  final bool isDismissible;

  /// Whether tapping outside dismisses the modal
  final bool allowsBackgroundDismiss;

  /// Transition style for the modal
  final String? transitionStyle;

  const DCFModalConfig({
    this.detents,
    this.selectedDetentIndex,
    this.showDragIndicator = true,
    this.cornerRadius,
    this.isDismissible = true,
    this.allowsBackgroundDismiss = true,
    this.transitionStyle,
  });

  /// Create modal config with standard detents
  factory DCFModalConfig.withDetents({
    required List<DCFModalDetent> detents,
    int? selectedDetentIndex,
    bool showDragIndicator = true,
    double? cornerRadius,
    bool isDismissible = true,
    bool allowsBackgroundDismiss = true,
    String? transitionStyle,
  }) {
    return DCFModalConfig(
      detents: detents,
      selectedDetentIndex: selectedDetentIndex,
      showDragIndicator: showDragIndicator,
      cornerRadius: cornerRadius,
      isDismissible: isDismissible,
      allowsBackgroundDismiss: allowsBackgroundDismiss,
      transitionStyle: transitionStyle,
    );
  }

  /// Create modal config with custom height detents
  factory DCFModalConfig.withCustomDetents({
    int? selectedDetentIndex,
    bool showDragIndicator = true,
    double? cornerRadius,
    bool isDismissible = true,
    bool allowsBackgroundDismiss = true,
    String? transitionStyle,
  }) {
    return DCFModalConfig(
      selectedDetentIndex: selectedDetentIndex,
      showDragIndicator: showDragIndicator,
      cornerRadius: cornerRadius,
      isDismissible: isDismissible,
      allowsBackgroundDismiss: allowsBackgroundDismiss,
      transitionStyle: transitionStyle,
    );
  }

  /// Create simple modal config (defaults to large detent)
  factory DCFModalConfig.simple({
    bool showDragIndicator = true,
    double? cornerRadius,
    bool isDismissible = true,
    bool allowsBackgroundDismiss = true,
  }) {
    return DCFModalConfig(
      detents: [
        DCFModalDetent.large
      ], // Default to large (full screen behavior)
      showDragIndicator: showDragIndicator,
      cornerRadius: cornerRadius,
      isDismissible: isDismissible,
      allowsBackgroundDismiss: allowsBackgroundDismiss,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (detents != null) 'detents': detents!.map((d) => d.name).toList(),
      if (selectedDetentIndex != null)
        'selectedDetentIndex': selectedDetentIndex,
      'showDragIndicator': showDragIndicator,
      if (cornerRadius != null) 'cornerRadius': cornerRadius,
      'isDismissible': isDismissible,
      'allowsBackgroundDismiss': allowsBackgroundDismiss,
      if (transitionStyle != null) 'transitionStyle': transitionStyle,
    };
  }

  @override
  List<Object?> get props => [
        detents,
        selectedDetentIndex,
        showDragIndicator,
        cornerRadius,
        isDismissible,
        allowsBackgroundDismiss,
        transitionStyle,
      ];
}


enum DCFModalPresentationStyle {
  pageSheet,
  fullScreen,
  overCurrentContext,
}

enum DCFModalDetent {
  /// Small detent - approximately 25% of screen height
  small,

  /// Medium detent - approximately 50% of screen height
  medium,

  /// Large detent - full available height (default)
  large,
}

