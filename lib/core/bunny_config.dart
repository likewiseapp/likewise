abstract final class BunnyConfig {
  // Bunny Storage (avatars / images)
  static const String storageUrl = 'https://storage.bunnycdn.com/dawnlitdev';
  static const String cdnUrl = 'https://dawnlitdev.b-cdn.net';
  static const String apiKey = 'a7122a49-72f9-4205-adb783a6b90a-0eaa-42ff';

  // Bunny Stream (Waves / video)
  static const int streamLibraryId = 622348;
  static const String streamApiKey = 'fff6e3a1-0f12-49e5-8be73fdb998b-6fab-406b';
  static const String streamCdnHostname = 'https://vz-e8751196-59c.b-cdn.net';
  static const String streamApiBase = 'https://video.bunnycdn.com';
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
