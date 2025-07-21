import "package:dcflight/dcflight.dart";

class AnimatedModalScreen extends StatelessComponent {
  
  @override
  DCFComponentNode render() {
    return DCFView(
      styleSheet: StyleSheet(backgroundColor: Colors.amber),
      layout: LayoutProps(
        flex: 1,
        padding: 16,
        gap: 2,
        alignContent: YogaAlign.spaceBetween,
        justifyContent: YogaJustifyContent.spaceBetween,
      ),
    );
  }
}