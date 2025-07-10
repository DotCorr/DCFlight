/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';

/// Fixed Virtual List - Proper virtualization implementation
/// This fixes the "scrolling into void" issue by correctly calculating
/// which items should be visible based on scroll position
class FixedVirtualList extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final itemsState = useMemo(
      () => List.generate(
        1000,
        (index) => ListItem(
          id: 'item_$index',
          title: 'Item #${index + 1}',
          subtitle: 'Fixed virtual list item',
          value: (index + 1) * 1.5,
          isHighlighted: index % 50 == 0,
          category: ['Work', 'Personal', 'Important'][index % 3],
          timestamp: DateTime.now(),
        ),
      ),
      dependencies: [],
    );

    final scrollOffsetState = useState<double>(0.0, 'scrollOffset');
    final viewportHeightState = useState<double>(600.0, 'viewportHeight');
    final isLoadingState = useState<bool>(false, 'isLoading');

    const double itemHeight = 80.0;
    const double headerHeight = 60.0;
    const double footerHeight = 60.0;
    const int batchSize = 20;
    const int bufferSize = 5; // Items to render outside viewport

    final scrollOffset = scrollOffsetState.state;
    final viewportHeight = viewportHeightState.state;
    final totalItems = itemsState.length;
    final isLoading = isLoadingState.state;

    // Calculate the total height of all content
    final totalContentHeight =
        headerHeight + (totalItems * itemHeight) + footerHeight;

    // Calculate which items are visible based on scroll position
    final VirtualizedRange visibleRange = _calculateVisibleRange(
      scrollOffset: scrollOffset,
      viewportHeight: viewportHeight,
      itemHeight: itemHeight,
      headerHeight: headerHeight,
      totalItems: totalItems,
      bufferSize: bufferSize,
    );

    // Calculate render range with progressive loading
    final int currentMaxRendered = _calculateMaxRendered(
      visibleRange: visibleRange,
      totalItems: totalItems,
      batchSize: batchSize,
    );

    // Check if we need to load more items
    final shouldLoadMore =
        visibleRange.lastVisible >= currentMaxRendered - 10 &&
        currentMaxRendered < totalItems &&
        !isLoading;

    if (shouldLoadMore) {
      isLoadingState.setState(true);
      Future.microtask(() {
        final newMaxRendered = (currentMaxRendered + batchSize).clamp(
          0,
          totalItems,
        );
        isLoadingState.setState(false);
        print('🚀 EXPANDING: From 0-$currentMaxRendered to 0-$newMaxRendered');
      });
    }

    // Build the items that should be rendered
    final renderedItems = <DCFComponentNode>[];

    print(
      '🔍 BUILDING ITEMS: Should build ${visibleRange.renderStart}-${visibleRange.renderEnd}',
    );

    for (
      int i = visibleRange.renderStart;
      i <= visibleRange.renderEnd && i < totalItems;
      i++
    ) {
      final item = FixedVirtualListItem(
        key: 'fixed_item_$i',
        index: i,
        title: itemsState[i].title,
        itemHeight: itemHeight,
      );
      renderedItems.add(item);

      if (i % 10 == 0) {
        print('✅ Built item $i: ${itemsState[i].title}');
      }
    }

    print('🔍 TOTAL BUILT: ${renderedItems.length} items');
    print(
      '🔍 VISIBLE RANGE: ${visibleRange.firstVisible}-${visibleRange.lastVisible}',
    );
    print(
      '🔍 RENDER RANGE: ${visibleRange.renderStart}-${visibleRange.renderEnd}',
    );

    // Calculate spacer heights
    final topSpacerHeight = visibleRange.renderStart * itemHeight;
    final bottomSpacerHeight =
        (totalItems - visibleRange.renderEnd - 1) * itemHeight;

    // Build the scroll view children
    final scrollViewChildren = <DCFComponentNode>[
      // Header
      DCFView(
        key: 'fixed_header',
        layout: LayoutProps(
          height: headerHeight,
          padding: 16,
          justifyContent: YogaJustifyContent.center,
        ),
        styleSheet: StyleSheet(backgroundColor: Colors.purple[100]),
        children: [
          DCFText(
            content: '🔧 FIXED HEADER - ${renderedItems.length} items rendered',
          ),
        ],
      ),

      // Top spacer (for items before render range)
      if (topSpacerHeight > 0)
        DCFView(
          key: 'top_spacer',
          layout: LayoutProps(height: topSpacerHeight),
          styleSheet: StyleSheet(backgroundColor: Colors.orange[100]),
          children: [
            DCFView(
              layout: LayoutProps(
                padding: 16,
                justifyContent: YogaJustifyContent.center,
              ),
              children: [
                DCFText(
                  content: '⬆️ TOP SPACER: ${visibleRange.renderStart} items',
                ),
                DCFText(
                  content: 'Height: ${topSpacerHeight.toStringAsFixed(0)}px',
                ),
              ],
            ),
          ],
        ),

      // Rendered items
      ...renderedItems,

      // Bottom spacer (for items after render range)
      if (bottomSpacerHeight > 0)
        DCFView(
          key: 'bottom_spacer',
          layout: LayoutProps(height: bottomSpacerHeight),
          styleSheet: StyleSheet(backgroundColor: Colors.red[100]),
          children: [
            DCFView(
              layout: LayoutProps(
                padding: 16,
                justifyContent: YogaJustifyContent.center,
              ),
              children: [
                DCFText(
                  content:
                      '⬇️ BOTTOM SPACER: ${totalItems - visibleRange.renderEnd - 1} items',
                ),
                DCFText(
                  content: 'Height: ${bottomSpacerHeight.toStringAsFixed(0)}px',
                ),
              ],
            ),
          ],
        ),

      // Footer
      DCFView(
        key: 'fixed_footer',
        layout: LayoutProps(
          height: footerHeight,
          padding: 16,
          justifyContent: YogaJustifyContent.center,
        ),
        styleSheet: StyleSheet(backgroundColor: Colors.green[100]),
        children: [DCFText(content: '🔧 FIXED FOOTER')],
      ),
    ];

    print(
      '🔍 SCROLL VIEW CHILDREN: ${scrollViewChildren.length} total children',
    );
    print(
      '🔍 BREAKDOWN: 1 header + ${topSpacerHeight > 0 ? 1 : 0} top spacer + ${renderedItems.length} items + ${bottomSpacerHeight > 0 ? 1 : 0} bottom spacer + 1 footer',
    );

    return DCFView(
      layout: LayoutProps(flex: 1, flexDirection: YogaFlexDirection.column),
      children: [
        // Debug header
        DCFView(
          layout: LayoutProps(
            height: 140,
            width: "100%",
            padding: 16,
            flexDirection: YogaFlexDirection.column,
          ),
          styleSheet: StyleSheet(
            backgroundColor: Colors.green.withOpacity(0.2),
          ),
          children: [
            DCFText(content: '🔧 FIXED VIRTUAL LIST DEBUG'),
            DCFText(
              content:
                  'Scroll: ${scrollOffset.toStringAsFixed(0)}px | Viewport: ${viewportHeight.toStringAsFixed(0)}px',
            ),
            DCFText(
              content:
                  'Visible: ${visibleRange.firstVisible}-${visibleRange.lastVisible} | Rendered: ${visibleRange.renderStart}-${visibleRange.renderEnd}',
            ),
            DCFText(
              content:
                  'Built ${renderedItems.length} items | Total: $totalItems',
            ),
            DCFText(
              content:
                  'Should load more: $shouldLoadMore | Loading: $isLoading',
            ),
          ],
        ),

        // ScrollView with fixed virtualization
        DCFScrollView(
          key: 'fixed_scroll_view',
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
            final layoutMeasurement =
                event['layoutMeasurement'] as Map<dynamic, dynamic>?;

            if (contentOffset != null) {
              final y = (contentOffset['y'] as num?)?.toDouble() ?? 0.0;
              scrollOffsetState.setState(y);
            }

            if (layoutMeasurement != null) {
              final height =
                  (layoutMeasurement['height'] as num?)?.toDouble() ?? 600.0;
              viewportHeightState.setState(height);
            }
          },
          children: scrollViewChildren,
        ),
      ],
    );
  }

  /// Calculate which items are visible and should be rendered
  VirtualizedRange _calculateVisibleRange({
    required double scrollOffset,
    required double viewportHeight,
    required double itemHeight,
    required double headerHeight,
    required int totalItems,
    required int bufferSize,
  }) {
    // Calculate the content scroll position (excluding header)
    final contentScrollOffset = (scrollOffset - headerHeight).clamp(
      0.0,
      double.infinity,
    );

    // Calculate which items are actually visible
    final firstVisibleIndex = (contentScrollOffset / itemHeight).floor().clamp(
      0,
      totalItems - 1,
    );
    final lastVisibleIndex = ((contentScrollOffset + viewportHeight) /
            itemHeight)
        .ceil()
        .clamp(0, totalItems - 1);

    // Calculate render range with buffer
    final renderStart = (firstVisibleIndex - bufferSize).clamp(
      0,
      totalItems - 1,
    );
    final renderEnd = (lastVisibleIndex + bufferSize).clamp(0, totalItems - 1);

    return VirtualizedRange(
      firstVisible: firstVisibleIndex,
      lastVisible: lastVisibleIndex,
      renderStart: renderStart,
      renderEnd: renderEnd,
    );
  }

  /// Calculate the maximum number of items that should be rendered
  int _calculateMaxRendered({
    required VirtualizedRange visibleRange,
    required int totalItems,
    required int batchSize,
  }) {
    // Start with initial batch, then expand as needed
    final minNeeded = visibleRange.renderEnd + 1;
    final batches = (minNeeded / batchSize).ceil();
    return (batches * batchSize).clamp(20, totalItems); // Minimum 20 items
  }
}

/// Data class to hold visible and render ranges
class VirtualizedRange {
  final int firstVisible;
  final int lastVisible;
  final int renderStart;
  final int renderEnd;

  VirtualizedRange({
    required this.firstVisible,
    required this.lastVisible,
    required this.renderStart,
    required this.renderEnd,
  });

  @override
  String toString() {
    return 'VirtualizedRange(visible: $firstVisible-$lastVisible, render: $renderStart-$renderEnd)';
  }
}

/// Fixed virtual list item with proper sizing
class FixedVirtualListItem extends StatelessComponent {
  final int index;
  final String title;
  final double itemHeight;

  FixedVirtualListItem({
    required this.index,
    required this.title,
    required this.itemHeight,
    super.key,
  });

  @override
  DCFComponentNode render() {
    return DCFView(
      layout: LayoutProps(
        height: itemHeight,
        padding: 16,
        flexDirection: YogaFlexDirection.row,
        alignItems: YogaAlign.center,
      ),
      styleSheet: StyleSheet(
        backgroundColor: index % 2 == 0 ? Colors.white : Colors.grey[50],
        borderWidth: 1,
        borderColor: Colors.blue[200],
      ),
      children: [
        DCFView(
          layout: LayoutProps(
            width: 48,
            height: 48,
            marginRight: 16,
            justifyContent: YogaJustifyContent.center,
            alignItems: YogaAlign.center,
          ),
          styleSheet: StyleSheet(
            backgroundColor: Colors.blue[400],
            borderRadius: 24,
          ),
          children: [
            DCFText(
              content: '$index',
              textProps: DCFTextProps(
                textAlign: "center",
                color: Colors.white,
                fontWeight: DCFFontWeight.bold,
              ),
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
            DCFText(
              content: title,
              textProps: DCFTextProps(
                fontWeight: DCFFontWeight.bold,
                fontSize: 16,
              ),
            ),
            DCFText(
              content:
                  'Index: $index | Position: ${(index * itemHeight).toStringAsFixed(0)}px',
              textProps: DCFTextProps(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }
}

// Keep the existing ListItem class for compatibility
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
