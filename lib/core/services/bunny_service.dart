import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../bunny_config.dart';

class BunnyService {
  /// Returns the public CDN URL for a given storage path.
  static String cdnUrl(String path) => '${BunnyConfig.cdnUrl}/$path';

  /// Extracts the storage path from a full CDN URL.
  /// e.g. "https://dawnlitdev.b-cdn.net/likewise/avatars/abc_123.jpg"
  ///   → "likewise/avatars/abc_123.jpg"
  static String? pathFromCdnUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final p = uri.path;
    return p.startsWith('/') ? p.substring(1) : p;
  }

  /// Uploads [bytes] to [path] in the BunnyCDN storage zone via HTTP PUT.
  /// Accepts both 200 (overwrite) and 201 (created) as success.
  Future<void> upload(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    final uri = Uri.parse('${BunnyConfig.storageUrl}/$path');
    final response = await http.put(
      uri,
      headers: {
        'AccessKey': BunnyConfig.apiKey,
        'Content-Type': contentType,
      },
      body: bytes,
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(
        'BunnyCDN upload failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Deletes the file at [path] from the BunnyCDN storage zone.
  /// 404 responses are silently ignored (file already absent).
  Future<void> delete(String path) async {
    final uri = Uri.parse('${BunnyConfig.storageUrl}/$path');
    final response = await http.delete(
      uri,
      headers: {'AccessKey': BunnyConfig.apiKey},
    );
    if (response.statusCode == 404) return;
    if (response.statusCode != 200) {
      throw Exception(
        'BunnyCDN delete failed: ${response.statusCode} ${response.body}',
      );
    }
  }
}
