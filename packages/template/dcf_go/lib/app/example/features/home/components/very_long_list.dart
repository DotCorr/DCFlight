/*
 * Proper FlatList test app using the FIXED DCFVirtualizedList
 * No more workarounds - this uses the actual fixed virtualization
 */

import 'package:dcflight/dcflight.dart';

/// Main test app that properly uses DCFFlatList with fixed virtualization
class ProperVirtualizedApp extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final testModeState = useState<int>(0, 'testMode');
    final testMode = testModeState.state;

    final tests = [
      ('Large Dataset (1000 items)', () => LargeDatasetFlatList()),
      ('Variable Heights', () => VariableHeightFlatList()),
      ('With Headers/Footers', () => HeaderFooterFlatList()),
      ('Multi-Column Grid', () => MultiColumnFlatList()),
    ];

    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFSafeArea(
          layout: LayoutProps(flex: 1),
          children: [
            // Test selector
            DCFView(
              layout: LayoutProps(
                height: 100,
                padding: 16,
                flexDirection: YogaFlexDirection.column,
              ),
              styleSheet: StyleSheet(backgroundColor: Colors.grey[100]),
              children: [
                DCFText(
                  content: 'Fixed DCFVirtualizedList Tests',
                  textProps: DCFTextProps(
                    fontWeight: DCFFontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                DCFText(
                  content: 'Current: ${tests[testMode].$1}',
                  textProps: DCFTextProps(fontSize: 14),
                ),
                DCFView(
                  layout: LayoutProps(
                    flexDirection: YogaFlexDirection.row,
                    marginTop: 8,
                  ),
                  children: [
                    for (int i = 0; i < tests.length; i++)
                      DCFTouchableOpacity(
                        layout: LayoutProps(padding: 8, marginRight: 8),
                        styleSheet: StyleSheet(
                          backgroundColor:
                              i == testMode
                                  ? Colors.blue[500]
                                  : Colors.grey[300],
                          borderRadius: 6,
                        ),
                        onPress: (v) => testModeState.setState(i),
                        children: [
                          DCFText(
                            content: '${i + 1}',
                            textProps: DCFTextProps(
                              color:
                                  i == testMode ? Colors.white : Colors.black,
                              // fontWeight: "bold",
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),

            // Current test
            tests[testMode].$2(),
          ],
        ),
      ],
    );
  }
}

/// Test 1: Large dataset with 1000 items
class LargeDatasetFlatList extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final data = useMemo(
      () => List.generate(
        1000,
        (index) => TestItem(
          id: 'large_$index',
          title: 'Large Dataset Item ${index + 1}',
          subtitle: 'This is item number $index',
          category: ['Work', 'Personal', 'Important', 'Urgent'][index % 4],
          value: (index + 1) * 10.5,
        ),
      ),
      dependencies: [],
    );

    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFView(
          layout: LayoutProps(
            height: 60,
            padding: 16,
            justifyContent: YogaJustifyContent.center,
          ),
          styleSheet: StyleSheet(backgroundColor: Colors.blue[100]),
          children: [
            DCFText(content: 'Large Dataset Test - ${data.length} items'),
          ],
        ),

        DCFFlatList<TestItem>(
          data: data,
          renderItem:
              (item, index) => LargeDatasetItem(index: index, item: item),
          keyExtractor: (item, index) => item.id,
          debug: true, // Enable debug to see virtualization working
          // Virtualization settings
          initialNumToRender: 15,
          windowSize: 25,
          maxToRenderPerBatch: 8,

          layout: LayoutProps(flex: 1),

          // Add separator for better visual distinction
          itemSeparatorComponent: DCFView(
            layout: LayoutProps(height: 1),
            styleSheet: StyleSheet(backgroundColor: Colors.grey[200]),
            children: [],
          ),

          // End reached callback
          onEndReached: () {
            print('🔥 End reached! Could load more data here...');
          },
          onEndReachedThreshold: 0.1,
        ),
      ],
    );
  }
}

/// Test 2: Variable height items
class VariableHeightFlatList extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final data = useMemo(
      () => List.generate(
        300,
        (index) => VariableTestItem(
          id: 'var_$index',
          title: 'Variable Item ${index + 1}',
          content: _generateVariableContent(index),
          height: _getVariableHeight(index),
        ),
      ),
      dependencies: [],
    );

    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFView(
          layout: LayoutProps(
            height: 60,
            padding: 16,
            justifyContent: YogaJustifyContent.center,
          ),
          styleSheet: StyleSheet(backgroundColor: Colors.green[100]),
          children: [
            DCFText(content: 'Variable Heights Test - ${data.length} items'),
          ],
        ),

        DCFFlatList<VariableTestItem>(
          data: data,
          renderItem:
              (item, index) => VariableHeightItem(index: index, item: item),
          keyExtractor: (item, index) => item.id,
          debug: true,

          // For variable heights, provide getItemLayout for better performance
          getItemLayout:
              (data, index) => {
                'length': data[index].height,
                'offset':
                    0.0, // Would calculate cumulative offset for perfect scrolling
                'index': index,
              },

          layout: LayoutProps(flex: 1),
        ),
      ],
    );
  }

  String _generateVariableContent(int index) {
    if (index % 7 == 0) {
      return 'This is a very long content item that spans multiple lines and contains a lot of text to demonstrate variable height items in the virtualized list. It should make the item much taller than others.';
    } else if (index % 4 == 0) {
      return 'Medium length content with some additional details and information.';
    } else if (index % 2 == 0) {
      return 'Short content item.';
    } else {
      return 'Tiny.';
    }
  }

  double _getVariableHeight(int index) {
    if (index % 7 == 0) return 120.0;
    if (index % 4 == 0) return 80.0;
    if (index % 2 == 0) return 60.0;
    return 40.0;
  }
}

/// Test 3: Headers and footers
class HeaderFooterFlatList extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final data = useMemo(
      () => List.generate(
        200,
        (index) => TestItem(
          id: 'header_$index',
          title: 'Header Test Item ${index + 1}',
          subtitle: 'Item with headers and footers',
          category: 'Test',
          value: index.toDouble(),
        ),
      ),
      dependencies: [],
    );

    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFView(
          layout: LayoutProps(
            height: 60,
            padding: 16,
            justifyContent: YogaJustifyContent.center,
          ),
          styleSheet: StyleSheet(backgroundColor: Colors.purple[100]),
          children: [
            DCFText(content: 'Headers & Footers Test - ${data.length} items'),
          ],
        ),

        DCFFlatList<TestItem>(
          data: data,
          renderItem: (item, index) => StandardItem(index: index, item: item),
          keyExtractor: (item, index) => item.id,
          debug: true,

          layout: LayoutProps(flex: 1),

          // List header
          listHeaderComponent: DCFView(
            layout: LayoutProps(
              height: 80,
              padding: 20,
              justifyContent: YogaJustifyContent.center,
              alignItems: YogaAlign.center,
            ),
            styleSheet: StyleSheet(
              backgroundColor: Colors.blue[500],
              borderRadius: 12,
              // margin: 8,
            ),
            children: [
              DCFText(
                content: '📋 List Header',
                textProps: DCFTextProps(
                  color: Colors.white,
                  // fontWeight: "bold",
                  fontSize: 18,
                ),
              ),
              DCFText(
                content: 'This header scrolls with the content',
                textProps: DCFTextProps(color: Colors.white, fontSize: 14),
              ),
            ],
          ),

          // List footer
          listFooterComponent: DCFView(
            layout: LayoutProps(
              height: 80,
              padding: 20,
              justifyContent: YogaJustifyContent.center,
              alignItems: YogaAlign.center,
            ),
            styleSheet: StyleSheet(
              backgroundColor: Colors.green[500],
              borderRadius: 12,
              // margin: 8,
            ),
            children: [
              DCFText(
                content: '🎯 List Footer',
                textProps: DCFTextProps(
                  color: Colors.white,
                  // fontWeight: "bold",
                  fontSize: 18,
                ),
              ),
              DCFText(
                content: 'End of ${data.length} items',
                textProps: DCFTextProps(color: Colors.white, fontSize: 14),
              ),
            ],
          ),

          // Item separator
          itemSeparatorComponent: DCFView(
            layout: LayoutProps(height: 2),
            styleSheet: StyleSheet(backgroundColor: Colors.grey[300]),
            children: [],
          ),
        ),
      ],
    );
  }
}

/// Test 4: Multi-column grid
class MultiColumnFlatList extends StatefulComponent {
  @override
  DCFComponentNode render() {
    final data = useMemo(
      () => List.generate(
        150,
        (index) => GridTestItem(
          id: 'grid_$index',
          title: 'Grid ${index + 1}',
          color: _getGridColor(index),
        ),
      ),
      dependencies: [],
    );

    return DCFView(
      layout: LayoutProps(flex: 1),
      children: [
        DCFView(
          layout: LayoutProps(
            height: 60,
            padding: 16,
            justifyContent: YogaJustifyContent.center,
          ),
          styleSheet: StyleSheet(backgroundColor: Colors.orange[100]),
          children: [
            DCFText(content: 'Multi-Column Grid Test - ${data.length} items'),
          ],
        ),

        DCFFlatList<GridTestItem>(
          data: data,
          renderItem: (item, index) => GridItem(index: index, item: item),
          keyExtractor: (item, index) => item.id,
          debug: true,

          // Multi-column settings
          numColumns: 3,
          columnWrapperLayout: LayoutProps(
            padding: 4,
            justifyContent: YogaJustifyContent.spaceBetween,
          ),

          layout: LayoutProps(flex: 1),
        ),
      ],
    );
  }

  Color _getGridColor(int index) {
    final colors = [
      Colors.red[300]!,
      Colors.blue[300]!,
      Colors.green[300]!,
      Colors.yellow[300]!,
      Colors.purple[300]!,
      Colors.orange[300]!,
    ];
    return colors[index % colors.length];
  }
}

// Data classes
class TestItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final double value;

  TestItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.value,
  });
}

class VariableTestItem {
  final String id;
  final String title;
  final String content;
  final double height;

  VariableTestItem({
    required this.id,
    required this.title,
    required this.content,
    required this.height,
  });
}

class GridTestItem {
  final String id;
  final String title;
  final Color color;

  GridTestItem({required this.id, required this.title, required this.color});
}

// Item components
class LargeDatasetItem extends StatelessComponent {
  final int index;
  final TestItem item;

  LargeDatasetItem({required this.index, required this.item, super.key});

  @override
  DCFComponentNode render() {
    return DCFView(
      layout: LayoutProps(
        height: 70,
        padding: 16,
        flexDirection: YogaFlexDirection.row,
        alignItems: YogaAlign.center,
      ),
      styleSheet: StyleSheet(
        backgroundColor: index % 2 == 0 ? Colors.white : Colors.grey[50],
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
            backgroundColor: _getCategoryColor(item.category),
            borderRadius: 25,
          ),
          children: [
            DCFText(
              content: '$index',
              textProps: DCFTextProps(
                color: Colors.white,
                // fontWeight: "bold",
                fontSize: 14,
              ),
            ),
          ],
        ),
        DCFView(
          layout: LayoutProps(flex: 1),
          children: [
            DCFText(
              content: item.title,
              textProps: DCFTextProps(
                // fontWeight: "600",
                fontSize: 16,
              ),
            ),
            DCFText(
              content: '${item.subtitle} • ${item.category}',
              textProps: DCFTextProps(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        DCFText(
          content: '\$${item.value.toStringAsFixed(1)}',
          textProps: DCFTextProps(
            // fontWeight: "bold",
            color: Colors.green[600],
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Work':
        return Colors.blue[500]!;
      case 'Personal':
        return Colors.green[500]!;
      case 'Important':
        return Colors.red[500]!;
      case 'Urgent':
        return Colors.orange[500]!;
      default:
        return Colors.grey[500]!;
    }
  }
}

class VariableHeightItem extends StatelessComponent {
  final int index;
  final VariableTestItem item;

  VariableHeightItem({required this.index, required this.item, super.key});

  @override
  DCFComponentNode render() {
    return DCFView(
      layout: LayoutProps(
        height: item.height,
        padding: 16,
        justifyContent: YogaJustifyContent.center,
      ),
      styleSheet: StyleSheet(
        backgroundColor: _getHeightColor(item.height),
        borderWidth: 1,
        borderColor: Colors.grey[300],
        // margin: 4,
        borderRadius: 8,
      ),
      children: [
        DCFText(
          content: item.title,
          textProps: DCFTextProps(
            // fontWeight: "bold",
            fontSize: 16,
          ),
        ),
        DCFText(
          content: item.content,
          textProps: DCFTextProps(fontSize: 14, color: Colors.grey[700]),
        ),
        DCFText(
          content: 'Height: ${item.height.toInt()}px',
          textProps: DCFTextProps(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Color _getHeightColor(double height) {
    if (height > 100) return Colors.red[50]!;
    if (height > 70) return Colors.yellow[50]!;
    if (height > 50) return Colors.green[50]!;
    return Colors.blue[50]!;
  }
}

class StandardItem extends StatelessComponent {
  final int index;
  final TestItem item;

  StandardItem({required this.index, required this.item, super.key});

  @override
  DCFComponentNode render() {
    return DCFView(
      layout: LayoutProps(
        height: 60,
        padding: 16,
        flexDirection: YogaFlexDirection.row,
        alignItems: YogaAlign.center,
      ),
      styleSheet: StyleSheet(backgroundColor: Colors.white),
      children: [
        DCFText(
          content: item.title,
          textProps: DCFTextProps(
            // fontWeight: "600",
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class GridItem extends StatelessComponent {
  final int index;
  final GridTestItem item;

  GridItem({required this.index, required this.item, super.key});

  @override
  DCFComponentNode render() {
    return DCFView(
      layout: LayoutProps(
        height: 80,
        justifyContent: YogaJustifyContent.center,
        alignItems: YogaAlign.center,
      ),
      styleSheet: StyleSheet(
        backgroundColor: item.color,
        borderRadius: 8,
        // margin: 4,
      ),
      children: [
        DCFText(
          content: item.title,
          textProps: DCFTextProps(
            color: Colors.white,
            // fontWeight: "bold",
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
