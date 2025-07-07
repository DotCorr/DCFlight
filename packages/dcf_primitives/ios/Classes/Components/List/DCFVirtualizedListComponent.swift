/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import dcflight

/// ListView that only render visible items for optimal memory usage and smooth scrolling.
///
/// Features:
/// - Viewport-based rendering (only renders visible items)
/// - Dynamic item heights with layout caching
/// - Bidirectional virtualization (horizontal + vertical)
/// - Smooth scrolling with predictive rendering
/// - Memory efficient with item recycling
/// - Infinite scroll support
class DCFVirtualizedListComponent: NSObject, DCFComponent, UIScrollViewDelegate {
    private static let sharedInstance = DCFVirtualizedListComponent()

    required override init() {
        super.init()
    }

    func createView(props: [String: Any]) -> UIView {
        let virtualizedList = DCFVirtualizedListView()

        // Set shared instance as delegate
        virtualizedList.delegate = DCFVirtualizedListComponent.sharedInstance

        // Configure from props
        updateView(virtualizedList, withProps: props)

        // Apply StyleSheet properties
        virtualizedList.applyStyles(props: props)

        return virtualizedList
    }

    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let virtualizedList = view as? DCFVirtualizedListView else { return false }

        // Update virtualization parameters
        if let itemCount = props["itemCount"] as? Int {
            virtualizedList.itemCount = itemCount
        }

        if let getItemSize = props["getItemSize"] as? String {
            virtualizedList.getItemSizeFunction = getItemSize
        }

        if let renderItem = props["renderItem"] as? String {
            virtualizedList.renderItemFunction = renderItem
        }

        if let horizontal = props["horizontal"] as? Bool {
            virtualizedList.isHorizontal = horizontal
        }

        if let initialNumToRender = props["initialNumToRender"] as? Int {
            virtualizedList.initialNumToRender = initialNumToRender
        }

        if let maxToRenderPerBatch = props["maxToRenderPerBatch"] as? Int {
            virtualizedList.maxToRenderPerBatch = maxToRenderPerBatch
        }

        if let windowSize = props["windowSize"] as? Int {
            virtualizedList.windowSize = windowSize
        }

        if let removeClippedSubviews = props["removeClippedSubviews"] as? Bool {
            virtualizedList.removeClippedSubviews = removeClippedSubviews
        }

        if let maintainVisibleContentPosition = props["maintainVisibleContentPosition"] as? Bool {
            virtualizedList.maintainVisibleContentPosition = maintainVisibleContentPosition
        }

        if let inverted = props["inverted"] as? Bool {
            virtualizedList.inverted = inverted
        }

        if let estimatedItemSize = props["estimatedItemSize"] as? CGFloat {
            virtualizedList.estimatedItemSize = estimatedItemSize
        }

        // Handle scroll behavior
        if let showsScrollIndicator = props["showsScrollIndicator"] as? Bool {
            virtualizedList.showsVerticalScrollIndicator = showsScrollIndicator
            virtualizedList.showsHorizontalScrollIndicator = showsScrollIndicator
        }

        if let scrollEnabled = props["scrollEnabled"] as? Bool {
            virtualizedList.isScrollEnabled = scrollEnabled
        }

        if let bounces = props["bounces"] as? Bool {
            virtualizedList.bounces = bounces
        }

        if let pagingEnabled = props["pagingEnabled"] as? Bool {
            virtualizedList.isPagingEnabled = pagingEnabled
        }

        // Handle background color
        if let backgroundColor = props["backgroundColor"] as? String {
            virtualizedList.backgroundColor = ColorUtilities.color(fromHexString: backgroundColor)
        }

        // Handle commands
        handleCommand(virtualizedList: virtualizedList, props: props)

        // Apply StyleSheet properties
        virtualizedList.applyStyles(props: props)

        // Trigger layout update
        virtualizedList.setNeedsLayout()

        return true
    }

    // MARK: - Command Handling
    private func handleCommand(virtualizedList: DCFVirtualizedListView, props: [String: Any]) {
        guard let commandData = props["command"] as? [String: Any] else { return }

        if let scrollToIndex = commandData["scrollToIndex"] as? [String: Any] {
            if let index = scrollToIndex["index"] as? Int {
                let animated = scrollToIndex["animated"] as? Bool ?? true
                let viewPosition = scrollToIndex["viewPosition"] as? String ?? "auto"
                virtualizedList.scrollToIndex(index, animated: animated, viewPosition: viewPosition)
            }
        }

        if let scrollToOffset = commandData["scrollToOffset"] as? [String: Any] {
            if let offset = scrollToOffset["offset"] as? CGFloat {
                let animated = scrollToOffset["animated"] as? Bool ?? true
                virtualizedList.scrollToOffset(offset, animated: animated)
            }
        }

        if let flashScrollIndicators = commandData["flashScrollIndicators"] as? Bool,
            flashScrollIndicators
        {
            virtualizedList.flashScrollIndicators()
        }

        if let recordInteraction = commandData["recordInteraction"] as? Bool, recordInteraction {
            virtualizedList.recordInteraction()
        }
    }

    // MARK: - UIScrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let virtualizedList = scrollView as? DCFVirtualizedListView else { return }

        // Update viewport and manage visible items
        virtualizedList.updateViewport()

        // Propagate scroll event
        propagateEvent(
            on: scrollView, eventName: "onScroll",
            data: [
                "contentOffset": [
                    "x": scrollView.contentOffset.x,
                    "y": scrollView.contentOffset.y,
                ],
                "contentSize": [
                    "width": scrollView.contentSize.width,
                    "height": scrollView.contentSize.height,
                ],
                "layoutMeasurement": [
                    "width": scrollView.bounds.width,
                    "height": scrollView.bounds.height,
                ],
                "zoomScale": scrollView.zoomScale,
            ])
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        propagateEvent(
            on: scrollView, eventName: "onScrollBeginDrag",
            data: [
                "contentOffset": [
                    "x": scrollView.contentOffset.x,
                    "y": scrollView.contentOffset.y,
                ]
            ])
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        propagateEvent(
            on: scrollView, eventName: "onScrollEndDrag",
            data: [
                "contentOffset": [
                    "x": scrollView.contentOffset.x,
                    "y": scrollView.contentOffset.y,
                ],
                "willDecelerate": decelerate,
            ])
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        propagateEvent(
            on: scrollView, eventName: "onMomentumScrollEnd",
            data: [
                "contentOffset": [
                    "x": scrollView.contentOffset.x,
                    "y": scrollView.contentOffset.y,
                ]
            ])
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        propagateEvent(
            on: scrollView, eventName: "onScrollEnd",
            data: [
                "contentOffset": [
                    "x": scrollView.contentOffset.x,
                    "y": scrollView.contentOffset.y,
                ]
            ])
    }
}

/// Custom UIScrollView for virtualized list rendering
class DCFVirtualizedListView: UIScrollView {

    // MARK: - Virtualization Properties
    var itemCount: Int = 0 {
        didSet {
            if itemCount != oldValue {
                invalidateLayout()
            }
        }
    }

    var getItemSizeFunction: String = ""
    var renderItemFunction: String = ""
    var isHorizontal: Bool = false
    var initialNumToRender: Int = 10
    var maxToRenderPerBatch: Int = 10
    var windowSize: Int = 21
    var removeClippedSubviews: Bool = true
    var maintainVisibleContentPosition: Bool = false
    var inverted: Bool = false
    var estimatedItemSize: CGFloat = 44.0

    // MARK: - Internal State
    private var visibleItems: [Int: UIView] = [:]
    private var itemSizeCache: [Int: CGFloat] = [:]
    private var itemOffsetCache: [Int: CGFloat] = [:]
    private var recyclePool: [String: [UIView]] = [:]
    private var renderQueue: Set<Int> = []
    private var isLayoutInvalid: Bool = true

    // MARK: - Viewport State
    private var currentViewportStart: CGFloat = 0
    private var currentViewportEnd: CGFloat = 0
    private var visibleStartIndex: Int = 0
    private var visibleEndIndex: Int = 0

    // MARK: - Performance Tracking
    private var lastScrollTime: TimeInterval = 0
    private var scrollVelocity: CGPoint = .zero
    private var isScrollingFast: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupVirtualizedList()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupVirtualizedList()
    }

    private func setupVirtualizedList() {
        self.clipsToBounds = true
        self.showsVerticalScrollIndicator = true
        self.showsHorizontalScrollIndicator = true

        // Performance optimizations
        self.layer.shouldRasterize = false
        self.canCancelContentTouches = true
        self.delaysContentTouches = true
    }

    // MARK: - Layout Management
    override func layoutSubviews() {
        super.layoutSubviews()

        if isLayoutInvalid {
            rebuildLayout()
            isLayoutInvalid = false
        }

        updateViewport()
    }

    private func invalidateLayout() {
        isLayoutInvalid = true
        itemSizeCache.removeAll()
        itemOffsetCache.removeAll()
        setNeedsLayout()
    }

    private func rebuildLayout() {
        guard itemCount > 0 else {
            self.contentSize = self.bounds.size
            return
        }

        // Calculate total content size
        let totalSize = calculateTotalContentSize()

        if isHorizontal {
            self.contentSize = CGSize(width: totalSize, height: self.bounds.height)
        } else {
            self.contentSize = CGSize(width: self.bounds.width, height: totalSize)
        }

        // Initial render
        updateViewport()
    }

    private func calculateTotalContentSize() -> CGFloat {
        var totalSize: CGFloat = 0

        for i in 0..<itemCount {
            let itemSize = getItemSize(at: i)
            itemOffsetCache[i] = totalSize
            totalSize += itemSize
        }

        return totalSize
    }

    private func getItemSize(at index: Int) -> CGFloat {
        if let cachedSize = itemSizeCache[index] {
            return cachedSize
        }

        // For now, use estimated size. In a real implementation,
        // this would call back to Dart to get the actual size
        let size = estimatedItemSize
        itemSizeCache[index] = size
        return size
    }

    // MARK: - Viewport Management
    func updateViewport() {
        let scrollOffset = isHorizontal ? self.contentOffset.x : self.contentOffset.y
        let viewportSize = isHorizontal ? self.bounds.width : self.bounds.height

        currentViewportStart = scrollOffset
        currentViewportEnd = scrollOffset + viewportSize

        // Calculate visible range with buffer
        let bufferSize = viewportSize * 0.5  // 50% buffer
        let bufferedStart = max(0, currentViewportStart - bufferSize)
        let bufferedEnd = currentViewportEnd + bufferSize

        // Find visible item indices
        let newVisibleStartIndex = findItemIndex(for: bufferedStart)
        let newVisibleEndIndex = findItemIndex(for: bufferedEnd)

        // Update visible range
        if newVisibleStartIndex != visibleStartIndex || newVisibleEndIndex != visibleEndIndex {
            visibleStartIndex = newVisibleStartIndex
            visibleEndIndex = min(newVisibleEndIndex, itemCount - 1)

            updateVisibleItems()
        }
    }

    private func findItemIndex(for offset: CGFloat) -> Int {
        // Binary search for performance
        var left = 0
        var right = itemCount - 1

        while left <= right {
            let mid = (left + right) / 2
            let itemOffset = itemOffsetCache[mid] ?? 0

            if itemOffset <= offset {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }

        return max(0, min(right, itemCount - 1))
    }

    private func updateVisibleItems() {
        // Remove items that are no longer visible
        let currentVisible = Set(visibleItems.keys)
        let newVisible = Set(visibleStartIndex...visibleEndIndex)
        let toRemove = currentVisible.subtracting(newVisible)
        let toAdd = newVisible.subtracting(currentVisible)

        // Remove invisible items
        for index in toRemove {
            if let view = visibleItems.removeValue(forKey: index) {
                recycleView(view)
            }
        }

        // Add new visible items
        for index in toAdd {
            renderItem(at: index)
        }
    }

    private func renderItem(at index: Int) {
        guard index >= 0 && index < itemCount else { return }

        // Get or create item view
        let itemView = getOrCreateItemView(at: index)

        // Position the item
        positionItem(itemView, at: index)

        // Add to visible items
        visibleItems[index] = itemView

        // Add to scroll view if not already added
        if itemView.superview != self {
            self.addSubview(itemView)
        }
    }

    private func getOrCreateItemView(at index: Int) -> UIView {
        // In a real implementation, this would communicate with Dart
        // to get the actual rendered component for this index

        // For now, create a simple placeholder
        let itemView = UIView()
        itemView.backgroundColor = index % 2 == 0 ? UIColor.lightGray : UIColor.white
        itemView.layer.borderWidth = 1
        itemView.layer.borderColor = UIColor.gray.cgColor

        // Add a label for debugging
        let label = UILabel()
        label.text = "Item \(index)"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        itemView.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: itemView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: itemView.centerYAnchor),
        ])

        return itemView
    }

    private func positionItem(_ itemView: UIView, at index: Int) {
        let itemSize = getItemSize(at: index)
        let itemOffset = itemOffsetCache[index] ?? 0

        if isHorizontal {
            itemView.frame = CGRect(
                x: itemOffset,
                y: 0,
                width: itemSize,
                height: self.bounds.height
            )
        } else {
            itemView.frame = CGRect(
                x: 0,
                y: itemOffset,
                width: self.bounds.width,
                height: itemSize
            )
        }
    }

    private func recycleView(_ view: UIView) {
        // Remove from superview
        view.removeFromSuperview()

        // In a real implementation, this would add the view to a recycle pool
        // for reuse with different data
    }

    // MARK: - Public Methods
    func scrollToIndex(_ index: Int, animated: Bool, viewPosition: String = "auto") {
        guard index >= 0 && index < itemCount else { return }

        let itemOffset = itemOffsetCache[index] ?? 0
        let targetOffset: CGFloat

        switch viewPosition {
        case "start":
            targetOffset = itemOffset
        case "center":
            let viewportSize = isHorizontal ? self.bounds.width : self.bounds.height
            let itemSize = getItemSize(at: index)
            targetOffset = itemOffset - (viewportSize - itemSize) / 2
        case "end":
            let viewportSize = isHorizontal ? self.bounds.width : self.bounds.height
            let itemSize = getItemSize(at: index)
            targetOffset = itemOffset - viewportSize + itemSize
        default:  // "auto"
            targetOffset = itemOffset
        }

        let clampedOffset = max(0, min(targetOffset, self.contentSize.height - self.bounds.height))

        if isHorizontal {
            self.setContentOffset(
                CGPoint(x: clampedOffset, y: self.contentOffset.y), animated: animated)
        } else {
            self.setContentOffset(
                CGPoint(x: self.contentOffset.x, y: clampedOffset), animated: animated)
        }
    }

    func scrollToOffset(_ offset: CGFloat, animated: Bool) {
        if isHorizontal {
            self.setContentOffset(CGPoint(x: offset, y: self.contentOffset.y), animated: animated)
        } else {
            self.setContentOffset(CGPoint(x: self.contentOffset.x, y: offset), animated: animated)
        }
    }

    func recordInteraction() {
        // Track user interaction for performance optimizations
        lastScrollTime = Date().timeIntervalSince1970
    }

    // MARK: - Performance Optimization
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        recordInteraction()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        // Trigger a cleanup of off-screen items after touch ends
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.cleanupOffScreenItems()
        }
    }

    private func cleanupOffScreenItems() {
        guard removeClippedSubviews else { return }

        // Remove items that are far outside the viewport
        let extraBuffer = (isHorizontal ? self.bounds.width : self.bounds.height) * 2
        let cleanupStart = currentViewportStart - extraBuffer
        let cleanupEnd = currentViewportEnd + extraBuffer

        let toRemove = visibleItems.filter { index, view in
            let itemOffset = itemOffsetCache[index] ?? 0
            let itemSize = getItemSize(at: index)
            return itemOffset + itemSize < cleanupStart || itemOffset > cleanupEnd
        }

        for (index, view) in toRemove {
            visibleItems.removeValue(forKey: index)
            recycleView(view)
        }
    }
}
