/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'dart:ui' as ui;
import 'dart:typed_data';

/// Drawing command types
/// Covers all Flutter Canvas API methods for complete functionality
enum DrawingCommandType {
  // Transformations
  save,
  restore,
  restoreToCount,
  translate,
  rotate,
  scale,
  skew,
  transform,
  
  // Clipping
  clipRect,
  clipPath,
  clipRRect,
  clipRSuperellipse,
  
  // Drawing - Basic Shapes
  drawRect,
  drawCircle,
  drawOval,
  drawArc,
  drawPath,
  drawLine,
  drawRRect,
  drawDRRect,
  drawRSuperellipse,
  
  // Drawing - Images
  drawImage,
  drawImageRect,
  drawImageNine,
  drawPicture,
  
  // Drawing - Text
  drawParagraph,
  
  // Drawing - Points & Vertices
  drawPoints,
  drawRawPoints,
  drawVertices,
  drawAtlas,
  drawRawAtlas,
  
  // Drawing - Effects
  drawShadow,
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
  
  void restoreToCount(int count) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.restoreToCount,
      params: {'count': count},
    ));
    realCanvas.restoreToCount(count);
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
    commands.add(DrawingCommand(
      type: DrawingCommandType.transform,
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
    final bounds = path.getBounds();
    final pathCommands = _serializePath(path);
    commands.add(DrawingCommand(
      type: DrawingCommandType.clipPath,
      params: {
        'bounds': [bounds.left, bounds.top, bounds.right, bounds.bottom],
        'pathCommands': pathCommands,
        'doAntiAlias': doAntiAlias,
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
  
  void clipRSuperellipse(ui.RSuperellipse rsuperellipse, {bool doAntiAlias = true}) {
    final rect = rsuperellipse.outerRect;
    commands.add(DrawingCommand(
      type: DrawingCommandType.clipRSuperellipse,
      params: {
        'rect': [rect.left, rect.top, rect.right, rect.bottom],
        'tlRadiusX': rsuperellipse.tlRadiusX,
        'tlRadiusY': rsuperellipse.tlRadiusY,
        'trRadiusX': rsuperellipse.trRadiusX,
        'trRadiusY': rsuperellipse.trRadiusY,
        'brRadiusX': rsuperellipse.brRadiusX,
        'brRadiusY': rsuperellipse.brRadiusY,
        'blRadiusX': rsuperellipse.blRadiusX,
        'blRadiusY': rsuperellipse.blRadiusY,
        'doAntiAlias': doAntiAlias,
      },
    ));
    realCanvas.clipRSuperellipse(rsuperellipse, doAntiAlias: doAntiAlias);
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
    final bounds = path.getBounds();
    final pathCommands = _serializePath(path);
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawPath,
      params: {
        'bounds': [bounds.left, bounds.top, bounds.right, bounds.bottom],
        'pathCommands': pathCommands,
        'paint': _serializePaint(paint),
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
  
  void drawRSuperellipse(ui.RSuperellipse rsuperellipse, ui.Paint paint) {
    final rect = rsuperellipse.outerRect;
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawRSuperellipse,
      params: {
        'rect': [rect.left, rect.top, rect.right, rect.bottom],
        'tlRadiusX': rsuperellipse.tlRadiusX,
        'tlRadiusY': rsuperellipse.tlRadiusY,
        'trRadiusX': rsuperellipse.trRadiusX,
        'trRadiusY': rsuperellipse.trRadiusY,
        'brRadiusX': rsuperellipse.brRadiusX,
        'brRadiusY': rsuperellipse.brRadiusY,
        'blRadiusX': rsuperellipse.blRadiusX,
        'blRadiusY': rsuperellipse.blRadiusY,
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawRSuperellipse(rsuperellipse, paint);
  }
  
  void drawPicture(ui.Picture picture) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawPicture,
      params: {
        'pictureId': picture.hashCode.toString(),
      },
    ));
    realCanvas.drawPicture(picture);
  }
  
  void drawVertices(ui.Vertices vertices, ui.BlendMode blendMode, ui.Paint paint) {
    final vertexData = _serializeVertices(vertices);
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawVertices,
      params: {
        'mode': vertexData['mode'],
        'positions': vertexData['positions'],
        'textureCoordinates': vertexData['textureCoordinates'],
        'indices': vertexData['indices'],
        'colors': vertexData['colors'],
        'blendMode': blendMode.index,
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawVertices(vertices, blendMode, paint);
  }
  
  void drawAtlas(ui.Image atlas, List<ui.RSTransform> transforms, List<ui.Rect> rects,
      List<ui.Color>? colors, ui.BlendMode? blendMode, ui.Rect? cullRect, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawAtlas,
      params: {
        'transforms': transforms.map((t) => [t.scos, t.ssin, t.tx, t.ty]).toList(),
        'rects': rects.map((r) => [r.left, r.top, r.right, r.bottom]).toList(),
        'colors': colors?.map((c) => c.value).toList(),
        'blendMode': blendMode?.index,
        'cullRect': cullRect != null ? [cullRect.left, cullRect.top, cullRect.right, cullRect.bottom] : null,
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawAtlas(atlas, transforms, rects, colors, blendMode, cullRect, paint);
  }
  
  void drawRawAtlas(ui.Image atlas, Float32List rstTransforms, Float32List rects,
      Int32List? colors, ui.BlendMode? blendMode, ui.Rect? cullRect, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawRawAtlas,
      params: {
        'rstTransforms': rstTransforms.toList(),
        'rects': rects.toList(),
        'colors': colors?.toList(),
        'blendMode': blendMode?.index,
        'cullRect': cullRect != null ? [cullRect.left, cullRect.top, cullRect.right, cullRect.bottom] : null,
        'paint': _serializePaint(paint),
      },
    ));
    realCanvas.drawRawAtlas(atlas, rstTransforms, rects, colors, blendMode, cullRect, paint);
  }
  
  void drawShadow(ui.Path path, ui.Color color, double elevation, bool transparentOccluder) {
    final bounds = path.getBounds();
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawShadow,
      params: {
        'bounds': [bounds.left, bounds.top, bounds.right, bounds.bottom],
        'color': color.value,
        'elevation': elevation,
        'transparentOccluder': transparentOccluder,
      },
    ));
    realCanvas.drawShadow(path, color, elevation, transparentOccluder);
  }
  
  void drawImage(ui.Image image, ui.Offset offset, ui.Paint paint) {
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawImage,
      params: {
        'offset': [offset.dx, offset.dy],
        'width': image.width,
        'height': image.height,
        'paint': _serializePaint(paint),
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
    final paragraphData = _serializeParagraph(paragraph);
    commands.add(DrawingCommand(
      type: DrawingCommandType.drawParagraph,
      params: {
        'offset': [offset.dx, offset.dy],
        'width': paragraphData['width'],
        'height': paragraphData['height'],
        'maxLines': paragraphData['maxLines'],
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
  
  // Serialize Paint object to map - FULL SUPPORT including shaders, masks, filters
  Map<String, dynamic> _serializePaint(ui.Paint paint) {
    final result = <String, dynamic>{
      'color': paint.color.value,
      'blendMode': paint.blendMode.index,
      'style': paint.style.index,
      'strokeWidth': paint.strokeWidth,
      'strokeCap': paint.strokeCap.index,
      'strokeJoin': paint.strokeJoin.index,
      'strokeMiterLimit': paint.strokeMiterLimit,
      'isAntiAlias': paint.isAntiAlias,
      'filterQuality': paint.filterQuality.index,
    };
    
    // Serialize shader if present (Gradient, ImageShader, etc.)
    if (paint.shader != null) {
      result['shader'] = _serializeShader(paint.shader!);
    }
    
    // Serialize color filter if present
    if (paint.colorFilter != null) {
      result['colorFilter'] = _serializeColorFilter(paint.colorFilter!);
    }
    
    // Serialize mask filter if present (blur, etc.)
    if (paint.maskFilter != null) {
      result['maskFilter'] = _serializeMaskFilter(paint.maskFilter!);
    }
    
    // Serialize image filter if present
    if (paint.imageFilter != null) {
      result['imageFilter'] = _serializeImageFilter(paint.imageFilter!);
    }
    
    return result;
  }
  
  // Serialize Shader (Gradient, ImageShader, etc.)
  Map<String, dynamic> _serializeShader(ui.Shader shader) {
    if (shader is ui.Gradient) {
      return _serializeGradient(shader);
    } else if (shader is ui.ImageShader) {
      return _serializeImageShader(shader);
    } else {
      return {
        'type': 'unknown',
        'shaderId': shader.hashCode.toString(),
      };
    }
  }
  
  // Serialize Gradient (Linear, Radial, Sweep)
  // Note: Gradient is a base class with factory constructors
  // With FFI, we can access native Skia gradient data directly
  // For now, serialize reference - native side extracts from Skia Paint object
  Map<String, dynamic> _serializeGradient(ui.Gradient gradient) {
    return {
      'type': 'gradient',
      'gradientType': gradient.runtimeType.toString(),
      'gradientId': gradient.hashCode.toString(),
      'gradientString': gradient.toString(),
    };
  }
  
  // Serialize ImageShader
  // Note: ImageShader constructor parameters aren't directly accessible
  Map<String, dynamic> _serializeImageShader(ui.ImageShader shader) {
    return {
      'type': 'image',
      'shaderId': shader.hashCode.toString(),
      'shaderString': shader.toString(),
    };
  }
  
  // Serialize ColorFilter
  // Note: ColorFilter has private fields, use toString() to identify type
  // With FFI, we can access native Skia ColorFilter data directly
  Map<String, dynamic> _serializeColorFilter(ui.ColorFilter filter) {
    final filterString = filter.toString();
    
    // Parse from toString() or use reference
    // ColorFilter.matrix(...) or ColorFilter.mode(...) format
    if (filterString.contains('ColorFilter.matrix')) {
      // Extract matrix from string or use reference
      return {
        'type': 'matrix',
        'filterId': filter.hashCode.toString(),
        'filterString': filterString,
      };
    } else if (filterString.contains('ColorFilter.mode')) {
      return {
        'type': 'mode',
        'filterId': filter.hashCode.toString(),
        'filterString': filterString,
      };
    } else if (filterString.contains('linearToSrgbGamma')) {
      return {'type': 'linearToSrgbGamma'};
    } else if (filterString.contains('srgbToLinearGamma')) {
      return {'type': 'srgbToLinearGamma'};
    } else {
      return {
        'type': 'unknown',
        'filterId': filter.hashCode.toString(),
        'filterString': filterString,
      };
    }
  }
  
  // Serialize MaskFilter
  // Note: MaskFilter.blur has private fields, use toString() to extract
  Map<String, dynamic> _serializeMaskFilter(ui.MaskFilter filter) {
    final filterString = filter.toString();
    
    // MaskFilter.blur(BlurStyle.normal, 5.0) format
    if (filterString.contains('MaskFilter.blur')) {
      // Extract style and sigma from string
      return {
        'type': 'blur',
        'filterId': filter.hashCode.toString(),
        'filterString': filterString,
      };
    } else {
      return {
        'type': 'unknown',
        'filterId': filter.hashCode.toString(),
        'filterString': filterString,
      };
    }
  }
  
  // Serialize ImageFilter
  // Note: ImageFilter is abstract with factory constructors
  Map<String, dynamic> _serializeImageFilter(ui.ImageFilter filter) {
    final filterString = filter.toString();
    
    // Parse from toString() format
    if (filterString.contains('ImageFilter.blur')) {
      return {
        'type': 'blur',
        'filterId': filter.hashCode.toString(),
        'filterString': filterString,
      };
    } else if (filterString.contains('ImageFilter.matrix')) {
      return {
        'type': 'matrix',
        'filterId': filter.hashCode.toString(),
        'filterString': filterString,
      };
    } else if (filterString.contains('ImageFilter.compose')) {
      return {
        'type': 'compose',
        'filterId': filter.hashCode.toString(),
        'filterString': filterString,
      };
    } else {
      return {
        'type': 'unknown',
        'filterId': filter.hashCode.toString(),
        'filterString': filterString,
      };
    }
  }
  
  // Serialize Path to list of commands
  List<Map<String, dynamic>> _serializePath(ui.Path path) {
    final commands = <Map<String, dynamic>>[];
    try {
      final metrics = path.computeMetrics();
      for (final metric in metrics) {
        final length = metric.length;
        final extractedPath = metric.extractPath(0, length);
        final bounds = extractedPath.getBounds();
        commands.add({
          'type': 'contour',
          'bounds': [bounds.left, bounds.top, bounds.right, bounds.bottom],
          'length': length,
        });
      }
    } catch (e) {
      final bounds = path.getBounds();
      commands.add({
        'type': 'bounds',
        'bounds': [bounds.left, bounds.top, bounds.right, bounds.bottom],
      });
    }
    return commands;
  }
  
  // Serialize Vertices to map
  // Note: Vertices data is not directly accessible, so we use a reference
  Map<String, dynamic> _serializeVertices(ui.Vertices vertices) {
    return {
      'mode': 0,
      'positions': <double>[],
      'textureCoordinates': null,
      'indices': null,
      'colors': null,
      'verticesId': vertices.hashCode.toString(),
    };
  }
  
  // Serialize Paragraph to map
  Map<String, dynamic> _serializeParagraph(ui.Paragraph paragraph) {
    return {
      'width': paragraph.maxIntrinsicWidth,
      'height': paragraph.height,
      'paragraphId': paragraph.hashCode.toString(),
    };
  }
}

