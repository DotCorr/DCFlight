// Style and layout registries - created once, reused across renders
// Using StyleSheet.create() for optimal performance (see StyleSheet.create() docs)
import 'package:dcflight/dcflight.dart';

final styles = DCFStyleSheet.create({
  'root': DCFStyleSheet(backgroundColor: DCFColors.black),
  'controlsPanel': DCFStyleSheet(
    backgroundColor: DCFTheme.current.surfaceColor,
    borderRadius: 20,
    elevation: 10,
  ),
  'titleText': DCFStyleSheet(primaryColor: DCFTheme.current.textColor),
  'bodyText': DCFStyleSheet(primaryColor: DCFTheme.current.textColor),
  'decrementButton': DCFStyleSheet(
    backgroundColor: const Color(0xFFFF5722),
    borderRadius: 8,
  ),
  'incrementButton': DCFStyleSheet(
    backgroundColor: const Color(0xFF4CAF50),
    borderRadius: 8,
  ),
  'buttonText': DCFStyleSheet(primaryColor: DCFColors.white),
  'toggleButton': DCFStyleSheet(
    backgroundColor: const Color(0xFF757575),
    borderRadius: 8,
  ),
  'toggleButtonActive': DCFStyleSheet(
    backgroundColor: const Color(0xFF4CAF50),
    borderRadius: 8,
  ),
  'infoBox': DCFStyleSheet(
    backgroundColor: const Color(0x3300FF00),
    borderRadius: 8,
  ),
  'infoText': DCFStyleSheet(primaryColor: DCFColors.green),
  'emptyStyle': DCFStyleSheet(),
});

final layouts = DCFLayout.create({
  'root': DCFLayout(flex: 1),
  'flutterWidget': DCFLayout(
    flex: 1,
    width: "100%",
    height: "100%",
  ),
  'controlsPanel': DCFLayout(
    width: '100%',
    flexWrap: DCFWrap.wrap,
    padding: 20,
  ),
  'title': DCFLayout(marginBottom: 15),
  'controlSection': DCFLayout(
    marginHorizontal: 10,
    width: "100%",
    marginBottom: 15,
  ),
  'speedText': DCFLayout(marginBottom: 10),
  'buttonRow': DCFLayout(
    flexDirection: DCFFlexDirection.row,
    gap: 10,
  ),
  'smallButton': DCFLayout(
    width: 50,
    height: 40,
  ),
  'fullWidthButton': DCFLayout(
    width: "100%",
    height: 40,
  ),
  'infoBox': DCFLayout(padding: 10),
});
