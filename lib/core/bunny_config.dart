abstract final class BunnyConfig {
  // Bunny Storage (avatars / images)
  static const String storageUrl = 'https://storage.bunnycdn.com/likewise';
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

}
