/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:ui' as ui;
import 'dart:typed_data';

/// Drawing command types
enum DrawingCommandType {
  // Transformations
  save,
  restore,
  translate,
  rotate,
  scale,
  skew,
  
  // Clipping
  clipRect,
  clipPath,
  clipRRect,
  
  // Drawing
  drawRect,
  drawCircle,
  drawOval,
  drawArc,
  drawPath,
  drawLine,
  drawImage,
  drawImageRect,
  drawImageNine,
  drawParagraph,
  drawPoints,
  drawRawPoints,
  drawVertices,
  drawAtlas,
  drawShadow,
  drawDRRect,
  drawRRect,
  drawColor,
  drawPaint,
}

/// Serialized drawing command
class DrawingCommand {
  final DrawingCommandType type;
  final Map<String, dynamic> params;
  
  DrawingCommand({
    required this.type,
    required this.params,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'params': params,
    };
  }
}

/// Command-recording canvas that intercepts all drawing operations
/// 
/// Records drawing commands instead of converting to pixels.
/// Commands are much smaller than pixel data and can be sent via bridge.
/// 
/// Later, these commands can be executed on native Skia directly via FFI.
class CommandCanvas {
  final List<DrawingCommand> commands = [];
  final ui.Canvas realCanvas;  // Real canvas for validation/fallback
  
  CommandCanvas(this.realCanvas);
  
  // Transformations
  void save() {
    commands.add(DrawingCommand(type: DrawingCommandType.save, params: {}));
    realCanvas.save();
  }
  
  void saveLayer(ui.Rect? bounds, ui.Paint paint) {
    // Save layer is complex - for now, just save
    save();
  }
  
  void restore() {
    commands.add(DrawingCommand(type: DrawingCommandType.restore, params: {}));
    realCanvas.restore();
  }
  
  void translate(double dx, double dy) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.translate,
      params: {'dx': dx, 'dy': dy},
    ));
    realCanvas.translate(dx, dy);
  }
  
  void rotate(double radians) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.rotate,
      params: {'radians': radians},
    ));
    realCanvas.rotate(radians);
  }
  
  void scale(double sx, [double? sy]) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.scale,
      params: {'sx': sx, 'sy': sy ?? sx},
    ));
    realCanvas.scale(sx, sy);
  }
  
  void skew(double sx, double sy) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.skew,
      params: {'sx': sx, 'sy': sy},
    ));
    realCanvas.skew(sx, sy);
  }
  
  void transform(Float64List matrix4) {
    // Transform is complex - record as matrix
    commands.add(DrawingCommand(
      type: DrawingCommandType.scale,  // Use scale as placeholder
      params: {'matrix': matrix4.toList()},
    ));
    realCanvas.transform(matrix4);
  }
  
  // Clipping
  void clipRect(ui.Rect rect, {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.clipRect,
      params: {
        'rect': [rect.left, rect.top, rect.right, rect.bottom],
        'clipOp': clipOp.index,
        'doAntiAlias': doAntiAlias,
      },
    ));
    realCanvas.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  }
  
  void clipPath(ui.Path path, {bool doAntiAlias = true}) {
    // Serialize path bounds and approximate representation
    final bounds = path.getBounds();
    commands.add(DrawingCommand(
      type: DrawingCommandType.clipPath,
      params: {
        'bounds': [bounds.left, bounds.top, bounds.right, bounds.bottom],
        'doAntiAlias': doAntiAlias,
        // Note: Full path serialization would require parsing path commands
        // For now, we record bounds - native side can reconstruct from bounds if needed
      },
    ));
    realCanvas.clipPath(path, doAntiAlias: doAntiAlias);
  }
  
  void clipRRect(ui.RRect rrect, {bool doAntiAlias = true}) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.clipRRect,
      params: {
        'rrect': [
          rrect.left, rrect.top, rrect.right, rrect.bottom,
          rrect.tlRadiusX, rrect.tlRadiusY,
          rrect.trRadiusX, rrect.trRadiusY,
          rrect.brRadiusX, rrect.brRadiusY,
          rrect.blRadiusX, rrect.blRadiusY,
        ],
        'doAntiAlias': doAntiAlias,
      },
    ));
    realCanvas.clipRRect(rrect, doAntiAlias: doAntiAlias);
  }
  
  // Drawing operations
  void drawRect(ui.Rect rect, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawRect,
      params: {
        'rect': [rect.left, rect.top, rect.right, rect.bottom],
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawRect(rect, paint);
  }
  
  void drawCircle(ui.Offset center, double radius, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawCircle,
      params: {
        'center': [center.dx, center.dy],
        'radius': radius,
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawCircle(center, radius, paint);
  }
  
  void drawOval(ui.Rect rect, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawOval,
      params: {
        'rect': [rect.left, rect.top, rect.right, rect.bottom],
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawOval(rect, paint);
  }
  
  void drawArc(ui.Rect rect, double startAngle, double sweepAngle, bool useCenter, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawArc,
      params: {
        'rect': [rect.left, rect.top, rect.right, rect.bottom],
        'startAngle': startAngle,
        'sweepAngle': sweepAngle,
        'useCenter': useCenter,
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
  }
  
  void drawPath(ui.Path path, ui.Paint paint) {
    // Serialize path bounds and approximate representation
    final bounds = path.getBounds();
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawPath,
      params: {
        'bounds': [bounds.left, bounds.top, bounds.right, bounds.bottom],
        'paint': _serializePaint(paint),
        // Note: Full path serialization would require parsing path commands
        // For now, we record bounds - native side can reconstruct from bounds if needed
      },
    ));
    realCanvas.drawPath(path, paint);
  }
  
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawLine,
      params: {
        'p1': [p1.dx, p1.dy],
        'p2': [p2.dx, p2.dy],
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawLine(p1, p2, paint);
  }
  
  void drawRRect(ui.RRect rrect, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawRRect,
      params: {
        'rrect': [
          rrect.left, rrect.top, rrect.right, rrect.bottom,
          rrect.tlRadiusX, rrect.tlRadiusY,
          rrect.trRadiusX, rrect.trRadiusY,
          rrect.brRadiusX, rrect.brRadiusY,
          rrect.blRadiusX, rrect.blRadiusY,
        ],
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawRRect(rrect, paint);
  }
  
  void drawDRRect(ui.RRect outer, ui.RRect inner, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawDRRect,
      params: {
        'outer': [
          outer.left, outer.top, outer.right, outer.bottom,
          outer.tlRadiusX, outer.tlRadiusY,
          outer.trRadiusX, outer.trRadiusY,
          outer.brRadiusX, outer.brRadiusY,
          outer.blRadiusX, outer.blRadiusY,
        ],
        'inner': [
          inner.left, inner.top, inner.right, inner.bottom,
          inner.tlRadiusX, inner.tlRadiusY,
          inner.trRadiusX, inner.trRadiusY,
          inner.brRadiusX, inner.brRadiusY,
          inner.blRadiusX, inner.blRadiusY,
        ],
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawDRRect(outer, inner, paint);
  }
  
  void drawImage(ui.Image image, ui.Offset offset, ui.Paint paint) {
    // For images, we still need to send pixel data (or image reference)
    // This is a limitation - images are complex
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawImage,
      params: {
        'offset': [offset.dx, offset.dy],
        'paint': _serializePaint(paint),
        // Note: Image data would need to be sent separately
      },
    ));
    realCanvas.drawImage(image, offset, paint);
  }
  
  void drawImageRect(ui.Image image, ui.Rect src, ui.Rect dst, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawImageRect,
      params: {
        'src': [src.left, src.top, src.right, src.bottom],
        'dst': [dst.left, dst.top, dst.right, dst.bottom],
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawImageRect(image, src, dst, paint);
  }
  
  void drawImageNine(ui.Image image, ui.Rect center, ui.Rect dst, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawImageNine,
      params: {
        'center': [center.left, center.top, center.right, center.bottom],
        'dst': [dst.left, dst.top, dst.right, dst.bottom],
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawImageNine(image, center, dst, paint);
  }
  
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawParagraph,
      params: {
        'offset': [offset.dx, offset.dy],
        // Paragraph data would need to be serialized separately
      },
    ));
    realCanvas.drawParagraph(paragraph, offset);
  }
  
  void drawPoints(ui.PointMode pointMode, List<ui.Offset> points, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawPoints,
      params: {
        'pointMode': pointMode.index,
        'points': points.map((p) => [p.dx, p.dy]).toList(),
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawPoints(pointMode, points, paint);
  }
  
  void drawRawPoints(ui.PointMode pointMode, Float32List points, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawRawPoints,
      params: {
        'pointMode': pointMode.index,
        'points': points.toList(),
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawRawPoints(pointMode, points, paint);
  }
  
  void drawColor(ui.Color color, ui.BlendMode blendMode) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawColor,
      params: {
        'color': color.value,
        'blendMode': blendMode.index,
      },
    ));
    realCanvas.drawColor(color, blendMode);
  }
  
  void drawPaint(ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawPaint,
      params: {
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawPaint(paint);
  }
  
  // Get all recorded commands
  List<Map<String, dynamic>> getCommands() {
    return commands.map((cmd) => cmd.toMap()).toList();
  }
  
  // Clear commands
  void clear() {
    commands.clear();
  }
  
  // Serialize Paint object to map
  Map<String, dynamic> _serializePaint(ui.Paint paint) {
    return {
      'color': paint.color.value,
      'blendMode': paint.blendMode.index,
      'style': paint.style.index,
      'strokeWidth': paint.strokeWidth,
      'strokeCap': paint.strokeCap.index,
      'strokeJoin': paint.strokeJoin.index,
      'strokeMiterLimit': paint.strokeMiterLimit,
      'isAntiAlias': paint.isAntiAlias,
      'filterQuality': paint.filterQuality.index,
      // Shaders and masks are complex - would need separate handling
    };
  }
}

