import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bunny_config.dart';
import '../models/profile.dart';
import '../models/user_hobby.dart';
import 'bunny_service.dart';

class ProfileService {
  final SupabaseClient _client;

  ProfileService(this._client);

  Future<ProfileStats?> fetchProfileStats(String userId) async {
    final data = await _client
        .from('v_profile_stats')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;

    // The view may not include profile_visibility, so fetch it separately
    if (!data.containsKey('profile_visibility')) {
      final profile = await _client
          .from('profiles')
          .select('profile_visibility')
          .eq('id', userId)
          .maybeSingle();
      if (profile != null) {
        data['profile_visibility'] = profile['profile_visibility'];
      }
    }

    return ProfileStats.fromJson(data);
  }

  Future<List<UserHobby>> fetchUserHobbies(String userId) async {
    final data = await _client
        .from('user_hobbies')
        .select('*, hobbies(*)')
        .eq('user_id', userId);
    return (data as List).map((e) => UserHobby.fromJson(e)).toList();
  }

  Future<void> updateThemePreference(String userId, String theme) async {
    await _client
        .from('profiles')
        .update({'theme_preference': theme})
        .eq('id', userId);
  }

  Future<Profile?> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> fields) async {
    await _client.from('profiles').update(fields).eq('id', userId);
  }

  /// Upload avatar image to BunnyCDN and update the profile's avatar_url.
  /// Returns the new public CDN URL.
  Future<String> uploadAvatar(String userId, File file) async {
    final raw = await file.readAsBytes();
    final bytes = await FlutterImageCompress.compressWithList(
      raw,
      minWidth: 512,
      minHeight: 512,
      quality: 75,
      format: CompressFormat.jpeg,
    );
    final bunny = BunnyService();

    // Delete the old avatar file from BunnyCDN (if one exists)
    await _deleteOldAvatar(userId, bunny);

    // Upload with a unique timestamped filename — no CDN caching issues
    final path = BunnyPaths.avatar(userId);
    await bunny.upload(path, bytes, 'image/jpeg');

    final url = BunnyService.cdnUrl(path);
    await _client
        .from('profiles')
        .update({'avatar_url': url})
        .eq('id', userId);

    return url;
  }

  /// Remove the avatar: delete from BunnyCDN and set avatar_url to null.
  Future<void> removeAvatar(String userId) async {
    await _deleteOldAvatar(userId, BunnyService());
    await _client
        .from('profiles')
        .update({'avatar_url': null})
        .eq('id', userId);
  }

  /// Looks up the current avatar_url in Supabase, derives the storage path,
  /// and deletes the file from BunnyCDN. Silently ignores missing files.
  Future<void> _deleteOldAvatar(String userId, BunnyService bunny) async {
    try {
      final row = await _client
          .from('profiles')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();
      final oldUrl = row?['avatar_url'] as String?;
      final oldPath = BunnyService.pathFromCdnUrl(oldUrl);
      if (oldPath != null) {
        await bunny.delete(oldPath);
      }
    } catch (_) {
      // Best-effort cleanup — don't block the upload if this fails
    }
  }

  Future<void> updateUserHobbies(
    String userId,
    List<({int hobbyId, bool isPrimary})> hobbies,
  ) async {
    await _client.from('user_hobbies').delete().eq('user_id', userId);
    if (hobbies.isNotEmpty) {
      await _client.from('user_hobbies').insert(
        hobbies
            .map((h) => {
                  'user_id': userId,
                  'hobby_id': h.hobbyId,
                  'is_primary': h.isPrimary,
                })
            .toList(),
      );
    }
  }
}
