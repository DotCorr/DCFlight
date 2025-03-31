import 'dart:ui';
import '../packages/vdom/vdom_node.dart';
import '../packages/vdom/vdom_element.dart';
import '../packages/text/text_measurement_service.dart';
import 'view_props.dart';
import 'button_props.dart';
import 'image_props.dart';
import 'scroll_view_props.dart';
import 'modifiers/text_content.dart';

/// Factory for creating UI components
class UI {
  /// Create a View component
  static VDomElement View({
    required ViewProps props,
    List<VDomNode> children = const [],
    String? key,
  }) {
    return VDomElement(
      type: 'View',
      key: key,
      props: props.toMap(),
      children: children,
    );
  }

  /// Create a Text component with automatic measurement
  static VDomElement Text({
    required TextContent content,
    String? key,
  }) {
    // Extract the text props from the content
    final textNodes = content.generateTextNodes(null);

    // For now, just return the first text node
    if (textNodes.isEmpty) {
      return VDomElement(
        type: 'Text',
        key: key,
        props: {'content': ''},
      );
    }

    final textNode = textNodes.first;
    final props = Map<String, dynamic>.from(textNode.props);

    // Get the text content
    final text = props['content'] as String? ?? '';

    // Initialize measurements with reasonable defaults to avoid zero-size elements
    double width = 10.0; // Minimum default width
    double height = 20.0; // Minimum default height

    // Perform text measurement if we have enough info
    if (props.containsKey('fontSize')) {
      final fontSize = props['fontSize'] as double? ?? 14.0;

      // Create measurement key
      final measurementKey = TextMeasurementKey(
        text: text,
        fontSize: fontSize,
        fontFamily: props['fontFamily'] as String?,
        fontWeight: props['fontWeight'] as String?,
        letterSpacing: props['letterSpacing'] as double?,
        textAlign: props['textAlign'] as String?,
        maxWidth:
            props['width'] as double?, // Pass width constraint if available
      );

      // Try to get cached measurement
      final cachedMeasurement =
          TextMeasurementService.instance.getCachedMeasurement(measurementKey);

      // If we have a cached measurement, use it to set dimensions
      if (cachedMeasurement != null) {
        width = cachedMeasurement.width;
        height = cachedMeasurement.height;
      } else {
        // Schedule measurement for later, but use estimated size now
        final estimate =
            TextMeasurementService.instance.estimateTextSize(text, fontSize);
        width = estimate.width;
        height = estimate.height;

        // Request actual measurement asynchronously
        TextMeasurementService.instance.measureText(
          text,
          fontSize: fontSize,
          fontFamily: props['fontFamily'] as String?,
          fontWeight: props['fontWeight'] as String?,
          letterSpacing: props['letterSpacing'] as double?,
          textAlign: props['textAlign'] as String?,
          maxWidth: props['width'] as double?,
        );
      }
    }

    // Always set width and height to ensure the element has dimensions
    if (!props.containsKey('width') || props['width'] == 0.0) {
      props['width'] = width;
    }

    if (!props.containsKey('height') || props['height'] == 0.0) {
      props['height'] = height;
    }

    // Create a new VDomElement with the given key
    return VDomElement(
      type: textNode.type,
      key: key,
      props: props,
      children: textNode.children,
    );
  }

  /// Create a Button component
  static VDomElement Button({
    required ButtonProps props,
    String? key,
    Function? onPress,
  }) {
    final propsMap = props.toMap();

    if (onPress != null) {
      propsMap['onPress'] = onPress;
    }

    return VDomElement(
      type: 'Button',
      key: key,
      props: propsMap,
    );
  }

  /// Create an Image component
  static VDomElement Image({
    required ImageProps props,
    String? key,
  }) {
    return VDomElement(
      type: 'Image',
      key: key,
      props: props.toMap(),
    );
  }

  /// Create a ScrollView component
  static VDomElement ScrollView({
    required ScrollViewProps props,
    List<VDomNode> children = const [],
    String? key,
    Function? onScroll,
  }) {
    final propsMap = props.toMap();

    if (onScroll != null) {
      propsMap['onScroll'] = onScroll;
    }

    return VDomElement(
      type: 'ScrollView',
      key: key,
      props: propsMap,
      children: children,
    );
  }
}
