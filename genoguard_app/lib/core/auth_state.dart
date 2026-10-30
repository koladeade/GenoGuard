import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'api.dart';
import 'google_auth.dart';

const kConsentVersion = '1.0';

enum AuthStatus { unknown, unauthed, authed }

String errMsg(Object e) {
  if (e is GoogleNotConfigured) return 'Google sign-in is not set up yet.';
  if (e is PlatformException) return 'Google sign-in failed. Try again.';
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] != null) return d['error'].toString();
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Cannot reach the server. Check your connection.';
    }
  }
  return 'Something went wrong. Try again.';
}

class AuthState extends ChangeNotifier {
  AuthState(this.api) {
    api.onSessionExpired = _expired;
  }

  final Api api;
  AuthStatus status = AuthStatus.unknown;
  Map<String, dynamic>? user;

  // Held in memory between the consent screen and account creation.
  bool consentAccepted = false;
  bool usageLogsConsent = false;

  /// Set when a Google account has no GenoGuard account yet: {id_token, email, name}.
  Map<String, dynamic>? pendingGoogle;

  String? get role => user?['role'] as String?;

  Future<void> boot() async {
    if (await api.tokens.refresh != null && await api.refresh()) {
      try {
        await _loadMe();
        return;
      } catch (_) {}
    }
    status = AuthStatus.unauthed;
    notifyListeners();
  }

  void acceptConsent({required bool usageLogs}) {
    consentAccepted = true;
    usageLogsConsent = usageLogs;
    notifyListeners();
  }

  Future<void> _loadMe() async {
    final r = await api.dio.get('/me');
    user = Map<String, dynamic>.from(r.data['user']);
    status = AuthStatus.authed;
    notifyListeners();
  }

  Future<void> _adopt(Response r) async {
    await api.tokens.save(r.data['access_token'], r.data['refresh_token']);
    user = Map<String, dynamic>.from(r.data['user']);
    pendingGoogle = null;
    status = AuthStatus.authed;
    notifyListeners();
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required bool hasScd,
    String? genotype,
    String? location,
  }) async {
    final r = await api.dio.post(
      '/auth/register',
      data: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'has_scd': hasScd,
        'genotype': genotype,
        'location': location,
        'consent': true,
        'consent_version': kConsentVersion,
        'usage_logs': usageLogsConsent,
      }..removeWhere((k, v) => v == null),
    );
    await _adopt(r);
  }

  Future<void> login(String email, String password) async {
    await _adopt(
      await api.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      ),
    );
  }

  /// Opens Google, then asks the API. Returns true if this Google account is new and the app
  /// must collect consent and the SCD answer before the account can be created.
  Future<bool> signInWithGoogle() async {
    final idToken = await GoogleAuth.idToken();
    if (idToken == null) return false; // cancelled
    final r = await api.dio.post('/auth/google', data: {'id_token': idToken});
    if (r.data['status'] == 'needs_profile') {
      pendingGoogle = {
        'id_token': idToken,
        'email': r.data['email'],
        'name': r.data['name'],
      };
      notifyListeners();
      return true;
    }
    await _adopt(r);
    return false;
  }

  Future<void> completeGoogleSignup({
    required String fullName,
    required bool hasScd,
    String? genotype,
    String? location,
  }) async {
    final p = pendingGoogle!;
    final r = await api.dio.post(
      '/auth/google',
      data: {
        'id_token': p['id_token'],
        'full_name': fullName,
        'has_scd': hasScd,
        'genotype': genotype,
        'location': location,
        'consent': true,
        'consent_version': kConsentVersion,
        'usage_logs': usageLogsConsent,
      }..removeWhere((k, v) => v == null),
    );
    await _adopt(r);
  }

  void cancelGoogle() {
    pendingGoogle = null;
    notifyListeners();
  }

  Future<void> logout() async {
    final rt = await api.tokens.refresh;
    try {
      if (rt != null)
        await api.dio.post('/auth/logout', data: {'refresh_token': rt});
    } catch (_) {}
    _expired();
  }

  Future<void> forgotPassword(String email) =>
      api.dio.post('/auth/forgot-password', data: {'email': email});

  Future<void> resetPassword(String email, String code, String newPassword) =>
      api.dio.post(
        '/auth/reset-password',
        data: {'email': email, 'code': code, 'new_password': newPassword},
      );

  Future<void> updateProfile({
    required String fullName,
    required bool hasScd,
    String? genotype,
    String? location,
  }) async {
    final r = await api.dio.patch(
      '/me',
      data: {
        'full_name': fullName,
        'has_scd': hasScd,
        'genotype': genotype,
        'location': location,
      },
    );
    user = Map<String, dynamic>.from(r.data['user']);
    notifyListeners();
  }

  Future<void> setUsageLogs(bool on) async {
    final r = await api.dio.patch('/me', data: {'usage_logs_consent': on});
    user = Map<String, dynamic>.from(r.data['user']);
    notifyListeners();
  }

  /// Password accounts pass their password; Google-only accounts pass null.
  Future<void> deleteAccount(String? password) async {
    await api.dio.delete(
      '/me',
      data: password != null ? {'password': password} : {'confirm': true},
    );
    _expired();
  }

  void _expired() {
    api.tokens.clear();
    user = null;
    pendingGoogle = null;
    status = AuthStatus.unauthed;
    notifyListeners();
  }
}
