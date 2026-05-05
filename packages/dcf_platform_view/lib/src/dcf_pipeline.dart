/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/widgets.dart';
import 'dcf_surface_manager.dart';
import 'dcf_platform_view_widget.dart';

/// View type for the single DCF surface. Plugin must register a factory for this.
const String kDCFSurfaceViewType = 'DCFSurface';

/// Root widget for the DCF pipeline. Owns the single platform view layer and
/// wraps the app in [DCFSurfaceScope].
class DCFPipeline extends StatefulWidget {
  const DCFPipeline({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<DCFPipeline> createState() => _DCFPipelineState();
}

class _DCFPipelineState extends State<DCFPipeline> {
  final DCFSurfaceManager _manager = DCFSurfaceManager.instance;
  double _frameX = 0, _frameY = 0, _frameW = 0, _frameH = 0;
  bool _hasFrame = false;

  @override
  void initState() {
    super.initState();
    _manager.setFrameCallback((x, y, w, h) {
      if (_frameX != x || _frameY != y || _frameW != w || _frameH != h) {
        setState(() {
          _frameX = x;
          _frameY = y;
          _frameW = w;
          _frameH = h;
          _hasFrame = w > 0 && h > 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DCFSurfaceScope(
      manager: _manager,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_hasFrame && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android))
            Positioned(
              left: _frameX,
              top: _frameY,
              width: _frameW,
              height: _frameH,
              child: _buildSinglePlatformView(),
            ),
        ],
      ),
    );
  }

  Widget _buildSinglePlatformView() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: kDCFSurfaceViewType,
        layoutDirection: TextDirection.ltr,
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: kDCFSurfaceViewType,
        layoutDirection: TextDirection.ltr,
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      );
    }
    return const SizedBox.expand();
  }
}
