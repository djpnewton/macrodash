/// An entry in the cache with a key, value, and expiration date.
class CacheEntry {
  /// Creates a new [CacheEntry] with the given key, value, and expiration.
  CacheEntry({
    required this.key,
    required this.value,
    required this.expiration,
  });

  /// The key for the cache entry.
  final String key;

  /// The value for the cache entry.
  final Map<String, dynamic> value;

  /// The expiration date and time for the cache entry.
  final DateTime expiration;

  /// check if the cache entry is expired
  bool isExpired() {
    return DateTime.now().isAfter(expiration);
  }
}

/// A simple in-memory cache implementation for storing key-value pairs with
/// expiration.
class Cache {
  /// The in-memory cache storage.
  static final Map<String, CacheEntry> _cache = {};

  /// Adds a new entry to the cache with the given key, value, expiration and
  /// duration.
  void add(
    String key,
    Map<String, dynamic> value, {
    Duration expirationDuration = const Duration(minutes: 5),
  }) {
    final expiration = DateTime.now().add(expirationDuration);
    _cache[key] = CacheEntry(key: key, value: value, expiration: expiration);
  }

  /// Retrieves the value associated with the given key from the cache. If the
  /// entry is expired, it removes the entry from the cache and returns null.
  /// If the key does not exist, it returns null.
  Map<String, dynamic>? get(String key) {
    final entry = _cache[key];
    if (entry == null) {
      return null;
    }
    if (entry.isExpired()) {
      _cache.remove(key);
      return null;
    }
    return entry.value;
  }
}
