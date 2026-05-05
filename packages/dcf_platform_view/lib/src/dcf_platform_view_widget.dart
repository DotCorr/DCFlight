/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:flutter/widgets.dart';
import 'dcf_surface_manager.dart';

/// Scope that provides [DCFSurfaceManager] to [DCFPlatformView] widgets.
class DCFSurfaceScope extends InheritedWidget {
  const DCFSurfaceScope({
    super.key,
    required this.manager,
    required super.child,
  });

  final DCFSurfaceManager manager;

  static DCFSurfaceManager? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DCFSurfaceScope>()?.manager;
  }

  @override
  bool updateShouldNotify(DCFSurfaceScope oldWidget) =>
      manager != oldWidget.manager;
}

/// Placeholder widget that reserves layout and registers its rect (global coords)
/// with the single DCF surface. The actual native view is one shared platform view
/// driven by the pipeline, not N views.
class DCFPlatformView extends StatefulWidget {
  const DCFPlatformView({
    super.key,
    this.child,
  });

  /// Optional child to show in the placeholder (e.g. loading).
  final Widget? child;

  @override
  State<DCFPlatformView> createState() => _DCFPlatformViewState();
}

class _DCFPlatformViewState extends State<DCFPlatformView> {
  int? _regionId;
  final GlobalKey _placeholderKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final manager = DCFSurfaceScope.of(context);
    if (manager != null && _regionId == null) {
      _regionId = manager.registerRegion();
    }
  }

  @override
  void dispose() {
    if (_regionId != null) {
      DCFSurfaceManager.instance.unregisterRegion(_regionId!);
    }
    super.dispose();
  }

  void _reportRect() {
    if (_regionId == null) return;
    final manager = DCFSurfaceScope.of(context);
    if (manager == null) return;
    final obj = _placeholderKey.currentContext?.findRenderObject();
    final box = obj is RenderBox ? obj : null;
    if (box != null && box.hasSize) {
      final offset = box.localToGlobal(Offset.zero);
      manager.updateRegion(
        _regionId!,
        offset.dx,
        offset.dy,
        box.size.width,
        box.size.height,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomSingleChildLayout(
          key: _placeholderKey,
          delegate: _ReportRectDelegate(onLayout: _reportRect),
          child: widget.child ?? const SizedBox.expand(),
        );
      },
    );
  }
}

class _ReportRectDelegate extends SingleChildLayoutDelegate {
  _ReportRectDelegate({required this.onLayout});

  final VoidCallback onLayout;

  @override
  Size getSize(BoxConstraints constraints) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onLayout());
    return constraints.biggest;
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset.zero;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints;

  @override
  bool shouldRelayout(covariant SingleChildLayoutDelegate oldDelegate) => false;
}
