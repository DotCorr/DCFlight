/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// DEBUG: What's actually being rendered vs what should be rendered
class DebugRenderedItems extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final itemsState = useMemo(
      () => List.generate(
        1000,
        (index) => ListItem(
          id: 'item_$index',
          title: 'Item #${index + 1}',
          subtitle: 'Debug test item',
          value: (index + 1) * 1.5,
          isHighlighted: index % 50 == 0,
          category: ['Work', 'Personal', 'Important'][index % 3],
          timestamp: DateTime.now(),
        ),
      ),
      dependencies: [],
    );

    final scrollOffsetState = useState<double>(0.0, 'scrollOffset');
    final highestRenderedIndexState = useState<int>(19, 'highestRenderedIndex');
    final isLoadingState = useState<bool>(
      false,
      'isLoading',
    ); // Prevent double loading

    const double itemHeight = 80.0;
    const double headerHeight = 60.0;
    const double footerHeight = 60.0;
    const int batchSize = 20;

    final scrollOffset = scrollOffsetState.state;
    final totalItems = itemsState.length;
    final totalContentHeight =
        headerHeight + (totalItems * itemHeight) + footerHeight;
    final highestRendered = highestRenderedIndexState.state;
    final isLoading = isLoadingState.state;

    // Calculate which items are actually visible based on scroll position
    // Account for header being part of the scrollable content
    final firstVisibleIndex =
        scrollOffset <= headerHeight
            ? 0
            : ((scrollOffset - headerHeight) / itemHeight).floor().clamp(
              0,
              totalItems - 1,
            );

    // Use a reasonable viewport estimate or get from layout
    final viewportHeight = 600.0; // Could be made dynamic later
    final lastVisibleIndex =
        scrollOffset <= headerHeight
            ? ((viewportHeight - (headerHeight - scrollOffset)) / itemHeight)
                .ceil()
                .clamp(0, totalItems - 1)
            : ((scrollOffset - headerHeight + viewportHeight) / itemHeight)
                .ceil()
                .clamp(0, totalItems - 1);

    // Check expansion - use a more robust threshold
    final threshold = highestRendered - 10; // Load earlier but not too early
    if (lastVisibleIndex > threshold &&
        highestRendered < totalItems - 1 &&
        !isLoading) {
      final newHighestRendered = (highestRendered + batchSize).clamp(
        0,
        totalItems - 1,
      );
      // Use microtask to prevent render loops
      isLoadingState.setState(true); // Set loading immediately
      Future.microtask(() {
        if (highestRenderedIndexState.state == highestRendered) {
          // Prevent double updates
          highestRenderedIndexState.setState(newHighestRendered);
          isLoadingState.setState(false); // Clear loading after update
          print(
            '🚀 EXPANDING: From 0-$highestRendered to 0-$newHighestRendered',
          );
        }
      });
    }

    // 🚀 DEBUG: Build items and LOG what we're building
    final renderedItems = <DCFComponentNode>[];
    print('🔍 BUILDING ITEMS: Should build 0-$highestRendered');

    for (int i = 0; i <= highestRendered && i < totalItems; i++) {
      final item = DebugListItem(
        key: 'debug_item_$i',
        index: i,
        title: itemsState[i].title,
      );
      renderedItems.add(item);

      // Log every 10th item
      if (i % 10 == 0) {
        print('✅ Built item $i: ${itemsState[i].title}');
      }
    }

    print('🔍 TOTAL BUILT: ${renderedItems.length} items');
    print('🔍 FIRST ITEM: ${renderedItems.isNotEmpty ? "Item 0" : "NONE"}');
    print(
      '🔍 LAST ITEM: ${renderedItems.isNotEmpty ? "Item ${renderedItems.length - 1}" : "NONE"}',
    );

    // Calculate bottom spacer height more accurately
    final remainingItems = totalItems - highestRendered - 1;
    final bottomSpacerHeight =
        remainingItems > 0 ? remainingItems * itemHeight : 0.0;

    // 🚀 DEBUG: Log what goes into the ScrollView children
    final scrollViewChildren = <DCFComponentNode>[
      // Header
      DCFView(
        key: 'debug_header',
        layout: LayoutProps(
          height: headerHeight,
          padding: 16,
          justifyContent: YogaJustifyContent.center,
        ),
        styleSheet: StyleSheet(backgroundColor: Colors.purple[100]),
        children: [
          DCFText(
            content:
                '🔍 DEBUG HEADER - Should see ${renderedItems.length} items below',
          ),
        ],
      ),

      // 🚀 ADD ITEMS TO CHILDREN
      ...renderedItems,

      // Bottom spacer
      if (bottomSpacerHeight > 0)
        DCFView(
          key: 'debug_bottom_spacer',
          layout: LayoutProps(height: bottomSpacerHeight),
          styleSheet: StyleSheet(backgroundColor: Colors.red[200]),
          children: [
            DCFView(
              layout: LayoutProps(
                padding: 16,
                justifyContent: YogaJustifyContent.center,
              ),
              children: [
                DCFText(content: '🔍 SPACER: $remainingItems items remaining'),
                DCFText(
                  content: 'Height: ${bottomSpacerHeight.toStringAsFixed(0)}px',
                ),
              ],
            ),
          ],
        ),

      // Footer
      DCFView(
        key: 'debug_footer',
        layout: LayoutProps(
          height: footerHeight,
          padding: 16,
          justifyContent: YogaJustifyContent.center,
        ),
        styleSheet: StyleSheet(backgroundColor: Colors.green[100]),
        children: [DCFText(content: '🔍 DEBUG FOOTER')],
      ),
    ];

    print(
      '🔍 SCROLL VIEW CHILDREN: ${scrollViewChildren.length} total children',
    );
    print(
      '🔍 BREAKDOWN: 1 header + ${renderedItems.length} items + ${bottomSpacerHeight > 0 ? 1 : 0} spacer + 1 footer',
    );

    return DCFView(
      layout: LayoutProps(flex: 1, flexDirection: YogaFlexDirection.column),
      children: [
        // Debug header
        DCFView(
          layout: LayoutProps(
            height: 120,
            width: "100%",
            padding: 16,
            flexDirection: YogaFlexDirection.column,
          ),
          styleSheet: StyleSheet(backgroundColor: Colors.blue.withOpacity(0.2)),
          children: [
            DCFText(
              content:
                  'DEBUG: Scroll=${scrollOffset.toStringAsFixed(0)}px | Visible: $firstVisibleIndex-$lastVisibleIndex',
            ),
            DCFText(
              content:
                  'Built ${renderedItems.length} items (0-$highestRendered)',
            ),
            DCFText(
              content: 'ScrollView has ${scrollViewChildren.length} children',
            ),
            DCFText(
              content:
                  'Should expand: ${lastVisibleIndex > threshold} (last=$lastVisibleIndex > threshold=$threshold)',
            ),
          ],
        ),

        // ScrollView with stable key to prevent attachment issues
        DCFScrollView(
          key: 'debug_scroll_view', // Stable key
          layout: LayoutProps(flex: 1),
          showsScrollIndicator: true,
          command: ScrollViewCommand(
            setContentSize: SetContentSizeCommand(
              width: 400,
              height: totalContentHeight,
            ),
          ),
          onScroll: (event) {
            final contentOffset =
                event['contentOffset'] as Map<dynamic, dynamic>?;
            if (contentOffset != null) {
              final y = (contentOffset['y'] as num?)?.toDouble() ?? 0.0;
              scrollOffsetState.setState(y);
            }
          },
          children: scrollViewChildren,
        ),
      ],
    );
  }
}

/// Simple debug item that shows its index clearly
class DebugListItem extends StatelessComponent {
  final int index;
  final String title;

  DebugListItem({required this.index, required this.title, super.key});

  @override
  DCFComponentNode render() {
    return DCFView(
      layout: LayoutProps(
        height: 80,
        padding: 16,
        flexDirection: YogaFlexDirection.row,
        alignItems: YogaAlign.center,
      ),
      styleSheet: StyleSheet(
        backgroundColor: index % 2 == 0 ? Colors.white : Colors.grey[100],
        borderWidth: 1,
        borderColor: Colors.blue[200],
      ),
      children: [
        DCFView(
          layout: LayoutProps(
            width: 60,
            height: 60,
            marginRight: 16,
            justifyContent: YogaJustifyContent.center,

            alignItems: YogaAlign.center,
          ),
          styleSheet: StyleSheet(
            backgroundColor: Colors.blue[300],
            borderRadius: 30,
          ),
          children: [
            DCFText(
              content: '$index',
              textProps: DCFTextProps(textAlign: "center"),
            ),
          ],
        ),
        DCFView(
          layout: LayoutProps(
            flex: 1,
            flexDirection: YogaFlexDirection.column,
            justifyContent: YogaJustifyContent.center,
          ),
          children: [
            DCFText(content: title),
            DCFText(content: 'Index: $index | Y: ${index * 80}px'),
          ],
        ),
      ],
    );
  }
}

/// Even simpler test - just show 10 actual items
class ShowActualItems extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // Just 10 items, no virtualization
    const int totalItems = 10;
    const double itemHeight = 100.0;

    final items = <DCFComponentNode>[];
    for (int i = 0; i < totalItems; i++) {
      items.add(
        DCFView(
          key: 'actual_item_$i',
          layout: LayoutProps(
            height: itemHeight,
            padding: 20,
            margin: 4,
            justifyContent: YogaJustifyContent.center,
            alignItems: YogaAlign.center,
          ),
          styleSheet: StyleSheet(
            backgroundColor: Colors.primaries[i % Colors.primaries.length],
            borderRadius: 8,
          ),
          children: [
            DCFText(content: 'ACTUAL ITEM $i'),
            DCFText(content: 'This should be visible'),
          ],
        ),
      );
    }

    print('ACTUAL ITEMS: Built ${items.length} items');

    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFText(
          content:
              'Actual Items Test - Should see ${items.length} colored items',
        ),

        DCFScrollView(
          layout: LayoutProps(flex: 1),
          children: [
            DCFText(content: 'HEADER - Items should appear below'),
            ...items,
            DCFText(content: 'FOOTER - Items should appear above'),
          ],
        ),
      ],
    );
  }
}

// Keep the ListItem class
class ListItem {
  final String id;
  final String title;
  final String subtitle;
  final double value;
  final bool isHighlighted;
  final String category;
  final DateTime timestamp;

  ListItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.value,
    this.isHighlighted = false,
    required this.category,
    required this.timestamp,
  });
}
