import 'package:dcflight/dcflight.dart';
import 'package:equatable/equatable.dart';

class DCFDrawerConfig extends Equatable {
  final String? title;
  final double? drawerWidth;  // Width of the drawer (default: 280)
  final double? drawerHeight; // Height for top/bottom drawers
  final String direction;     // "left", "right", "top", "bottom"  
  final bool dismissOnTap;    // Whether tapping outside dismisses
  final Color? overlayColor;  // Background overlay color
  final double? animationDuration;

  const DCFDrawerConfig({
    this.title,
    this.drawerWidth = 280,  // Standard drawer width
    this.drawerHeight,
    this.direction = "left",
    this.dismissOnTap = true,
    this.overlayColor,
    this.animationDuration = 0.3,
  });

  Map<String, dynamic> toMap() {
    return {
      if (title != null) 'title': title,
      if (drawerWidth != null) 'drawerWidth': drawerWidth,
      if (drawerHeight != null) 'drawerHeight': drawerHeight,
      'direction': direction,
      'dismissOnTap': dismissOnTap,
      if (overlayColor != null)
        'overlayColor': '#${overlayColor!.value.toRadixString(16).padLeft(8, '0')}',
      if (animationDuration != null) 'animationDuration': animationDuration,
    };
  }

  @override
  List<Object?> get props => [
        title,
        drawerWidth,
        drawerHeight,
        direction,
        dismissOnTap,
        overlayColor,
        animationDuration,
      ];
}