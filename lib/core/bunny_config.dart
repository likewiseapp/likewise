abstract final class BunnyConfig {
  // Bunny Storage (avatars / images)
  static const String storageUrl = 'https://sg.storage.bunnycdn.com/likewise';
  static const String cdnUrl = 'https://likewise.b-cdn.net';
  static const String apiKey = '67306197-98fb-41b9-83a4fa0b5d1d-6280-4af6';

  // Bunny Stream (Waves / video)
  static const int streamLibraryId = 622331;
  static const String streamApiKey = '6508e037-4121-40d0-bb4f57aece32-fb0c-4938';
  static const String streamCdnHostname = 'https://vz-8ed166a2-a16.b-cdn.net';
  static const String streamApiBase = 'https://video.bunnycdn.com';
}

abstract final class BunnyPaths {
  /// Unique avatar path per upload — timestamp in filename prevents CDN caching.
  static String avatar(String userId) =>
      'likewise/avatars/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

  /// Temporary storage path for a raw wave video awaiting admin review.
  static String rawWave(String userId) =>
      'likewise/waves/raw/${userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
}

abstract final class CustomAvatars {
  static const int count = 20;

  /// CDN URL for thumb #[index] (1-based, matches the filename like "01.png").
  static String urlForIndex(int index) {
    final padded = index.toString().padLeft(2, '0');
    return '${BunnyConfig.cdnUrl}/likewise/avatars/thumbs/$padded.png';
  }

  /// All 20 URLs, in order.
  static List<String> allUrls() => [
        for (int i = 1; i <= count; i++) urlForIndex(i),
      ];

  /// Returns true if [url] is one of the custom avatar URLs (used to detect
  /// that the current avatar was picked rather than uploaded).
  static bool isCustom(String? url) {
    if (url == null) return false;
    return url.startsWith('${BunnyConfig.cdnUrl}/likewise/avatars/thumbs/');
  }
}
