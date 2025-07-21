
import 'package:dcflight/dcflight.dart';
import 'package:equatable/equatable.dart';

/// Configuration for popover presentation
class DCFPopoverConfig extends Equatable {
  final String? title;
  final double? preferredWidth;
  final double? preferredHeight;
  final List<String>? permittedArrowDirections;
  final bool dismissOnOutsideTap;

  const DCFPopoverConfig({
    this.title,
    this.preferredWidth,
    this.preferredHeight,
    this.permittedArrowDirections,
    this.dismissOnOutsideTap = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      if (preferredWidth != null) 'preferredWidth': preferredWidth,
      if (preferredHeight != null) 'preferredHeight': preferredHeight,
      if (permittedArrowDirections != null)
        'permittedArrowDirections': permittedArrowDirections,
      'dismissOnOutsideTap': dismissOnOutsideTap,
    };
  }

  @override
  List<Object?> get props => [
        title,
        preferredWidth,
        preferredHeight,
        permittedArrowDirections,
        dismissOnOutsideTap,
      ];
}

/// Configuration for overlay presentation
class DCFOverlayConfig extends Equatable {
  final String? title;
  final Color? overlayBackgroundColor;
  final bool dismissOnTap;
  final double? animationDuration;
  final bool blocksInteraction;

  const DCFOverlayConfig({
    this.title,
    this.overlayBackgroundColor,
    this.dismissOnTap = true,
    this.animationDuration,
    this.blocksInteraction = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      if (overlayBackgroundColor != null)
        'overlayBackgroundColor':
            '#${overlayBackgroundColor!.value.toRadixString(16).padLeft(8, '0')}',
      'dismissOnTap': dismissOnTap,
      if (animationDuration != null) 'animationDuration': animationDuration,
      'blocksInteraction': blocksInteraction,
    };
  }

  @override
  List<Object?> get props => [
        title,
        overlayBackgroundColor,
        dismissOnTap,
        animationDuration,
        blocksInteraction,
      ];
}