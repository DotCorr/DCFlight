import 'package:dcf_primitives/dcf_primitives.dart';
import 'package:dcflight/dcflight.dart';

void main() async {
  await DCFlight.go(app: MyApp());
}

class MyApp extends DCFStatefulComponent {
  @override
  DCFComponentNode render() {
    final count = useState<int>(0);
    final isDarkMode = useState<bool>(DCFTheme.isDarkMode);
    
    return DCFView(
      layout: DCFLayout(
        flex: 1,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      // Using unified theme system instead of hardcoded colors
      styleSheet: DCFStyleSheet(
        backgroundColor: isDarkMode.state 
            ? DCFTheme.current.backgroundColor 
            : DCFTheme.current.surfaceColor,
      ),
      children: [
        DCFText(
          content: "Hello, World! ${count.state}",
          // Using theme text color - adapts to light/dark mode
          textProps: DCFTextProps(
            color: DCFTheme.textColor,
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
          ),
          layout: DCFLayout(
            height: 100,
            width: 200,
            justifyContent: YogaJustifyContent.center,
            alignItems: YogaAlign.center,
          ),
        ),
        DCFText(
          content: "Theme: ${isDarkMode.state ? 'Dark' : 'Light'}",
          textProps: DCFTextProps(
            color: DCFTheme.current.secondaryTextColor,
            fontSize: 16,
          ),
          layout: DCFLayout(
            marginTop: 20,
          ),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(
            title: "Count: ${count.state}",
          ),
          onPress: (data) => count.setState(count.state + 1),
          layout: DCFLayout(
            marginTop: 20,
          ),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(
            title: "Toggle Theme",
          ),
          onPress: (data) => isDarkMode.setState(!isDarkMode.state),
          layout: DCFLayout(
            marginTop: 10,
          ),
        ),
      ],
    );
  }

  @override
  List<Object?> get props => [];
}
