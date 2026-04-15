import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleAuthService {
  GoogleAuthService(this._client);

  final SupabaseClient _client;

  static const _webClientId =
      '37982742852-kc171e10f7d0ndgjv50ajdjmacp98q0b.apps.googleusercontent.com';

  final _googleSignIn = GoogleSignIn(serverClientId: _webClientId);

  Future<AuthResponse> signInWithGoogle() async {
    await _googleSignIn.signOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw 'Google Sign-In was cancelled.';
    }

    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) throw 'No Access Token from Google.';
    if (idToken == null) throw 'No ID Token from Google.';

    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    await _googleSignIn.signOut();
  }
}
