import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
