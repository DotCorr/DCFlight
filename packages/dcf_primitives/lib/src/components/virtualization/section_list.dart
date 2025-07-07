/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:equatable/equatable.dart';
import 'package:dcflight/dcflight.dart';
import 'virtualized_list.dart';

/// SectionList - High-performance sectioned list component
/// Renders data in sections with headers and footers
/// Built on top of VirtualizedList for optimal performance
class DCFSectionList<T> extends StatelessComponent
    with EquatableMixin
    implements ComponentPriorityInterface {
  @override
  ComponentPriority get priority => ComponentPriority.high;

  /// List of sections
  final List<SectionData<T>> sections;

  /// Function to render each item
  final DCFComponentNode Function(T item, int index, int sectionIndex)
      renderItem;

  /// Function to render section headers
  final DCFComponentNode Function(SectionData<T> section, int sectionIndex)?
      renderSectionHeader;

  /// Function to render section footers
  final DCFComponentNode Function(SectionData<T> section, int sectionIndex)?
      renderSectionFooter;

  /// Function to extract unique key for each item
  final String Function(T item, int index, int sectionIndex)? keyExtractor;

  /// Whether to make section headers sticky
  final bool stickySectionHeaders;

  /// Whether to scroll horizontally
  final bool horizontal;

  /// Layout and style properties
  final LayoutProps layout;
  final StyleSheet styleSheet;

  /// Scroll behavior properties
  final bool showsScrollIndicator;
  final bool scrollEnabled;
  final bool bounces;
  final bool pagingEnabled;

  /// Estimated size of each item (for optimization)
  final double? itemSize;

  /// Estimated size of section headers
  final double? sectionHeaderSize;

  /// Estimated size of section footers
  final double? sectionFooterSize;

  /// Function to get dynamic size of each item
  final double Function(T item, int index, int sectionIndex)? getItemSize;

  /// Function to get dynamic size of section headers
  final double Function(SectionData<T> section, int sectionIndex)?
      getSectionHeaderSize;

  /// Function to get dynamic size of section footers
  final double Function(SectionData<T> section, int sectionIndex)?
      getSectionFooterSize;

  /// Initial number of items to render
  final int? initialNumToRender;

  /// Whether to remove clipped subviews for memory optimization
  final bool removeClippedSubviews;

  /// Whether the list is inverted (items rendered from bottom to top)
  final bool inverted;

  /// Event handlers
  final Function(VirtualizedListScrollEvent)? onScroll;
  final Function(VirtualizedListScrollEvent)? onScrollBeginDrag;
  final Function(VirtualizedListScrollEvent)? onScrollEndDrag;
  final Function(VirtualizedListScrollEvent)? onMomentumScrollEnd;

  /// Called when user scrolls close to the end
  final Function()? onEndReached;

  /// How close to the end before onEndReached is called (0-1)
  final double onEndReachedThreshold;

  /// Component to render at the top of the list
  final DCFComponentNode? header;

  /// Component to render at the bottom of the list
  final DCFComponentNode? footer;

  /// Component to render when the list is empty
  final DCFComponentNode? emptyState;

  /// Component to render between items in the same section
  final DCFComponentNode? itemSeparator;

  /// Component to render between sections
  final DCFComponentNode? sectionSeparator;

  /// Function to render custom separator between items
  final DCFComponentNode Function(int index, int sectionIndex)?
      itemSeparatorBuilder;

  /// Function to render custom separator between sections
  final DCFComponentNode Function(int sectionIndex)? sectionSeparatorBuilder;

  /// Refresh control
  final bool refreshing;
  final Function()? onRefresh;

  /// Commands for imperative operations
  final SectionListCommand? command;

  /// Whether to enable debug mode
  final bool debug;

  /// Additional props for customization
  final Map<String, dynamic>? additionalProps;

  /// Performance monitoring
  final Function(VirtualizedListMetrics)? onMetrics;

  /// Section visibility callback
  final Function(List<SectionVisibilityInfo>)? onSectionVisibilityChanged;

  const DCFSectionList({
    required this.sections,
    required this.renderItem,
    this.renderSectionHeader,
    this.renderSectionFooter,
    this.keyExtractor,
    this.stickySectionHeaders = true,
    this.horizontal = false,
    this.layout = const LayoutProps(),
    this.styleSheet = const StyleSheet(),
    this.showsScrollIndicator = true,
    this.scrollEnabled = true,
    this.bounces = true,
    this.pagingEnabled = false,
    this.itemSize,
    this.sectionHeaderSize,
    this.sectionFooterSize,
    this.getItemSize,
    this.getSectionHeaderSize,
    this.getSectionFooterSize,
    this.initialNumToRender,
    this.removeClippedSubviews = true,
    this.inverted = false,
    this.onScroll,
    this.onScrollBeginDrag,
    this.onScrollEndDrag,
    this.onMomentumScrollEnd,
    this.onEndReached,
    this.onEndReachedThreshold = 0.1,
    this.header,
    this.footer,
    this.emptyState,
    this.itemSeparator,
    this.sectionSeparator,
    this.itemSeparatorBuilder,
    this.sectionSeparatorBuilder,
    this.refreshing = false,
    this.onRefresh,
    this.command,
    this.debug = false,
    this.additionalProps,
    this.onMetrics,
    this.onSectionVisibilityChanged,
    super.key,
  });

  @override
  DCFComponentNode render() {
    // Handle empty state
    if (sections.isEmpty) {
      if (emptyState != null) {
        return DCFView(
          layout: layout,
          styleSheet: styleSheet,
          children: [emptyState!],
        );
      }
      return DCFVirtualizedList(
        itemCount: 0,
        renderItem: (index, info) => DCFView(children: []),
        horizontal: horizontal,
        layout: layout,
        styleSheet: styleSheet,
        showsScrollIndicator: showsScrollIndicator,
        scrollEnabled: scrollEnabled,
        bounces: bounces,
        pagingEnabled: pagingEnabled,
        debug: debug,
      );
    }

    // Build flat item list from sections
    final flatItems = <_FlatItem<T>>[];
    final sectionMap = <int, int>{}; // virtualizedIndex -> sectionIndex
    final itemMap = <int, _ItemInfo>{}; // virtualizedIndex -> item info

    // Add header if present
    if (header != null) {
      flatItems.add(_FlatItem<T>(
        type: _FlatItemType.header,
        index: 0,
        sectionIndex: -1,
      ));
    }

    // Process sections
    for (int sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];

      // Add section header if present
      if (renderSectionHeader != null) {
        final virtualizedIndex = flatItems.length;
        flatItems.add(_FlatItem<T>(
          type: _FlatItemType.sectionHeader,
          index: virtualizedIndex,
          sectionIndex: sectionIndex,
        ));
        sectionMap[virtualizedIndex] = sectionIndex;
      }

      // Add section items
      for (int itemIndex = 0; itemIndex < section.data.length; itemIndex++) {
        final virtualizedIndex = flatItems.length;
        flatItems.add(_FlatItem<T>(
          type: _FlatItemType.item,
          index: virtualizedIndex,
          sectionIndex: sectionIndex,
          itemIndex: itemIndex,
          data: section.data[itemIndex],
        ));
        itemMap[virtualizedIndex] = _ItemInfo(
          sectionIndex: sectionIndex,
          itemIndex: itemIndex,
          item: section.data[itemIndex],
        );

        // Add item separator if not the last item in section
        if (itemIndex < section.data.length - 1 &&
            (itemSeparator != null || itemSeparatorBuilder != null)) {
          flatItems.add(_FlatItem<T>(
            type: _FlatItemType.itemSeparator,
            index: flatItems.length,
            sectionIndex: sectionIndex,
            itemIndex: itemIndex,
          ));
        }
      }

      // Add section footer if present
      if (renderSectionFooter != null) {
        final virtualizedIndex = flatItems.length;
        flatItems.add(_FlatItem<T>(
          type: _FlatItemType.sectionFooter,
          index: virtualizedIndex,
          sectionIndex: sectionIndex,
        ));
        sectionMap[virtualizedIndex] = sectionIndex;
      }

      // Add section separator if not the last section
      if (sectionIndex < sections.length - 1 &&
          (sectionSeparator != null || sectionSeparatorBuilder != null)) {
        flatItems.add(_FlatItem<T>(
          type: _FlatItemType.sectionSeparator,
          index: flatItems.length,
          sectionIndex: sectionIndex,
        ));
      }
    }

    // Add footer if present
    if (footer != null) {
      flatItems.add(_FlatItem<T>(
        type: _FlatItemType.footer,
        index: flatItems.length,
        sectionIndex: -1,
      ));
    }

    // Build render function
    DCFComponentNode renderVirtualizedItem(
        int index, VirtualizedListItemInfo info) {
      if (index < 0 || index >= flatItems.length) {
        return DCFView(children: []);
      }

      final flatItem = flatItems[index];

      switch (flatItem.type) {
        case _FlatItemType.header:
          return header!;

        case _FlatItemType.footer:
          return footer!;

        case _FlatItemType.sectionHeader:
          final section = sections[flatItem.sectionIndex];
          return renderSectionHeader!(section, flatItem.sectionIndex);

        case _FlatItemType.sectionFooter:
          final section = sections[flatItem.sectionIndex];
          return renderSectionFooter!(section, flatItem.sectionIndex);

        case _FlatItemType.item:
          return renderItem(
            flatItem.data as T,
            flatItem.itemIndex!,
            flatItem.sectionIndex,
          );

        case _FlatItemType.itemSeparator:
          if (itemSeparatorBuilder != null) {
            return itemSeparatorBuilder!(
              flatItem.itemIndex!,
              flatItem.sectionIndex,
            );
          }
          return itemSeparator!;

        case _FlatItemType.sectionSeparator:
          if (sectionSeparatorBuilder != null) {
            return sectionSeparatorBuilder!(flatItem.sectionIndex);
          }
          return sectionSeparator!;
      }
    }

    // Build size function
    double? getVirtualizedItemSize(int index) {
      if (index < 0 || index >= flatItems.length) {
        return null;
      }

      final flatItem = flatItems[index];

      switch (flatItem.type) {
        case _FlatItemType.header:
        case _FlatItemType.footer:
          return itemSize ?? (horizontal ? 100.0 : 50.0);

        case _FlatItemType.sectionHeader:
          final section = sections[flatItem.sectionIndex];
          if (getSectionHeaderSize != null) {
            return getSectionHeaderSize!(section, flatItem.sectionIndex);
          }
          return sectionHeaderSize ?? (horizontal ? 120.0 : 40.0);

        case _FlatItemType.sectionFooter:
          final section = sections[flatItem.sectionIndex];
          if (getSectionFooterSize != null) {
            return getSectionFooterSize!(section, flatItem.sectionIndex);
          }
          return sectionFooterSize ?? (horizontal ? 80.0 : 20.0);

        case _FlatItemType.item:
          if (getItemSize != null) {
            return getItemSize!(
              flatItem.data as T,
              flatItem.itemIndex!,
              flatItem.sectionIndex,
            );
          }
          return itemSize;

        case _FlatItemType.itemSeparator:
        case _FlatItemType.sectionSeparator:
          return 1.0; // Thin separator
      }
    }

    // Build key extractor
    String? getVirtualizedItemKey(int index) {
      if (index < 0 || index >= flatItems.length) {
        return 'unknown_$index';
      }

      final flatItem = flatItems[index];

      switch (flatItem.type) {
        case _FlatItemType.header:
          return 'header';

        case _FlatItemType.footer:
          return 'footer';

        case _FlatItemType.sectionHeader:
          return 'section_header_${flatItem.sectionIndex}';

        case _FlatItemType.sectionFooter:
          return 'section_footer_${flatItem.sectionIndex}';

        case _FlatItemType.item:
          if (keyExtractor != null) {
            return keyExtractor!(
              flatItem.data as T,
              flatItem.itemIndex!,
              flatItem.sectionIndex,
            );
          }
          return 'item_${flatItem.sectionIndex}_${flatItem.itemIndex}';

        case _FlatItemType.itemSeparator:
          return 'item_separator_${flatItem.sectionIndex}_${flatItem.itemIndex}';

        case _FlatItemType.sectionSeparator:
          return 'section_separator_${flatItem.sectionIndex}';
      }
    }

    // Handle viewability changes for section tracking
    Function(VirtualizedListViewabilityInfo)? onViewableItemsChanged;
    if (onSectionVisibilityChanged != null) {
      onViewableItemsChanged = (VirtualizedListViewabilityInfo info) {
        final visibleSections = <int, SectionVisibilityInfo>{};

        for (final viewableItem in info.viewableItems) {
          final flatItem = flatItems[viewableItem.index];
          final sectionIndex = flatItem.sectionIndex;

          if (sectionIndex >= 0 && sectionIndex < sections.length) {
            visibleSections[sectionIndex] = SectionVisibilityInfo(
              sectionIndex: sectionIndex,
              section: sections[sectionIndex],
              isVisible: true,
              visibleItemCount:
                  (visibleSections[sectionIndex]?.visibleItemCount ?? 0) + 1,
            );
          }
        }

        onSectionVisibilityChanged!(visibleSections.values.toList());
      };
    }

    // Handle end reached
    if (onEndReached != null) {
      final originalCallback = onViewableItemsChanged;
      onViewableItemsChanged = (VirtualizedListViewabilityInfo info) {
        // Call original callback first
        originalCallback?.call(info);

        // Check for end reached
        if (info.viewableItems.isNotEmpty) {
          final maxIndex = info.viewableItems
              .map((item) => item.index)
              .reduce((a, b) => a > b ? a : b);
          final threshold =
              (flatItems.length * (1.0 - onEndReachedThreshold)).floor();

          if (maxIndex >= threshold) {
            onEndReached!();
          }
        }
      };
    }

    // Build command
    VirtualizedListCommand? virtualizedCommand;
    if (command != null) {
      virtualizedCommand = VirtualizedListCommand(
        scrollToIndex: command!.scrollToIndex != null
            ? ScrollToIndexCommand(
                index: _convertToVirtualizedIndex(command!.scrollToIndex!),
                animated: command!.scrollToIndex!.animated,
                viewPosition: command!.scrollToIndex!.viewPosition,
              )
            : null,
        scrollToOffset: command!.scrollToOffset != null
            ? ScrollToOffsetCommand(
                offset: command!.scrollToOffset!.offset,
                animated: command!.scrollToOffset!.animated,
              )
            : null,
        flashScrollIndicators: command!.flashScrollIndicators,
        recordInteraction: command!.recordInteraction,
        refresh: command!.refresh != null
            ? RefreshCommand(
                maintainScrollPosition:
                    command!.refresh!.maintainScrollPosition,
              )
            : null,
      );
    }

    return DCFVirtualizedList(
      itemCount: flatItems.length,
      renderItem: renderVirtualizedItem,
      getItemSize: getVirtualizedItemSize,
      keyExtractor: getVirtualizedItemKey,
      horizontal: horizontal,
      layout: layout,
      styleSheet: styleSheet,
      showsScrollIndicator: showsScrollIndicator,
      scrollEnabled: scrollEnabled,
      bounces: bounces,
      pagingEnabled: pagingEnabled,
      initialNumToRender: initialNumToRender ?? (horizontal ? 5 : 10),
      removeClippedSubviews: removeClippedSubviews,
      inverted: inverted,
      onScroll: onScroll,
      onScrollBeginDrag: onScrollBeginDrag,
      onScrollEndDrag: onScrollEndDrag,
      onMomentumScrollEnd: onMomentumScrollEnd,
      onViewableItemsChanged: onViewableItemsChanged,
      command: virtualizedCommand,
      debug: debug,
      additionalProps: additionalProps,
      onMetrics: onMetrics,
      estimatedItemSize: itemSize ?? (horizontal ? 100.0 : 44.0),
    );
  }

  /// Convert SectionList coordinates to VirtualizedList index
  int _convertToVirtualizedIndex(SectionListScrollToIndexCommand command) {
    int virtualizedIndex = 0;

    // Account for header
    if (header != null) {
      virtualizedIndex += 1;
    }

    // Find the target section
    for (int sectionIndex = 0;
        sectionIndex < command.sectionIndex;
        sectionIndex++) {
      final section = sections[sectionIndex];

      // Add section header
      if (renderSectionHeader != null) {
        virtualizedIndex += 1;
      }

      // Add all items in this section
      virtualizedIndex += section.data.length;

      // Add item separators
      if (itemSeparator != null || itemSeparatorBuilder != null) {
        virtualizedIndex +=
            (section.data.length - 1).clamp(0, section.data.length);
      }

      // Add section footer
      if (renderSectionFooter != null) {
        virtualizedIndex += 1;
      }

      // Add section separator
      if (sectionIndex < sections.length - 1 &&
          (sectionSeparator != null || sectionSeparatorBuilder != null)) {
        virtualizedIndex += 1;
      }
    }

    // Add section header for target section
    if (renderSectionHeader != null) {
      if (command.itemIndex == null) {
        return virtualizedIndex; // Scroll to section header
      }
      virtualizedIndex += 1;
    }

    // Add items before target item
    if (command.itemIndex != null) {
      virtualizedIndex += command.itemIndex!;

      // Add item separators before target item
      if (itemSeparator != null || itemSeparatorBuilder != null) {
        virtualizedIndex += command.itemIndex!;
      }
    }

    return virtualizedIndex;
  }

  @override
  List<Object?> get props => [
        sections,
        renderItem,
        renderSectionHeader,
        renderSectionFooter,
        keyExtractor,
        stickySectionHeaders,
        horizontal,
        layout,
        styleSheet,
        showsScrollIndicator,
        scrollEnabled,
        bounces,
        pagingEnabled,
        itemSize,
        sectionHeaderSize,
        sectionFooterSize,
        getItemSize,
        getSectionHeaderSize,
        getSectionFooterSize,
        initialNumToRender,
        removeClippedSubviews,
        inverted,
        onScroll,
        onScrollBeginDrag,
        onScrollEndDrag,
        onMomentumScrollEnd,
        onEndReached,
        onEndReachedThreshold,
        header,
        footer,
        emptyState,
        itemSeparator,
        sectionSeparator,
        itemSeparatorBuilder,
        sectionSeparatorBuilder,
        refreshing,
        onRefresh,
        command,
        debug,
        additionalProps,
        onMetrics,
        onSectionVisibilityChanged,
        key,
      ];
}

/// Section data structure
class SectionData<T> extends Equatable {
  final String? key;
  final String? title;
  final List<T> data;
  final Map<String, dynamic>? metadata;

  const SectionData({
    this.key,
    this.title,
    required this.data,
    this.metadata,
  });

  @override
  List<Object?> get props => [key, title, data, metadata];
}

/// Section visibility information
class SectionVisibilityInfo {
  final int sectionIndex;
  final SectionData section;
  final bool isVisible;
  final int visibleItemCount;

  SectionVisibilityInfo({
    required this.sectionIndex,
    required this.section,
    required this.isVisible,
    required this.visibleItemCount,
  });
}

/// Commands for SectionList imperative operations
class SectionListCommand {
  final SectionListScrollToIndexCommand? scrollToIndex;
  final ScrollToOffsetCommand? scrollToOffset;
  final bool? flashScrollIndicators;
  final bool? recordInteraction;
  final RefreshCommand? refresh;

  SectionListCommand({
    this.scrollToIndex,
    this.scrollToOffset,
    this.flashScrollIndicators,
    this.recordInteraction,
    this.refresh,
  });

  bool get hasCommands {
    return scrollToIndex != null ||
        scrollToOffset != null ||
        flashScrollIndicators == true ||
        recordInteraction == true ||
        refresh != null;
  }
}

/// Scroll to index command for SectionList
class SectionListScrollToIndexCommand {
  final int sectionIndex;
  final int? itemIndex; // null = scroll to section header
  final bool animated;
  final String viewPosition; // 'auto', 'start', 'center', 'end'

  SectionListScrollToIndexCommand({
    required this.sectionIndex,
    this.itemIndex,
    this.animated = true,
    this.viewPosition = 'auto',
  });
}

/// Internal flat item representation
class _FlatItem<T> {
  final _FlatItemType type;
  final int index;
  final int sectionIndex;
  final int? itemIndex;
  final T? data;

  _FlatItem({
    required this.type,
    required this.index,
    required this.sectionIndex,
    this.itemIndex,
    this.data,
  });
}

/// Internal item info
class _ItemInfo<T> {
  final int sectionIndex;
  final int itemIndex;
  final T item;

  _ItemInfo({
    required this.sectionIndex,
    required this.itemIndex,
    required this.item,
  });
}

/// Internal flat item types
enum _FlatItemType {
  header,
  footer,
  sectionHeader,
  sectionFooter,
  item,
  itemSeparator,
  sectionSeparator,
}
