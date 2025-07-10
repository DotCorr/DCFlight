/*
 * TARGETED FIX: The issue is that render window updates during scroll aren't working
 *
 * Root cause: The useState for renderWindow isn't triggering re-renders properly
 * when the scroll handler updates it during scroll events.
 */

import 'package:dcflight/dcflight.dart';

/// Fixed test that should work beyond 20 items
class FixedVirtualizationTest extends StatefulComponent {
  @override
  DCFComponentNode render() {
    print('🔍 FixedVirtualizationTest: Starting render');

    // Create test data
    final data = List.generate(
      1000,
      (index) =>
          SimpleItem(id: 'fixed_item_$index', title: 'Fixed Item ${index + 1}'),
    );

    // 🚀 KEY FIX: Use a more aggressive state update strategy
    final renderRangeState = useState<RenderRange>(
      RenderRange(start: 0, end: 19), // Start with 20 items
      'renderRange',
    );
    final scrollOffsetState = useState<double>(0.0, 'scrollOffset');

    final renderRange = renderRangeState.state;
    final scrollOffset = scrollOffsetState.state;

    print('🔍 Current render range: ${renderRange.start}-${renderRange.end}');
    print('🔍 Current scroll offset: ${scrollOffset.toStringAsFixed(0)}px');

    // Calculate which items should be visible based on scroll
    const double itemHeight = 70.0;
    const double viewportHeight = 600.0; // Estimate

    final firstVisibleIndex = (scrollOffset / itemHeight).floor().clamp(
      0,
      data.length - 1,
    );
    final lastVisibleIndex = ((scrollOffset + viewportHeight) / itemHeight)
        .ceil()
        .clamp(0, data.length - 1);

    print('🔍 Visible range should be: $firstVisibleIndex-$lastVisibleIndex');

    // Build children for current render range
    final children = <DCFComponentNode>[];

    // Add header
    children.add(
      DCFView(
        key: 'fixed_header',
        layout: LayoutProps(
          height: 80,
          padding: 16,
          justifyContent: YogaJustifyContent.center,
        ),
        styleSheet: StyleSheet(backgroundColor: Colors.blue[100]),
        children: [
          DCFText(content: 'Fixed Virtualization Test'),
          DCFText(
            content:
                'Rendering ${renderRange.end - renderRange.start + 1} items (${renderRange.start}-${renderRange.end})',
          ),
          DCFText(
            content:
                'Scroll: ${scrollOffset.toStringAsFixed(0)}px | Visible: $firstVisibleIndex-$lastVisibleIndex',
          ),
        ],
      ),
    );

    // Add spacer before rendered items
    if (renderRange.start > 0) {
      final spacerHeight = renderRange.start * itemHeight;
      children.add(
        DCFView(
          key: 'before_spacer',
          layout: LayoutProps(height: spacerHeight),
          styleSheet: StyleSheet(backgroundColor: Colors.red[100]),
          children: [
            DCFView(
              layout: LayoutProps(
                padding: 8,
                justifyContent: YogaJustifyContent.center,
              ),
              children: [
                DCFText(
                  content:
                      'SPACER: ${renderRange.start} items above (${spacerHeight.toStringAsFixed(0)}px)',
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Add actual items
    int renderedCount = 0;
    for (
      int i = renderRange.start;
      i <= renderRange.end && i < data.length;
      i++
    ) {
      children.add(
        DCFView(
          key: 'fixed_item_$i',
          layout: LayoutProps(
            height: itemHeight,
            padding: 16,
            flexDirection: YogaFlexDirection.row,
            alignItems: YogaAlign.center,
          ),
          styleSheet: StyleSheet(
            backgroundColor: i % 2 == 0 ? Colors.white : Colors.grey[50],
            borderWidth: 1,
            borderColor: Colors.grey[300],
          ),
          children: [
            DCFView(
              layout: LayoutProps(
                width: 40,
                height: 40,
                marginRight: 12,
                justifyContent: YogaJustifyContent.center,
                alignItems: YogaAlign.center,
              ),
              styleSheet: StyleSheet(
                backgroundColor: _getIndexColor(i),
                borderRadius: 20,
              ),
              children: [
                DCFText(
                  content: '$i',
                  textProps: DCFTextProps(
                    color: Colors.white,
                    // fontWeight: "bold",
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            DCFView(
              layout: LayoutProps(flex: 1),
              children: [
                DCFText(content: data[i].title),
                DCFText(
                  content:
                      'Index: $i | Y: ${(i * itemHeight).toStringAsFixed(0)}px',
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
      renderedCount++;
    }

    print('🔍 Actually rendered $renderedCount items');

    // Add spacer after rendered items
    if (renderRange.end < data.length - 1) {
      final remainingItems = data.length - 1 - renderRange.end;
      final spacerHeight = remainingItems * itemHeight;
      children.add(
        DCFView(
          key: 'after_spacer',
          layout: LayoutProps(height: spacerHeight),
          styleSheet: StyleSheet(backgroundColor: Colors.green[100]),
          children: [
            DCFView(
              layout: LayoutProps(
                padding: 8,
                justifyContent: YogaJustifyContent.center,
              ),
              children: [
                DCFText(
                  content:
                      'SPACER: $remainingItems items below (${spacerHeight.toStringAsFixed(0)}px)',
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Add footer
    children.add(
      DCFView(
        key: 'fixed_footer',
        layout: LayoutProps(
          height: 60,
          padding: 16,
          justifyContent: YogaJustifyContent.center,
        ),
        styleSheet: StyleSheet(backgroundColor: Colors.purple[100]),
        children: [
          DCFText(content: 'End of list - ${data.length} total items'),
        ],
      ),
    );

    // 🚀 KEY FIX: More aggressive scroll handler that forces updates
    void handleScroll(Map<dynamic, dynamic> event) {
      final contentOffset = event['contentOffset'] as Map<dynamic, dynamic>?;
      if (contentOffset == null) return;

      final newOffset = (contentOffset['y'] as num?)?.toDouble() ?? 0.0;
      scrollOffsetState.setState(newOffset);

      // Calculate new render range based on scroll position
      final buffer = 30; // Render 30 items before and after visible area
      final newFirstVisible = (newOffset / itemHeight).floor().clamp(
        0,
        data.length - 1,
      );
      final newLastVisible = ((newOffset + viewportHeight) / itemHeight)
          .ceil()
          .clamp(0, data.length - 1);

      final newStart = (newFirstVisible - buffer).clamp(0, data.length - 1);
      final newEnd = (newLastVisible + buffer).clamp(0, data.length - 1);

      final newRange = RenderRange(start: newStart, end: newEnd);

      // 🚀 AGGRESSIVE UPDATE: Update render range if ANY change is needed
      if (newRange.start != renderRange.start ||
          newRange.end != renderRange.end) {
        print(
          '🚀 UPDATING RENDER RANGE: ${renderRange.start}-${renderRange.end} -> ${newRange.start}-${newRange.end}',
        );
        print('🚀 Scroll offset: ${newOffset.toStringAsFixed(0)}px');
        print('🚀 Visible items: $newFirstVisible-$newLastVisible');

        renderRangeState.setState(newRange);
      }
    }

    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFSafeArea(
          layout: LayoutProps(flex: 1),
          children: [
            DCFScrollView(
              layout: LayoutProps(flex: 1),
              onScroll: handleScroll,
              children: children,
            ),
          ],
        ),
      ],
    );
  }

  Color _getIndexColor(int index) {
    final colors = [
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.purple[400]!,
      Colors.red[400]!,
      Colors.teal[400]!,
    ];
    return colors[index % colors.length];
  }
}

/// Simple data class
class SimpleItem {
  final String id;
  final String title;

  SimpleItem({required this.id, required this.title});
}

/// Helper class for render range
class RenderRange {
  final int start;
  final int end;

  RenderRange({required this.start, required this.end});

  @override
  String toString() => 'RenderRange($start-$end)';
}

/// Test to compare with broken DCFVirtualizedList
class BrokenVirtualizedListTest extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final data = List.generate(
      1000,
      (index) => SimpleItem(
        id: 'broken_item_$index',
        title: 'Broken Item ${index + 1}',
      ),
    );

    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFSafeArea(
          layout: LayoutProps(flex: 1),
          children: [
            DCFView(
              layout: LayoutProps(
                height: 60,
                padding: 16,
                justifyContent: YogaJustifyContent.center,
              ),
              styleSheet: StyleSheet(backgroundColor: Colors.red[100]),
              children: [DCFText(content: 'Broken DCFVirtualizedList Test')],
            ),

            // This should show the same issue you're experiencing
            DCFVirtualizedList(
              data: data,
              getItem: (data, index) => (data as List)[index],
              getItemCount: (data) => (data as List).length,
              renderItem: ({required item, required index}) {
                return DCFView(
                  layout: LayoutProps(
                    height: 70,
                    padding: 16,
                    justifyContent: YogaJustifyContent.center,
                  ),
                  styleSheet: StyleSheet(
                    backgroundColor:
                        index % 2 == 0 ? Colors.blue[50] : Colors.green[50],
                    borderWidth: 1,
                    borderColor: Colors.grey[300],
                  ),
                  children: [DCFText(content: (item as SimpleItem).title)],
                );
              },
              debug: true,
              layout: LayoutProps(flex: 1),
            ),
          ],
        ),
      ],
    );
  }
}

/// Master test to compare fixed vs broken
class ComparisonTest extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final useFixedState = useState<bool>(true, 'useFixed');
    final useFixed = useFixedState.state;

    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFSafeArea(
          layout: LayoutProps(flex: 1),
          children: [
            // Toggle button
            DCFView(
              layout: LayoutProps(
                height: 80,
                padding: 16,
                justifyContent: YogaJustifyContent.center,
              ),
              styleSheet: StyleSheet(backgroundColor: Colors.grey[200]),
              children: [
                DCFTouchableOpacity(
                  layout: LayoutProps(padding: 12),
                  styleSheet: StyleSheet(
                    backgroundColor:
                        useFixed ? Colors.green[300] : Colors.red[300],
                    borderRadius: 8,
                  ),
                  onPress: (v) => useFixedState.setState(!useFixed),
                  children: [
                    DCFText(
                      content:
                          useFixed
                              ? 'Using FIXED Implementation'
                              : 'Using BROKEN Implementation',
                      textProps: DCFTextProps(
                        color: Colors.white,
                        // fontWeight: "bold",
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Show the selected test
            useFixed ? FixedVirtualizationTest() : BrokenVirtualizedListTest(),
          ],
        ),
      ],
    );
  }
}
