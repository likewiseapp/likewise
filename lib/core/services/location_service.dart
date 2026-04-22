import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import 'profile_service.dart';

class LocationService {
  /// Detect current device location, reverse-geocode it to a display string,
  /// persist it to the user's profile, and invalidate the profile providers.
  ///
  /// Returns true if a location was saved. Fails silently (returns false) on
  /// permission denial, disabled services, or geolocation errors.
  static Future<bool> detectAndSaveForCurrentUser(WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      String? locationLabel;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          locationLabel = [p.locality, p.administrativeArea, p.country]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
        }
      } catch (_) {
        // Reverse geocoding is best-effort; we still save coords.
      }

      final profileService = ProfileService(ref.read(supabaseProvider));
      await profileService.updateProfile(userId, {
        'latitude': position.latitude,
        'longitude': position.longitude,
        if (locationLabel != null && locationLabel.isNotEmpty)
          'location': locationLabel,
      });

      ref.invalidate(fullProfileProvider);
      ref.invalidate(currentProfileProvider);
      return true;
    } catch (_) {
      return false;
    }
  }
}
