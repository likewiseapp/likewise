import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> sendPasswordResetOTP({required String email}) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: false,
    );
  }

  Future<AuthResponse> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    return _client.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim(),
      token: otp.trim(),
    );
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Returns true if the username is available (not taken).
  Future<bool> isUsernameAvailable(String username) async {
    final data = await _client
        .from('profiles')
        .select('id')
        .eq('username', username.trim().toLowerCase())
        .maybeSingle();
    return data == null;
  }

  /// Creates a profile row for an already-authenticated user.
  /// Used when sign-up succeeded but profile creation failed.
  Future<void> createProfile({
    required String username,
    required String fullName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');
    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email ?? '',
      'username': username.trim().toLowerCase(),
      'full_name': fullName.trim(),
    }, onConflict: 'id');
  }
}
