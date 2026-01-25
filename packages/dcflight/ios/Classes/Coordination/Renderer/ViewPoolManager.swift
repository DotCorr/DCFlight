/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

import UIKit
import Foundation

/// Global view pooling system for reusing native views across all screens
/// Dramatically reduces inflation latency by reusing views instead of creating new ones
/// Inspired by Valdi's view pooling system
class ViewPoolManager {
    static let shared = ViewPoolManager()
    
    /// Maximum number of views to keep per type (prevents unbounded memory growth)
    private let maxPoolSizePerType = 10
    
    /// Feature flag to enable/disable view pooling
    private var isEnabled = true
    
    /// Pools of views by type: [ViewType: [UIView]]
    private var pools: [String: [UIView]] = [:]
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    private init() {
        // Listen for memory warnings to clear pools
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    /// Enable or disable view pooling
    func setEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        isEnabled = enabled
        
        if !enabled {
            // Clear all pools when disabled
            clearAllPools()
        }
    }
    
    /// Check if pooling is enabled
    func isPoolingEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isEnabled
    }
    
    /// Acquire a view from the pool, or create a new one if pool is empty
    /// - Parameters:
    ///   - viewType: The type of view to acquire
    ///   - componentType: The component type to create a new view if pool is empty
    ///   - props: Props to apply to the view
    /// - Returns: A recycled view or nil if pooling is disabled or pool is empty
    func acquireView(
        viewType: String,
        componentType: DCFComponent.Type,
        props: [String: Any]
    ) -> UIView? {
        guard isEnabled else {
            return nil
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        // Try to get a view from the pool
        if var pool = pools[viewType], !pool.isEmpty {
            let view = pool.removeLast()
            pools[viewType] = pool
            
            print("♻️ ViewPoolManager: Reused view of type '\(viewType)' from pool (pool size: \(pool.count))")
            return view
        }
        
        // Pool is empty, return nil to create new view
        return nil
    }
    
    /// Release a view to the pool for future reuse
    /// - Parameters:
    ///   - view: The view to release
    ///   - viewType: The type of the view
    ///   - componentType: The component type (for prepareForRecycle)
    func releaseView(
        view: UIView,
        viewType: String,
        componentType: DCFComponent.Type
    ) {
        guard isEnabled else {
            return
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        // Prepare view for recycling
        let componentInstance = componentType.init()
        componentInstance.prepareForRecycle(view)
        
        // Check pool size limit
        var pool = pools[viewType] ?? []
        if pool.count >= maxPoolSizePerType {
            // Pool is full, don't add this view (it will be deallocated)
            print("♻️ ViewPoolManager: Pool for '\(viewType)' is full (\(pool.count)), discarding view")
            return
        }
        
        // Add to pool
        pool.append(view)
        pools[viewType] = pool
        
        print("♻️ ViewPoolManager: Released view of type '\(viewType)' to pool (pool size: \(pool.count))")
    }
    
    /// Clear all pools (useful for memory management or hot restart)
    func clearAllPools() {
        lock.lock()
        defer { lock.unlock() }
        
        let totalViews = pools.values.reduce(0) { $0 + $1.count }
        pools.removeAll()
        
        print("♻️ ViewPoolManager: Cleared all pools (\(totalViews) views)")
    }
    
    /// Clear pool for a specific view type
    func clearPool(for viewType: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let count = pools[viewType]?.count ?? 0
        pools.removeValue(forKey: viewType)
        
        print("♻️ ViewPoolManager: Cleared pool for '\(viewType)' (\(count) views)")
    }
    
    /// Get current pool size for a view type
    func getPoolSize(for viewType: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return pools[viewType]?.count ?? 0
    }
    
    /// Get total number of pooled views across all types
    func getTotalPooledViews() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return pools.values.reduce(0) { $0 + $1.count }
    }
    
    /// Handle memory warnings by clearing pools
    @objc private func handleMemoryWarning() {
        print("♻️ ViewPoolManager: Memory warning received, clearing pools")
        clearAllPools()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

