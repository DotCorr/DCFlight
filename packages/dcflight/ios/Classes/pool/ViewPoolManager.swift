/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Foundation

/**
 * View recycling pool manager for performance optimization.
 * Reuses views instead of creating/destroying them, reducing allocation overhead
 * and eliminating visual flashing during rapid updates.
 */
class ViewPoolManager {
    
    static let shared = ViewPoolManager()
    
    private let defaultMaxPoolSize = 10 // Max views per type in pool
    
    // Map of view type -> queue of recycled views
    private var pools: [String: [UIView]] = [:]
    
    // Track pool sizes per type
    private var poolSizes: [String: Int] = [:]
    private var maxPoolSizes: [String: Int] = [:]
    
    private let queue = DispatchQueue(label: "com.dotcorr.dcflight.viewpool", attributes: .concurrent)
    
    private init() {}
    
    /**
     * Get a recycled view from the pool, or nil if none available
     */
    func acquireView(viewType: String) -> UIView? {
        return queue.sync {
            guard var pool = pools[viewType], !pool.isEmpty else {
                return nil
            }
            
            let view = pool.removeFirst()
            pools[viewType] = pool
            
            let currentSize = poolSizes[viewType] ?? 0
            poolSizes[viewType] = max(0, currentSize - 1)
            
            print("♻️ ViewPoolManager: Acquired recycled view for type '\(viewType)' (pool size: \(poolSizes[viewType] ?? 0))")
            
            return view
        }
    }
    
    /**
     * Return a view to the pool for recycling
     */
    func releaseView(_ view: UIView, viewType: String) {
        guard view != nil else { return }
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Clean up the view before pooling
            self.resetViewForReuse(view)
            
            let maxSize = self.maxPoolSizes[viewType] ?? self.defaultMaxPoolSize
            let currentSize = self.poolSizes[viewType] ?? 0
            
            if currentSize >= maxSize {
                // Pool is full, don't add this view
                print("♻️ ViewPoolManager: Pool for '\(viewType)' is full (max: \(maxSize)), discarding view")
                return
            }
            
            var pool = self.pools[viewType] ?? []
            pool.append(view)
            self.pools[viewType] = pool
            self.poolSizes[viewType] = currentSize + 1
            
            print("♻️ ViewPoolManager: Released view to pool for type '\(viewType)' (pool size: \(self.poolSizes[viewType] ?? 0))")
        }
    }
    
    /**
     * Reset a view to a clean state before reusing
     */
    private func resetViewForReuse(_ view: UIView) {
        DispatchQueue.main.sync {
            // Remove from parent if attached
            view.removeFromSuperview()
            
            // Clear any state that might interfere with reuse
            view.alpha = 1.0
            view.isHidden = false
            view.isUserInteractionEnabled = true
            view.isMultipleTouchEnabled = false
            
            // Clear any layout constraints that might be specific to previous parent
            view.translatesAutoresizingMaskIntoConstraints = false
            view.removeConstraints(view.constraints)
            
            // Clear any view-specific state - remove all subviews
            view.subviews.forEach { $0.removeFromSuperview() }
        }
    }
    
    /**
     * Set maximum pool size for a specific view type
     */
    func setMaxPoolSize(_ viewType: String, maxSize: Int) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.maxPoolSizes[viewType] = maxSize
            print("📊 ViewPoolManager: Set max pool size for '\(viewType)' to \(maxSize)")
            
            // Trim pool if it exceeds new max size
            if var pool = self.pools[viewType] {
                let currentSize = self.poolSizes[viewType] ?? 0
                if currentSize > maxSize {
                    let toRemove = currentSize - maxSize
                    pool.removeFirst(toRemove)
                    self.pools[viewType] = pool
                    self.poolSizes[viewType] = maxSize
                    print("✂️ ViewPoolManager: Trimmed pool for '\(viewType)' by \(toRemove) views")
                }
            }
        }
    }
    
    /**
     * Clear all pools (useful for memory management)
     */
    func clearAll() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.pools.removeAll()
            self.poolSizes.removeAll()
            self.maxPoolSizes.removeAll()
            print("🗑️ ViewPoolManager: Cleared all view pools")
        }
    }
    
    /**
     * Clear pool for a specific view type
     */
    func clearPool(_ viewType: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.pools.removeValue(forKey: viewType)
            self.poolSizes.removeValue(forKey: viewType)
            self.maxPoolSizes.removeValue(forKey: viewType)
            print("🗑️ ViewPoolManager: Cleared pool for type '\(viewType)'")
        }
    }
    
    /**
     * Get current pool size for a view type
     */
    func getPoolSize(_ viewType: String) -> Int {
        return queue.sync {
            return poolSizes[viewType] ?? 0
        }
    }
    
    /**
     * Get statistics about all pools
     */
    func getPoolStats() -> [String: Int] {
        return queue.sync {
            return poolSizes
        }
    }
}

