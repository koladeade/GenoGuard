import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Only the refresh token is persisted, in the iOS Keychain / Android Keystore-backed
/// storage. The short-lived access token lives in memory and is re-issued on launch.
class TokenStore {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _refreshKey = 'refresh_token';

  String? access;

  Future<String?> get refresh => _storage.read(key: _refreshKey);

  Future<void> save(String accessToken, String refreshToken) async {
    access = accessToken;
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    access = null;
    await _storage.delete(key: _refreshKey);
  }
}
