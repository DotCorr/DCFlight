import 'package:dcflight/dcflight.dart';

class ReallyLongList extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final currentCommand = useState<FlatListCommand?>(null);
    
    // Create a larger dataset to properly test virtualization
    final data = List<int>.generate(1000, (i) => i + 1); // 1000 items instead of 100
    
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
              buttonProps: DCFButtonProps(title: "Scroll to Item 50"),
              layout: const LayoutProps(height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.orange, borderRadius: 8),
              onPress: (v) {
                // Item 50 is at index 49 (0-based indexing)
                currentCommand.setState(const ScrollToIndexCommand(index: 49, animated: true));
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Scroll to Item 500"),
              layout: const LayoutProps(height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.red, borderRadius: 8),
              onPress: (v) {
                // Test scrolling to a much further item
                currentCommand.setState(const ScrollToIndexCommand(index: 499, animated: true));
              },
            ),
            DCFButton(
              buttonProps: DCFButtonProps(title: "Scroll to Item 900"),
              layout: const LayoutProps(height: 44),
              styleSheet: StyleSheet(backgroundColor: Colors.purple, borderRadius: 8),
              onPress: (v) {
                // Test scrolling to near the end
                currentCommand.setState(const ScrollToIndexCommand(index: 899, animated: true));
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
              
              // ✅ IMPROVED: Better virtualization config
              estimatedItemSize: 60.0, // Slightly larger for better estimation
              virtualizationConfig: VirtualizationConfig(
                windowSize: 15.0, // Larger window for smoother scrolling
                initialNumToRender: 20, // Render more items initially
                maxToRenderPerBatch: 15,
                debug: true, // Keep debug on to see what's happening
                defaultEstimatedItemSize: 60.0,
              ),
              
              onScroll: (v) {
                print('📜 MAnually Scrolled to: ${v['contentOffset']}');
                // Clear command after it's been processed to avoid re-execution
                if (currentCommand.state != null) {
                  Future.microtask(() {
                    currentCommand.setState(null);
                  });
                }
                
                // Log scroll info for debugging
                final contentOffset = v['contentOffset'] as Map<String, dynamic>?;
                if (contentOffset != null) {
                  final y = contentOffset['y'] as double? ?? 0.0;
                  if (y % 1000 < 50) { // Log every ~1000 pixels
                    print('📍 Scroll offset: ${y.toStringAsFixed(1)}');
                  }
                }
              },
              
              data: data,
              renderItem: (v, i) {
                return DCFView(
                  layout: const LayoutProps(
                    gap: 5,
                    flexDirection: YogaFlexDirection.row,
                    flexWrap: YogaWrap.wrap,
                    height: 100, // Fixed height for consistent virtualization
                    // ❌ REMOVED: width: double.infinity - this was causing crashes
                    // ✅ FIXED: Use flex: 1 for full width
                    flex: 1,
                    padding: 10,
                    justifyContent: YogaJustifyContent.center,
                  ),
                  styleSheet: StyleSheet(
                    backgroundColor: _getItemColor(i), // Dynamic colors to see recycling
                    borderWidth: 1,
                    borderColor: Colors.grey.withOpacity(0.3),
                  ),
                  children: [
                    DCFText(
                      content: "📱 Item ${i + 1} ${_getItemEmoji(i)}",
                      textProps: DCFTextProps(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: _isSpecialItem(i) ? DCFFontWeight.bold : DCFFontWeight.regular,
                      ),
                    ),
                  ],
                );
              },
              
              // ✅ IMPROVED: Better end reached handling
              onEndReached: () {
                print('🏁 Reached end of list!');
              },
              onEndReachedThreshold: 0.1,
              
              // ✅ IMPROVED: Add item type function for better recycling
              getItemType: (item, index) {
                // Demonstrate heterogeneous item types
                if (index % 10 == 0) return 'header'; // Every 10th item is a "header"
                if (index % 5 == 0) return 'important'; // Every 5th item is "important"
                return 'default'; // Regular items
              },
            ),
          ],
        ),
      ],
    );
  }
  
  /// Get dynamic colors to visualize recycling
  Color _getItemColor(int index) {
    if (index % 10 == 0) return Colors.lightBlue.withOpacity(0.3); // Headers
    if (index % 5 == 0) return Colors.orange.withOpacity(0.3); // Important
    if (index == 49) return Colors.green.withOpacity(0.5); // Item 50
    if (index == 499) return Colors.red.withOpacity(0.5); // Item 500
    if (index == 899) return Colors.purple.withOpacity(0.5); // Item 900
    return Colors.white;
  }
  
  /// Get emoji based on item type
  String _getItemEmoji(int index) {
    if (index % 10 == 0) return '📋'; // Headers
    if (index % 5 == 0) return '⭐'; // Important
    if (index == 49) return '🎯'; // Item 50
    if (index == 499) return '🚀'; // Item 500
    if (index == 899) return '🏆'; // Item 900
    return '📄'; // Regular items
  }
  
  /// Check if item should be bold
  bool _isSpecialItem(int index) {
    return index == 49 || index == 499 || index == 899 || index % 10 == 0;
  }
}