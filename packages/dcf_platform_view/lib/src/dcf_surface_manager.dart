/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import 'surface_native_stub.dart'
    if (dart.library.io) 'surface_native_io.dart';

/// Rectangle in global (screen) coordinates.
class _SurfaceRect {
  final double x, y, width, height;
  const _SurfaceRect(this.x, this.y, this.width, this.height);
  bool get isValid => width > 0 && height > 0;
}

/// Manages the single DCF surface: collects rects from [DCFPlatformView] widgets,
/// computes union frame, and drives the one platform view via FFI (iOS) / FFI→JNI (Android).
class DCFSurfaceManager {
  DCFSurfaceManager._();
  static final DCFSurfaceManager instance = DCFSurfaceManager._();

  final Map<int, _SurfaceRect> _regions = {};
  int _nextId = 1;
  void Function(double x, double y, double width, double height)? _onFrameUpdate;

  /// Register a region (e.g. from a [DCFPlatformView]). Returns a region id.
  int registerRegion() {
    final id = _nextId++;
    _regions[id] = const _SurfaceRect(0, 0, 0, 0);
    return id;
  }

  /// Unregister a region.
  void unregisterRegion(int id) {
    _regions.remove(id);
    _updateUnion();
  }

  /// Update the rect for a region (in global coordinates).
  void updateRegion(int id, double x, double y, double width, double height) {
    _regions[id] = _SurfaceRect(x, y, width, height);
    _updateUnion();
  }

  void _updateUnion() {
    if (_regions.isEmpty) {
      _applyFrame(0, 0, 0, 0);
      return;
    }
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    for (final r in _regions.values) {
      if (!r.isValid) continue;
      if (r.x < minX) minX = r.x;
      if (r.y < minY) minY = r.y;
      final right = r.x + r.width;
      final bottom = r.y + r.height;
      if (right > maxX) maxX = right;
      if (bottom > maxY) maxY = bottom;
    }
    if (minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite) {
      final w = maxX - minX;
      final h = maxY - minY;
      if (w > 0 && h > 0) _applyFrame(minX, minY, w, h);
    }
  }

  void _applyFrame(double x, double y, double width, double height) {
    _onFrameUpdate?.call(x, y, width, height);
    setSurfaceFrameNative(x, y, width, height);
  }

  /// Called by the pipeline to set the callback for positioning the platform view layer.
  void setFrameCallback(void Function(double x, double y, double width, double height) cb) {
    _onFrameUpdate = cb;
    _updateUnion();
  }
}
