// Style and layout registries - created once, reused across renders
// Using StyleSheet.create() for optimal performance (see StyleSheet.create() docs)
import 'package:dcflight/dcflight.dart';

final styles = DCFStyleSheet.create({
  'root': DCFStyleSheet(
    backgroundColor: DCFColors.beige,
  ),
  'header': DCFStyleSheet(
    backgroundColor: const Color(0xFF1a1a2e),
    borderRadius: 12,
  ),
  'titleText': DCFStyleSheet(primaryColor: DCFColors.white),
  'subtitleText': DCFStyleSheet(primaryColor: const Color(0xFF888888)),
  'section': DCFStyleSheet(
    backgroundColor: const Color(0xFF16213e),
    borderRadius: 12,
  ),
  'sectionTitle': DCFStyleSheet(primaryColor: DCFColors.white),
  'animatedBox': DCFStyleSheet(
    backgroundColor: const Color(0xFF4CAF50),
    borderRadius: 12,
  ),
  'boxText': DCFStyleSheet(primaryColor: DCFColors.white),
  'canvasBox': DCFStyleSheet(
    backgroundColor: const Color(0xFF1a1a2e),
    borderRadius: 12,
  ),
  'gpuDemoBox': DCFStyleSheet(
    backgroundColor: const Color(0xFF2d1b69),
    borderRadius: 12,
  ),
  'demoButton': DCFStyleSheet(
    backgroundColor: const Color(0xFF0f3460),
    borderRadius: 8,
  ),
  'buttonText': DCFStyleSheet(primaryColor: DCFColors.white),
  'confettiOverlay': DCFStyleSheet(
    backgroundColor: DCFColors.transparent, // Explicit transparent background
  ),
  'emptyStyle': DCFStyleSheet(),
});

final layouts = DCFLayout.create({
  'root': DCFLayout(
    flex: 1,
    padding: 20,
  ),
  'header': DCFLayout(
    width: '100%',
    alignItems: DCFAlign.center,
    padding: 20,
    marginBottom: 20,
  ),
  'title': DCFLayout(
    marginBottom: 8,
    alignItems: DCFAlign.center,
  ),
  'subtitle': DCFLayout(
    marginBottom: 20,
  ),
  'section': DCFLayout(
    width: '100%',
    padding: 16,
    marginBottom: 16,
  ),
  'sectionTitle': DCFLayout(
    marginBottom: 12,
    alignItems: DCFAlign.center,
  ),
  'animatedBox': DCFLayout(
    width: '100%',
    minHeight: 100,
    padding: 20,
    alignItems: DCFAlign.center,
    justifyContent: DCFJustifyContent.center,
  ),
  'canvasBox': DCFLayout(
    width: '100%',
    height: 150,
  ),
  'gpuDemoBox': DCFLayout(
    width: '100%',
    minHeight: 100,
    padding: 20,
    alignItems: DCFAlign.center,
    justifyContent: DCFJustifyContent.center,
  ),
  'button': DCFLayout(
    width: '100%',
    padding: 12,
    marginTop: 12,
    alignItems: DCFAlign.center,
    justifyContent: DCFJustifyContent.center,
  ),
  'confettiOverlay': DCFLayout(
    position: DCFPositionType.absolute,
    absoluteLayout: AbsoluteLayout(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
    ),
  ),
});
