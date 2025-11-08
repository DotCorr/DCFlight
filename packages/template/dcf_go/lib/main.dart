import 'dart:io';

import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';

void main() async {
  await DCFlight.go(app: MyApp());
}

class MyApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final count = useState<int>(0);
    final sliderVal = useState<double>(0.0);
    

    final name = useState<String>("");
    final isDarkMode = useState<bool>(DCFTheme.isDarkMode);

    return DCFTheme.current.isDark ? DCFView(
      layout: DCFLayout(
        padding:20,
        flex: 1,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
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
            backgroundColor: DCFColors.red,
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

        DCFSlider(value: sliderVal.state.toDouble(),
        onValueChange: (data) => sliderVal.setState(data.value),
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
          styleSheet: DCFStyleSheet(primaryColor: DCFColors.blue),
          layout: DCFLayout(width: 200,height: 40,alignItems: YogaAlign.center,justifyContent: YogaJustifyContent.center),
        ),
        DCFAlert(
          visible: isDarkMode.state,
          title: "Alert",
          message: "Theme changed to ${isDarkMode.state ? 'Dark' : 'Light'}",
      
          actions: [
          DCFAlertAction(title: "Cancel", style: DCFAlertActionStyle.cancel, handler: "Cancel"),
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
          onPress: (data) => count.setState(count.state + 1),
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
          },
          layout: DCFLayout(marginTop: 10,height: 
          50),
        ),
        
      ],
    ):DCFView(
      layout: DCFLayout(
        flex: 1,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      styleSheet: DCFStyleSheet(
        backgroundColor: DCFTheme.current.backgroundColor,
      
      ),
      children: [
        DCFToggle(value: DCFTheme.isDarkMode, onValueChange: (data) {
             final newDarkMode = !isDarkMode.state;
            isDarkMode.setState(newDarkMode);
            // Actually update the theme
            DCFTheme.setTheme(
              newDarkMode ? DCFThemeData.dark : DCFThemeData.light,
            );
        }),
         DCFButton(buttonProps: DCFButtonProps(title:isDarkMode.state.toString()), onPress: (data) {
            final newDarkMode = !isDarkMode.state;
            isDarkMode.setState(newDarkMode);
            // Actually update the theme
            DCFTheme.setTheme(
              newDarkMode ? DCFThemeData.dark : DCFThemeData.light,
            );
        }),
      ]
    );
  }

  @override
  List<Object?> get props => [];
}
