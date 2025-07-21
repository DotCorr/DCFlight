import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatelessComponent {
  
  @override
  DCFComponentNode render() {
    return DCFScrollView(
      styleSheet: StyleSheet(backgroundColor: Colors.amber),
      layout: LayoutProps(
       height: "100%",
        width: "100%",
        padding: 16,
        gap: 2,
        alignContent: YogaAlign.spaceBetween,
        justifyContent: YogaJustifyContent.spaceBetween,
       
      ),

      children: [
        DCFText(
          content: "Animated Modal Screen",
          textProps: DCFTextProps(
            fontSize: 24,
            fontWeight: DCFFontWeight.bold,
            color: Colors.black,
          ),
        ),
        DCFText(
          content: "Animation below",
          textProps: DCFTextProps(fontSize: 16, color: Colors.grey.shade600),
        ),
        DCFButton(
          buttonProps: DCFButtonProps(title: "Dismiss Modal"),
          layout: LayoutProps(height: 50, width: 200),
          styleSheet: StyleSheet(backgroundColor: Colors.red, borderRadius: 8),
          onPress: (v) {
          
          
          },
        ),
      ],
    );
  }
}