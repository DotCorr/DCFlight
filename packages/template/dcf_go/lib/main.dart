import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';

void main() async {
  // Set log level to see all logs (default is warning)
  // Options: none, error, warning, info, debug, verbose
  DCFLogger.setLevel(DCFLogLevel.info);

  // Optional: Set identifiers for log isolation
  // DCFLogger.setProjectId('my-project');
  // DCFLogger.setInstanceId('instance-1');

  // Log app startup (tag defaults to 'DCFlight' if not provided)
  DCFLogger.info('Starting DCFlight app...', 'App');

  // Example of all log levels (tag is optional, defaults to 'DCFlight'):
  // DCFLogger.error('Error message', error: errorObject, stackTrace: stackTrace, tag: 'MyTag');
  // DCFLogger.warning('Warning message', 'MyTag');
  // DCFLogger.info('Info message', 'MyTag');
  // DCFLogger.debug('Debug message', 'MyTag');
  // DCFLogger.verbose('Verbose message', 'MyTag');

  // Or without tag (uses default 'DCFlight'):
  // DCFLogger.info('Simple message');
  // DCFLogger.debug('Debug message');

  await DCFlight.go(app: MyApp());
}

class MyApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final count = useState<int>(0);
    final sliderVal = useState<double>(0.0);

    final name = useState<String>("");
    final isDarkMode = useState<bool>(DCFTheme.isDarkMode);

    return DCFView(
      layout: DCFLayout(
        padding: 20,
        flex: 1,
        justifyContent: YogaJustifyContent.center,
        alignItems:isDarkMode.state ? YogaAlign.center : YogaAlign.flexStart,
      ),
      // Using unified theme system with semantic colors
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFTheme.current.backgroundColor,
      ),
      children: [
        DCFText(
          content: "Hello, Test ${name.state}! ${count.state}",
          // Using semantic colors from StyleSheet instead of explicit color prop
          styleSheet: DCFStyleSheet(
            backgroundColor: DCFColors.amber,
            borderRadius: 20,
            elevation: 10,
            primaryColor:
                DCFTheme.textColor, // Semantic color - maps to text color
          ),
          textProps: DCFTextProps(fontSize: 24, fontWeight: DCFFontWeight.bold),
          layout: DCFLayout(
            height: 100,
            width: 200,
            justifyContent: YogaJustifyContent.center,
            alignItems: YogaAlign.center,
          ),
        ),
        DCFWebView(
          webViewProps: DCFWebViewProps(source: 'https://dotcorr.com'),
        ),

        DCFSlider(
          value: sliderVal.state.toDouble(),
          onValueChange: (data) {
            sliderVal.setState(data.value);
            // Log slider change (using debug level for frequent updates)
            DCFLogger.debug('Slider value changed to: ${data.value}', 'MyApp');
          },
        ),
        DCFSpinner(),
        DCFIcon(iconProps: DCFIconProps(name: DCFIcons.aArrowDown)),
        DCFSegmentedControl(
          segmentedControlProps: DCFSegmentedControlProps(
            selectedIndex: sliderVal.state.toInt(),
            segments: [
              DCFSegmentItem(title: "Item 1"),
              DCFSegmentItem(title: "Item 2"),
            ],
          ),
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.red),
          layout: DCFLayout(
            width: 200,
            height: 40,
            alignItems: YogaAlign.center,
            justifyContent: YogaJustifyContent.center,
          ),
        ),
        DCFAlert(
          visible: isDarkMode.state,
          title: "Alert",
          message: "Theme changed to ${isDarkMode.state ? 'Dark' : 'Light'}",
          textFields: [DCFAlertTextField(placeholder: "Enter your name")],
          actions: [
            DCFAlertAction(
              title: "Change Theme",
              style: DCFAlertActionStyle.destructive,
              handler: "Change Theme",
            ),
          ],
          onActionPress: (data) {
            if (data['handler'] == "Change Theme") {
              final newDarkMode = !isDarkMode.state;
              isDarkMode.setState(newDarkMode);
              // Actually update the theme
              DCFTheme.setTheme(
                newDarkMode ? DCFThemeData.dark : DCFThemeData.light,
              );
              // Log alert action
              DCFLogger.info('Alert action pressed: Change Theme', 'MyApp');
            }
          },
        ),
        DCFDropdown(
          dropdownProps: DCFDropdownProps(
            items: [
              DCFDropdownMenuItem(title: "Item 1", value: "item1"),
              DCFDropdownMenuItem(title: "Item 2", value: "item2"),
            ],
          ),
        ),

        DCFText(
          content: "Theme: ${isDarkMode.state ? 'Dark' : 'Light'}",
          // Using semantic secondaryColor for secondary text
          styleSheet: DCFStyleSheet(
            secondaryColor: DCFTheme.current.secondaryTextColor,
          ),
          textProps: DCFTextProps(fontSize: 16),
          layout: DCFLayout(marginTop: 20),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Count: ${count.state}"),
          onPress: (data) {
            final newCount = count.state + 1;
            count.setState(newCount);
            // Log button press
            DCFLogger.info(
              'Count button pressed, new count: $newCount',
              'MyApp',
            );
          },
          layout: DCFLayout(marginTop: 20),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Toggle Theme"),
          onPress: (data) {
            final newDarkMode = !isDarkMode.state;
            isDarkMode.setState(newDarkMode);
            // Actually update the theme
            DCFTheme.setTheme(
              newDarkMode ? DCFThemeData.dark : DCFThemeData.light,
            );
            // Log theme change
            DCFLogger.info(
              'Theme changed to ${newDarkMode ? 'Dark' : 'Light'}',
              'MyApp',
            );
          },
          layout: DCFLayout(marginTop: 10, height: 50),
        ),
      ],
    );
  }
}
