/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/// LRU (Least Recently Used) Cache implementation
class LRUCache<K, V> {
  final int maxSize;
  final Map<K, _CacheEntry<V>> _cache = {};
  _CacheEntry<V>? _head;
  _CacheEntry<V>? _tail;
  int _accessCounter = 0;

  LRUCache({required this.maxSize}) : assert(maxSize > 0);

  /// Get value from cache, promoting to most recently used
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    _accessCounter++;
    entry.lastAccessed = _accessCounter;
    _promoteToHead(entry);
    return entry.value;
  }

  /// Put value in cache, evicting least recently used if needed
  void put(K key, V value) {
    final existing = _cache[key];
    if (existing != null) {
      existing.value = value;
      _accessCounter++;
      existing.lastAccessed = _accessCounter;
      _promoteToHead(existing);
      return;
    }

    // Create new entry
    _accessCounter++;
    final newEntry = _CacheEntry<V>(
      key: key,
      value: value,
      lastAccessed: _accessCounter,
    );

    if (_cache.length >= maxSize) {
      // Evict least recently used (tail)
      if (_tail != null) {
        _cache.remove(_tail!.key);
        _removeFromList(_tail!);
      }
    }

    _cache[key] = newEntry;
    _addToHead(newEntry);
  }

  /// Remove entry from cache
  void remove(K key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _removeFromList(entry);
    }
  }

  /// Clear all entries
  void clear() {
    _cache.clear();
    _head = null;
    _tail = null;
  }

  /// Get current size
  int get length => _cache.length;

  /// Check if cache contains key
  bool containsKey(K key) => _cache.containsKey(key);

  /// Get all keys
  Iterable<K> get keys => _cache.keys;

  void _promoteToHead(_CacheEntry<V> entry) {
    if (entry == _head) return;

    _removeFromList(entry);
    _addToHead(entry);
  }

  void _addToHead(_CacheEntry<V> entry) {
    if (_head == null) {
      _head = entry;
      _tail = entry;
    } else {
      entry.next = _head;
      _head!.prev = entry;
      _head = entry;
    }
  }

  void _removeFromList(_CacheEntry<V> entry) {
    if (entry.prev != null) {
      entry.prev!.next = entry.next;
    } else {
      _head = entry.next;
    }

    if (entry.next != null) {
      entry.next!.prev = entry.prev;
    } else {
      _tail = entry.prev;
    }

    entry.prev = null;
    entry.next = null;
  }
}

class _CacheEntry<V> {
  final dynamic key;
  V value;
  int lastAccessed;
  _CacheEntry<V>? prev;
  _CacheEntry<V>? next;

  _CacheEntry({
    required this.key,
    required this.value,
    required this.lastAccessed,
  });
}

