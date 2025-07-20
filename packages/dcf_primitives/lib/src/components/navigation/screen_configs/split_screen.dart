import 'package:dcflight/dcflight.dart';

enum DCFSplitViewDisplayMode {
  /// Automatically choose the best display mode
  automatic,

  /// Show master and detail side by side
  oneBesideSecondary,

  /// Show master as overlay on top of detail
  primaryOverlay,

  /// Show only the detail view (hide master)
  secondaryOnly,

  /// Hide the detail view (show only master)
  primaryHidden,
}

/// Enhanced split view configuration for 3-pane layouts
class DCFSplitViewConfig extends Equatable {
  /// Display mode for split view
  final DCFSplitViewDisplayMode displayMode;

  /// Primary column width (sidebar)
  final double? primaryColumnWidth;

  /// Supplementary column width (inspector) - 🎯 NEW!
  final double? supplementaryColumnWidth;

  /// Whether to show master side on iPhone
  final bool showMasterOnPhone;

  /// Whether to show inspector side on iPhone
  final bool showInspectorOnPhone;

  /// 🎯 SIDEBAR CONTENT (Left pane)
  final String? sidebarTitle;
  final List<DCFComponentNode>? sidebarChildren;

  /// 🎯 INSPECTOR CONTENT (Right pane)
  final String? inspectorTitle;
  final List<DCFComponentNode>? inspectorChildren;

  /// Whether to use 3-pane layout (sidebar + content + inspector)
  final bool useThreePaneLayout;

  const DCFSplitViewConfig({
    this.displayMode = DCFSplitViewDisplayMode.oneBesideSecondary,
    this.primaryColumnWidth,
    this.supplementaryColumnWidth,
    this.showMasterOnPhone = true,
    this.showInspectorOnPhone = false,
    this.sidebarTitle,
    this.sidebarChildren,
    this.inspectorTitle,
    this.inspectorChildren,
    this.useThreePaneLayout = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'displayMode': displayMode.name,
      if (primaryColumnWidth != null) 'primaryColumnWidth': primaryColumnWidth,
      if (supplementaryColumnWidth != null)
        'supplementaryColumnWidth': supplementaryColumnWidth,
      'showMasterOnPhone': showMasterOnPhone,
      'showInspectorOnPhone': showInspectorOnPhone,
      if (sidebarTitle != null) 'sidebarTitle': sidebarTitle,
      if (inspectorTitle != null) 'inspectorTitle': inspectorTitle,
      'useThreePaneLayout': useThreePaneLayout,
      'hasSidebarChildren':
          sidebarChildren != null && sidebarChildren!.isNotEmpty,
      'hasInspectorChildren':
          inspectorChildren != null && inspectorChildren!.isNotEmpty,
    };
  }

  @override
  List<Object?> get props => [
        displayMode,
        primaryColumnWidth,
        supplementaryColumnWidth,
        showMasterOnPhone,
        showInspectorOnPhone,
        sidebarTitle,
        sidebarChildren,
        inspectorTitle,
        inspectorChildren,
        useThreePaneLayout,
      ];
}
