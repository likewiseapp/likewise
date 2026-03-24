import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bunny_config.dart';
import '../models/wave.dart';

class WaveService {
  final SupabaseClient _client;

  WaveService(this._client);

  Future<List<Wave>> fetchWaves() async {
    final data = await _client
        .from('waves')
        .select()
        .eq('status', 'approved')
        .order('created_at', ascending: false);
    return (data as List).map((e) => Wave.fromJson(e)).toList();
  }

  Future<void> uploadWave(
    File videoFile,
    String caption,
    String userId, {
    void Function(double progress)? onProgress,
  }) async {
    // Step 1: Create video object in Bunny Stream
    final createRes = await http.post(
      Uri.parse(
        '${BunnyConfig.streamApiBase}/library/${BunnyConfig.streamLibraryId}/videos',
      ),
      headers: {
        'AccessKey': BunnyConfig.streamApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': 'wave_${DateTime.now().millisecondsSinceEpoch}',
      }),
    );

    if (createRes.statusCode != 200 && createRes.statusCode != 201) {
      throw Exception(
        'Failed to create video: ${createRes.statusCode} ${createRes.body}',
      );
    }

    final videoId =
        (jsonDecode(createRes.body) as Map<String, dynamic>)['guid'] as String;

    // Step 2: Stream video bytes to Bunny (avoids loading entire file into RAM)
    final fileLength = await videoFile.length();
    var sentBytes = 0;
    final client = http.Client();
    try {
      final request = http.StreamedRequest(
        'PUT',
        Uri.parse(
          '${BunnyConfig.streamApiBase}/library/${BunnyConfig.streamLibraryId}/videos/$videoId',
        ),
      );
      request.headers['AccessKey'] = BunnyConfig.streamApiKey;
      request.headers['Content-Type'] = 'application/octet-stream';
      request.contentLength = fileLength;

      videoFile.openRead().listen(
        (chunk) {
          request.sink.add(chunk);
          sentBytes += chunk.length;
          onProgress?.call(sentBytes / fileLength);
        },
        onDone: request.sink.close,
        onError: request.sink.addError,
        cancelOnError: true,
      );

      final streamed = await client.send(request);
      final uploadRes = await http.Response.fromStream(streamed);

      if (uploadRes.statusCode != 200 && uploadRes.statusCode != 201) {
        throw Exception(
          'Failed to upload video: ${uploadRes.statusCode} ${uploadRes.body}',
        );
      }
    } finally {
      client.close();
    }

    // Step 3: Save record to Supabase
    await _client.from('waves').insert({
      'user_id': userId,
      'video_id': videoId,
      'video_url': '${BunnyConfig.streamCdnHostname}/$videoId/playlist.m3u8',
      'thumbnail_url': '${BunnyConfig.streamCdnHostname}/$videoId/thumbnail.jpg',
      'caption': caption,
    });
  }

  Future<void> deleteWave(String waveId) async {
    await _client.from('waves').delete().eq('id', waveId);
  }
}
