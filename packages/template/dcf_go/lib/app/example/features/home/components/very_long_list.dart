/*
 * FINAL SOLUTION: Fix content size calculation in ScrollView
 * The issue was that content size wasn't being calculated properly
 */

import 'package:dcflight/dcflight.dart';

/// Fixed infinite scroll with proper content size calculation
class FixedInfiniteScroll extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final itemCountState = useState<int>(30, 'itemCount');
    final itemCount = itemCountState.state;

    const totalItems = 1000;
    const itemHeight = 70.0;
    const headerHeight = 100.0;

    // Calculate proper content size
    final totalContentHeight = headerHeight + (itemCount * itemHeight);

    print(
      '🔍 FixedInfiniteScroll: $itemCount items, content height: ${totalContentHeight.toStringAsFixed(0)}px',
    );

    final items = <DCFComponentNode>[];

    // Header
    items.add(
      DCFView(
        key: 'fixed_header',
        layout: LayoutProps(
          height: headerHeight,
          padding: 16,
          justifyContent: YogaJustifyContent.center,
        ),
        styleSheet: StyleSheet(backgroundColor: Colors.green[500]),
        children: [
          DCFText(
            content: 'FIXED INFINITE SCROLL',
            textProps: DCFTextProps(color: Colors.white, fontSize: 18),
          ),
          DCFText(
            content: 'Items: $itemCount of $totalItems',
            textProps: DCFTextProps(color: Colors.white, fontSize: 14),
          ),
          DCFText(
            content: 'Content: ${totalContentHeight.toStringAsFixed(0)}px',
            textProps: DCFTextProps(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );

    // Add items
    for (int i = 0; i < itemCount; i++) {
      items.add(
        DCFView(
          key: 'fixed_item_$i',
          layout: LayoutProps(
            height: itemHeight,
            padding: 16,
            flexDirection: YogaFlexDirection.row,
            alignItems: YogaAlign.center,
          ),
          styleSheet: StyleSheet(
            backgroundColor: i % 2 == 0 ? Colors.blue[200] : Colors.purple[200],
            borderWidth: 1,
            borderColor: Colors.grey[300],
          ),
          children: [
            DCFView(
              layout: LayoutProps(
                width: 50,
                height: 50,
                marginRight: 16,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: Colors.deepOrange[400],
                borderRadius: 25,
              ),
              children: [
                DCFText(
                  content: '$i',
                  textProps: DCFTextProps(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
            DCFView(
              layout: LayoutProps(flex: 1),
              children: [
                DCFText(
                  content: 'Fixed Item ${i + 1}',
                  textProps: DCFTextProps(fontSize: 16),
                ),
                DCFText(
                  content:
                      'Proper content size • \$${(i * 15.0).toStringAsFixed(1)}',
                  textProps: DCFTextProps(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFSafeArea(
          layout: LayoutProps(flex: 1),
          children: [
            DCFScrollView(
              layout: LayoutProps(flex: 1),

              // 🚀 KEY FIX: Set explicit content size
              command: ScrollViewCommand(
                setContentSize: SetContentSizeCommand(
                  width: 400,
                  height: totalContentHeight,
                ),
              ),

              onScroll: (event) {
                final contentOffset =
                    event['contentOffset'] as Map<dynamic, dynamic>?;
                final contentSize =
                    event['contentSize'] as Map<dynamic, dynamic>?;
                final layoutMeasurement =
                    event['layoutMeasurement'] as Map<dynamic, dynamic>?;

                if (contentOffset != null &&
                    contentSize != null &&
                    layoutMeasurement != null) {
                  final scrollY =
                      (contentOffset['y'] as num?)?.toDouble() ?? 0.0;
                  final contentHeight =
                      (contentSize['height'] as num?)?.toDouble() ?? 0.0;
                  final screenHeight =
                      (layoutMeasurement['height'] as num?)?.toDouble() ?? 0.0;

                  final distanceFromBottom =
                      contentHeight - (scrollY + screenHeight);

                  // Load more when close to bottom
                  if (distanceFromBottom < 200 && itemCount < totalItems) {
                    final newCount = (itemCount + 25).clamp(0, totalItems);
                    print('🚀 Loading more: $itemCount -> $newCount');

                    // Use Future.microtask to avoid setState during scroll
                    Future.microtask(() {
                      itemCountState.setState(newCount);
                    });
                  }

                  // Debug logging
                  if (scrollY.toInt() % 500 == 0) {
                    print(
                      '🔍 Fixed scroll: ${scrollY.toStringAsFixed(0)}px / ${contentHeight.toStringAsFixed(0)}px',
                    );
                  }
                }
              },

              children: items,
            ),
          ],
        ),
      ],
    );
  }
}
