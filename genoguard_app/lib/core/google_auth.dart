import 'package:google_sign_in/google_sign_in.dart';

class GoogleNotConfigured implements Exception {}

/// Gets a Google ID token on the device. The API verifies it; the app never trusts it.
///
/// Pass the client IDs when running:
///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com \
///               --dart-define=GOOGLE_IOS_CLIENT_ID=yyy.apps.googleusercontent.com
class GoogleAuth {
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static GoogleSignIn? _client;

  /// Returns the ID token, or null if the user closed the Google sheet.
  static Future<String?> idToken() async {
    if (_serverClientId.isEmpty) throw GoogleNotConfigured();
    final gs = _client ??= GoogleSignIn(
      scopes: const ['email', 'profile'],
      clientId: _iosClientId.isEmpty ? null : _iosClientId,
      serverClientId: _serverClientId,
    );
    await gs.signOut(); // always show the account picker
    final account = await gs.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }
}
