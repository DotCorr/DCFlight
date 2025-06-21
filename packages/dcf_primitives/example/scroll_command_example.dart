/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'package:dcf_primitives/dcf_primitives.dart';

/// Example demonstrating the new prop-based command pattern
/// This replaces the old imperative ref.method() pattern
class ScrollCommandExampleScreen extends StatefulComponent {
  
  @override
  State<ScrollCommandExampleScreen> createState() => _ScrollCommandExampleScreenState();
}

class _ScrollCommandExampleScreenState extends State<ScrollCommandExampleScreen> {
  ScrollViewCommand? _scrollCommand;
  FlatListCommand? _flatListCommand;
  
  final List<String> _items = List.generate(100, (index) => "Item $index");

  void _scrollToTop() {
    setState(() {
      _scrollCommand = const ScrollToTopCommand(animated: true);
    });
  }

  void _scrollToBottom() {
    setState(() {
      _scrollCommand = const ScrollToBottomCommand(animated: true);
    });
  }

  void _scrollToPosition() {
    setState(() {
      _scrollCommand = const ScrollToPositionCommand(x: 0, y: 500, animated: true);
    });
  }

  void _flashIndicators() {
    setState(() {
      _scrollCommand = const FlashScrollIndicatorsCommand();
    });
  }

  void _flatListScrollToIndex() {
    setState(() {
      _flatListCommand = const FlatListScrollToIndexCommand(index: 50, animated: true);
    });
  }

  void _flatListScrollToTop() {
    setState(() {
      _flatListCommand = const FlatListScrollToTopCommand(animated: true);
    });
  }

  @override
  DCFComponentNode render() {
    return DCFView(
      layout: const LayoutProps(flex: 1),
      backgroundColor: '#F5F5F5',
      children: [
        // Control buttons
        DCFView(
          layout: const LayoutProps(
            paddingHorizontal: 16,
            paddingVertical: 8,
            flexDirection: FlexDirection.row,
            flexWrap: FlexWrap.wrap,
            gap: 8,
          ),
          children: [
            DCFButton(
              title: "Scroll Top",
              onPress: (_) => _scrollToTop(),
              layout: const LayoutProps(marginRight: 8),
            ),
            DCFButton(
              title: "Scroll Bottom", 
              onPress: (_) => _scrollToBottom(),
              layout: const LayoutProps(marginRight: 8),
            ),
            DCFButton(
              title: "Scroll to 500px",
              onPress: (_) => _scrollToPosition(),
              layout: const LayoutProps(marginRight: 8),
            ),
            DCFButton(
              title: "Flash Indicators",
              onPress: (_) => _flashIndicators(),
            ),
          ],
        ),
        
        // ScrollView example
        DCFView(
          layout: const LayoutProps(flex: 1, marginHorizontal: 16),
          children: [
            DCFText(
              "ScrollView with Command Pattern:",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              layout: const LayoutProps(marginBottom: 8),
            ),
            DCFScrollView(
              command: _scrollCommand, // ✅ Type-safe command prop!
              layout: const LayoutProps(flex: 1, marginBottom: 16),
              backgroundColor: '#FFFFFF',
              children: [
                for (int i = 0; i < 50; i++)
                  DCFView(
                    layout: const LayoutProps(
                      height: 60,
                      marginVertical: 4,
                      paddingHorizontal: 16,
                      alignItems: AlignItems.center,
                      justifyContent: JustifyContent.center,
                    ),
                    backgroundColor: i % 2 == 0 ? '#E3F2FD' : '#F3E5F5',
                    children: [
                      DCFText("ScrollView Item $i"),
                    ],
                  ),
              ],
            ),
          ],
        ),
        
        // FlatList control buttons
        DCFView(
          layout: const LayoutProps(
            paddingHorizontal: 16,
            flexDirection: FlexDirection.row,
            gap: 8,
          ),
          children: [
            DCFButton(
              title: "FlatList to Index 50",
              onPress: (_) => _flatListScrollToIndex(),
            ),
            DCFButton(
              title: "FlatList to Top",
              onPress: (_) => _flatListScrollToTop(),
            ),
          ],
        ),
        
        // FlatList example  
        DCFView(
          layout: const LayoutProps(flex: 1, marginHorizontal: 16, marginTop: 8),
          children: [
            DCFText(
              "FlatList with Command Pattern:",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              layout: const LayoutProps(marginBottom: 8),
            ),
            DCFFlatList<String>(
              data: _items,
              command: _flatListCommand, // ✅ Type-safe command prop!
              layout: const LayoutProps(flex: 1),
              renderItem: (item, index) => DCFView(
                layout: const LayoutProps(
                  height: 50,
                  paddingHorizontal: 16,
                  alignItems: AlignItems.center,
                  justifyContent: JustifyContent.center,
                  borderBottomWidth: 1,
                ),
                borderColor: '#E0E0E0',
                backgroundColor: index % 2 == 0 ? '#F8F9FA' : '#FFFFFF',
                children: [
                  DCFText(item),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
