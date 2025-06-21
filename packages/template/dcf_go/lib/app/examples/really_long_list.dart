import 'package:dcflight/dcflight.dart';

class ReallyLongList extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final currentCommand = useState<FlatListCommand?>(null);

    return DCFView(
      layout: const LayoutProps(
        flex: 1,
        padding: 10,
      ),
      children: [
        // Control buttons demonstrating the new command pattern
        DCFView(
          layout: const LayoutProps(
            flexDirection: YogaFlexDirection.row,
            height: 200,
            flexWrap: YogaWrap.wrap,
            gap: 10,
            marginBottom: 10,
          ),
          children: [
            DCFButton(
              buttonProps: DCFButtonProps(title: "Scroll to Top"),
              layout: const LayoutProps(height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.blue, borderRadius: 8),
              onPress: (v) {
                currentCommand.setState(const FlatListScrollToTopCommand(animated: true));
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Scroll to Bottom"),
              layout: const LayoutProps(height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.green, borderRadius: 8),
              onPress: (v) {
                currentCommand.setState(const FlatListScrollToBottomCommand(animated: true));
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Scroll to Index 50"),
              layout: const LayoutProps(height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.orange, borderRadius: 8),
              onPress: (v) {
                currentCommand.setState(const ScrollToIndexCommand(index: 50, animated: true));
              },
            ),
          ],
        ),
        
        // FlatList with command prop demonstrating new pattern
        DCFView(
          layout: const LayoutProps(flex: 1),
          children: [
            DCFFlatList(
              // ✅ NEW: Type-safe command prop for imperative control
              command: currentCommand.state,
              
              onScroll: (v) {
                // Clear command after it's been processed to avoid re-execution
                if (currentCommand.state != null) {
                  Future.microtask(() {
                    currentCommand.setState(null);
                  });
                }
              },
              data: List<int>.generate(100, (i) => i + 1),
              renderItem: (v, i) {
                return DCFView(
                  layout: LayoutProps(
                    gap: 5,
                    flexDirection: YogaFlexDirection.row,
                    flexWrap: YogaWrap.wrap,
                    height: 50,
                    width: double.infinity,
                    padding: 10,
                    justifyContent: YogaJustifyContent.center,
                  ),
                  styleSheet: StyleSheet(
                    backgroundColor: i == 50 ? Colors.lightBlue : null, // Highlight item 50
                  ),
                  children: [
                    DCFText(
                      content: "Item ${i + 1}",
                      textProps: DCFTextProps(
                        fontSize: 16, 
                        color: Colors.black,
                        fontWeight: i == 50 ? DCFFontWeight.bold : DCFFontWeight.regular,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}