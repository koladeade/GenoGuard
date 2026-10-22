import 'package:google_sign_in/google_sign_in.dart';

class GoogleNotConfigured implements Exception {}

class GoogleAuth {
  static const _iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '333142466396-abh1ptovdr2541hb5hk8gj8pq7pln3u0.apps.googleusercontent.com',
  );
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '333142466396-6qisfe4t9pbre94audjscsfou0oa426c.apps.googleusercontent.com',
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
