/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */



import UIKit
import dcflight

class DCFSuspensionViewComponent: NSObject, DCFComponent {
    required override init() {
        super.init()
    }

    func createView(props: [String: Any]) -> UIView {
        let suspensionView = DCFSuspensionView()
        suspensionView.configure(with: props)
        return suspensionView
    }

    func updateView(_ view: UIView, withProps props: [String: Any]) -> Bool {
        guard let suspensionView = view as? DCFSuspensionView else {
            return false
        }
        
        suspensionView.configure(with: props)
        return true
    }
}

/// Native suspension view that can efficiently suspend/unsuspend its content
class DCFSuspensionView: UIView {
    /// Whether the view is currently suspended
    private var isSuspended: Bool = false
    
    /// Suspension mode
    private var suspensionMode: String = "full"
    
    /// Content container that holds the actual content
    private let contentContainer = UIView()
    
    /// Placeholder view for placeholder mode
    private var placeholderView: UIView?
    
    /// Stored content views for memory mode
    private var storedContentViews: [UIView] = []
    
    /// Suspension start time for metrics
    private var suspensionStartTime: Date?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSuspensionView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSuspensionView()
    }
    
    private func setupSuspensionView() {
        // Add content container
        addSubview(contentContainer)
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Default configuration
        backgroundColor = UIColor.clear
        clipsToBounds = true
    }
    
    /// Configure the suspension view with props
    func configure(with props: [String: Any]) {
        let newSuspended = props["isSuspended"] as? Bool ?? false
        let newMode = props["suspensionMode"] as? String ?? "full"
        let visible = props["visible"] as? Bool ?? true
        
        print("🎭 Native: Configuring suspension view - suspended: \(newSuspended), mode: \(newMode)")
        
        // Handle suspension state change
        if newSuspended != isSuspended || newMode != suspensionMode {
            transitionToSuspension(suspended: newSuspended, mode: newMode)
        }
        
        isSuspended = newSuspended
        suspensionMode = newMode
        
        // Apply other props
        applyStandardProps(props)
    }
    
    /// Transition to suspension state with animation
    private func transitionToSuspension(suspended: Bool, mode: String) {
        if suspended {
            suspensionStartTime = Date()
            applySuspensionMode(mode)
        } else {
            suspensionStartTime = nil
            applyActiveMode()
        }
    }
    
    /// Apply suspension mode
    private func applySuspensionMode(_ mode: String) {
        switch mode {
        case "full":
            applyFullSuspension()
        case "placeholder":
            applyPlaceholderSuspension()
        case "background":
            applyBackgroundSuspension()
        case "memory":
            applyMemorySuspension()
        default:
            applyFullSuspension()
        }
    }
    
    /// Full suspension - hide everything
    private func applyFullSuspension() {
        UIView.animate(withDuration: 0.2) {
            self.contentContainer.alpha = 0.0
            self.isUserInteractionEnabled = false
        }
        
        // Optionally pause animations
        pauseAnimations()
        
        print("🎭 Native: Applied full suspension")
    }
    
    /// Placeholder suspension - show placeholder
    private func applyPlaceholderSuspension() {
        // Keep content hidden but show placeholder
        contentContainer.alpha = 0.0
        
        if placeholderView == nil {
            createDefaultPlaceholder()
        }
        
        placeholderView?.alpha = 1.0
        isUserInteractionEnabled = false
        
        print("🎭 Native: Applied placeholder suspension")
    }
    
    /// Background suspension - move off-screen
    private func applyBackgroundSuspension() {
        UIView.animate(withDuration: 0.1) {
            self.contentContainer.alpha = 0.0
            self.contentContainer.transform = CGAffineTransform(translationX: -10000, y: -10000)
            self.isUserInteractionEnabled = false
        }
        
        pauseAnimations()
        
        print("🎭 Native: Applied background suspension")
    }
    
    /// Memory suspension - store in memory but don't display
    private func applyMemorySuspension() {
        // Store content views
        storedContentViews = contentContainer.subviews
        
        // Hide container
        contentContainer.alpha = 0.0
        contentContainer.isHidden = true
        isUserInteractionEnabled = false
        
        // Pause animations but keep content in memory
        pauseAnimations()
        
        print("🎭 Native: Applied memory suspension - stored \(storedContentViews.count) views")
    }
    
    /// Apply active mode - unsuspend
    private func applyActiveMode() {
        // Restore container
        contentContainer.isHidden = false
        isUserInteractionEnabled = true
        
        // Hide placeholder
        placeholderView?.alpha = 0.0
        
        // Restore content
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: []) {
            self.contentContainer.alpha = 1.0
            self.contentContainer.transform = .identity
        }
        
        // Resume animations
        resumeAnimations()
        
        print("🎭 Native: Applied active mode")
    }
    
    /// Create default placeholder
    private func createDefaultPlaceholder() {
        let placeholder = UIView()
        placeholder.backgroundColor = UIColor.systemGray6
        placeholder.layer.cornerRadius = 8
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "Loading..."
        label.textColor = UIColor.systemGray
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        placeholder.addSubview(label)
        addSubview(placeholder)
        
        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
            placeholder.widthAnchor.constraint(equalToConstant: 120),
            placeholder.heightAnchor.constraint(equalToConstant: 40),
            
            label.centerXAnchor.constraint(equalTo: placeholder.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: placeholder.centerYAnchor)
        ])
        
        placeholderView = placeholder
        placeholder.alpha = 0.0 // Start hidden
    }
    
    /// Pause animations in the content
    private func pauseAnimations() {
        pauseAnimationsRecursively(in: contentContainer)
    }
    
    /// Resume animations in the content
    private func resumeAnimations() {
        resumeAnimationsRecursively(in: contentContainer)
    }
    
    /// Recursively pause animations
    private func pauseAnimationsRecursively(in view: UIView) {
        let pausedTime = view.layer.convertTime(CACurrentMediaTime(), from: nil)
        view.layer.speed = 0.0
        view.layer.timeOffset = pausedTime
        
        for subview in view.subviews {
            pauseAnimationsRecursively(in: subview)
        }
    }
    
    /// Recursively resume animations
    private func resumeAnimationsRecursively(in view: UIView) {
        let pausedTime = view.layer.timeOffset
        view.layer.speed = 1.0
        view.layer.timeOffset = 0.0
        view.layer.beginTime = 0.0
        let timeSincePause = view.layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        view.layer.beginTime = timeSincePause
        
        for subview in view.subviews {
            resumeAnimationsRecursively(in: subview)
        }
    }
    
    /// Apply standard view props
    private func applyStandardProps(_ props: [String: Any]) {
        if let bgColor = props["backgroundColor"] as? String {
            backgroundColor = ColorUtilities.color(fromHexString: bgColor)
        }
        
        if let alpha = props["alpha"] as? CGFloat {
            self.alpha = alpha
        }
        
        if let userInteraction = props["userInteractionEnabled"] as? Bool {
            isUserInteractionEnabled = userInteraction
        }
        
        // Apply layout props if needed
        if let width = props["width"] as? CGFloat,
           let height = props["height"] as? CGFloat {
            frame.size = CGSize(width: width, height: height)
        }
    }
    
    /// Get suspension metrics
    func getSuspensionMetrics() -> [String: Any] {
        var metrics: [String: Any] = [
            "isSuspended": isSuspended,
            "suspensionMode": suspensionMode,
            "contentViewsCount": contentContainer.subviews.count,
            "hasPlaceholder": placeholderView != nil
        ]
        
        if let startTime = suspensionStartTime {
            metrics["suspensionDuration"] = Date().timeIntervalSince(startTime)
        }
        
        return metrics
    }
    
    /// Memory cleanup for long-suspended views
    func performMemoryCleanup() {
        if isSuspended && suspensionMode == "full" {
            // Remove views that aren't needed
            if let startTime = suspensionStartTime,
               Date().timeIntervalSince(startTime) > 300 { // 5 minutes
                print("🎭 Native: Performing memory cleanup for long-suspended view")
                
                // Remove non-essential subviews
                contentContainer.subviews.forEach { subview in
                    if subview.tag == 999 { // Mark non-essential views with tag 999
                        subview.removeFromSuperview()
                    }
                }
            }
        }
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if superview == nil && isSuspended {
            print("🎭 Native: Suspension view removed from superview")
        }
    }
    
    deinit {
        print("🎭 Native: DCFSuspensionView deallocated")
    }
}

/// Extension to track suspension views globally
extension DCFSuspensionView {
    private static var suspensionViews: [WeakRef<DCFSuspensionView>] = []
    
    /// Register a suspension view for global tracking
    private func registerForTracking() {
        Self.suspensionViews.append(WeakRef(self))
        Self.cleanupWeakReferences()
    }
    
    /// Clean up nil weak references
    private static func cleanupWeakReferences() {
        suspensionViews = suspensionViews.filter { $0.value != nil }
    }
    
    /// Get global suspension statistics
    static func getGlobalSuspensionStats() -> [String: Any] {
        cleanupWeakReferences()
        
        let totalViews = suspensionViews.count
        let suspendedViews = suspensionViews.compactMap { $0.value }.filter { $0.isSuspended }
        let activeViews = suspensionViews.compactMap { $0.value }.filter { !$0.isSuspended }
        
        var modeStats: [String: Int] = [:]
        for view in suspensionViews.compactMap({ $0.value }) {
            if view.isSuspended {
                modeStats[view.suspensionMode] = (modeStats[view.suspensionMode] ?? 0) + 1
            }
        }
        
        return [
            "totalViews": totalViews,
            "suspendedCount": suspendedViews.count,
            "activeCount": activeViews.count,
            "modeDistribution": modeStats,
            "memoryOptimization": totalViews > 0 ? "\(suspendedViews.count * 100 / totalViews)%" : "0%"
        ]
    }
    
    /// Perform global memory cleanup
    static func performGlobalMemoryCleanup() {
        cleanupWeakReferences()
        
        for view in suspensionViews.compactMap({ $0.value }) {
            view.performMemoryCleanup()
        }
        
        print("🎭 Native: Performed global memory cleanup on \(suspensionViews.count) suspension views")
    }
}

/// Weak reference wrapper
class WeakRef<T: AnyObject> {
    weak var value: T?
    
    init(_ value: T) {
        self.value = value
    }
}