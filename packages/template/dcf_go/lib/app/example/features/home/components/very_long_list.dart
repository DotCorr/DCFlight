/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/dcflight.dart';
import 'package:dcf_primitives/dcf_primitives.dart';

/// VeryLongList - Performance test component with 100,000 items
/// Demonstrates virtualization capabilities with large datasets
class VeryLongList extends StatefulComponent {
  @override
  DCFComponentNode render() {
    // Generate 100,000 items for performance testing
    final itemsState = useState<List<ListItem>>(
      _generateItems(100000),
      'items',
    );

    final scrollMetricsState = useState<VirtualizedListMetrics?>(
      null,
      'metrics',
    );
    final scrollPositionState = useState<double>(0.0, 'scrollPosition');

    return DCFView(
      layout: LayoutProps(flex: 1, flexDirection: YogaFlexDirection.column),
      children: [
        // Performance metrics header
        DCFView(
          layout: LayoutProps(
            height: 60,
            padding: 16,
            flexDirection: YogaFlexDirection.row,
            justifyContent: YogaJustifyContent.spaceBetween,
            alignItems: YogaAlign.center,
          ),
          styleSheet: StyleSheet(
            backgroundColor: Colors.black.withOpacity(0.9),
          ),
          children: [
            DCFText(content: 'Items: ${itemsState.state.length}'),
            if (scrollMetricsState.state != null)
              DCFText(
                content: 'Rendered: ${scrollMetricsState.state!.renderedItems}',
              ),
            DCFText(
              content: 'Pos: ${scrollPositionState.state.toStringAsFixed(0)}',
            ),
          ],
        ),

        // Virtualized list
        DCFFlatList<ListItem>(
          data: itemsState.state,
          renderItem:
              (item, index) => VeryLongListItem(item: item, index: index),
          keyExtractor: (item, index) => item.id,
          itemSize: 80.0, // Fixed height for optimal performance
          horizontal: false,
          showsScrollIndicator: true,
          removeClippedSubviews: true,
          initialNumToRender: 15, // Start with minimal items
          layout: LayoutProps(flex: 1),
          onScroll: (event) {
            scrollPositionState.setState(event.contentOffset.y);
          },
          onMetrics: (metrics) {
            scrollMetricsState.setState(metrics);
          },
          onEndReached: () {
            // Simulate loading more data
            print('Reached end of list - could load more items');
          },
          onEndReachedThreshold: 0.1,
          separator: DCFView(
            layout: LayoutProps(height: 1),
            styleSheet: StyleSheet(backgroundColor: Colors.grey[300]),
          ),
          header: DCFView(
            layout: LayoutProps(
              height: 50,
              padding: 16,
              justifyContent: YogaJustifyContent.center,
            ),
            styleSheet: StyleSheet(backgroundColor: Colors.blue[50]),
            children: [DCFText(content: '📋 Very Long List Performance Test')],
          ),
          footer: DCFView(
            layout: LayoutProps(
              height: 50,
              padding: 16,
              justifyContent: YogaJustifyContent.center,
            ),
            styleSheet: StyleSheet(backgroundColor: Colors.green[50]),
            children: [
              DCFText(content: '🎉 End of ${itemsState.state.length} items!'),
            ],
          ),
        ),
      ],
    );
  }

  /// Generate items for the list
  List<ListItem> _generateItems(int count) {
    return List.generate(count, (index) {
      return ListItem(
        id: 'item_$index',
        title: 'Item #${index + 1}',
        subtitle: _getRandomSubtitle(index),
        value: (index + 1) * 1.5,
        isHighlighted: index % 100 == 0, // Highlight every 100th item
        category: _getCategory(index),
      );
    });
  }

  String _getRandomSubtitle(int index) {
    final subtitles = [
      'Performance test item',
      'Virtualized rendering',
      'Smooth scrolling',
      'Memory efficient',
      'React Native style',
      'High performance',
      'Optimized for mobile',
      'Viewport rendering',
    ];
    return subtitles[index % subtitles.length];
  }

  String _getCategory(int index) {
    final categories = ['Work', 'Personal', 'Important', 'Archive'];
    return categories[index % categories.length];
  }
}

/// Individual list item widget
class VeryLongListItem extends StatelessComponent {
  final ListItem item;
  final int index;

  VeryLongListItem({required this.item, required this.index});

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
        backgroundColor: item.isHighlighted ? Colors.yellow[100] : Colors.white,
      ),
      children: [
        // Icon/Avatar
        DCFView(
          layout: LayoutProps(width: 48, height: 48, marginRight: 16),
          styleSheet: StyleSheet(
            borderRadius: 24,
            backgroundColor: _getCategoryColor(item.category),
          ),
          children: [DCFText(content: _getCategoryIcon(item.category))],
        ),

        // Content
        DCFView(
          layout: LayoutProps(
            flex: 1,
            flexDirection: YogaFlexDirection.column,
            justifyContent: YogaJustifyContent.center,
          ),
          children: [
            DCFText(content: item.title),
            DCFText(content: item.subtitle),
          ],
        ),

        // Value and category
        DCFView(
          layout: LayoutProps(
            flexDirection: YogaFlexDirection.column,
            alignItems: YogaAlign.flexEnd,
          ),
          children: [
            DCFText(content: '\$${item.value.toStringAsFixed(2)}'),
            DCFView(
              layout: LayoutProps(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                marginTop: 4,
              ),
              styleSheet: StyleSheet(
                backgroundColor: _getCategoryColor(
                  item.category,
                ).withOpacity(0.2),
                borderRadius: 12,
              ),
              children: [DCFText(content: item.category)],
            ),
          ],
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Work':
        return Colors.blue;
      case 'Personal':
        return Colors.green;
      case 'Important':
        return Colors.red;
      case 'Archive':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getCategoryIcon(String category) {
    switch (category) {
      case 'Work':
        return '💼';
      case 'Personal':
        return '👤';
      case 'Important':
        return '⭐';
      case 'Archive':
        return '📦';
      default:
        return '📄';
    }
  }
}

/// Data model for list items
class ListItem {
  final String id;
  final String title;
  final String subtitle;
  final double value;
  final bool isHighlighted;
  final String category;

  ListItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.value,
    this.isHighlighted = false,
    required this.category,
  });
}
