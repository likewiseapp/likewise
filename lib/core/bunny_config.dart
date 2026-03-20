abstract final class BunnyConfig {
  static const String storageUrl = 'https://storage.bunnycdn.com/dawnlitdev';
  static const String cdnUrl = 'https://dawnlitdev.b-cdn.net';
  static const String apiKey = 'a7122a49-72f9-4205-adb783a6b90a-0eaa-42ff';
}

abstract final class BunnyPaths {
  /// Unique avatar path per upload — timestamp in filename prevents CDN caching.
  static String avatar(String userId) =>
      'likewise/avatars/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

  static String reel(String userId, String reelId) =>
      'likewise/reels/$userId/$reelId.mp4';
  static String reelThumbnail(String userId, String reelId) =>
      'likewise/thumbnails/$userId/$reelId.jpg';
}
