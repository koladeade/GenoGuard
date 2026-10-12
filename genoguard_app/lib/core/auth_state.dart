import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api.dart';

const kConsentVersion = '1.0';

enum AuthStatus { unknown, unauthed, authed }

String errMsg(Object e) {
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
  bool consentAccepted =
      false; // in-memory; the server stores the consent record at sign-up

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

  void acceptConsent() {
    consentAccepted = true;
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
    status = AuthStatus.authed;
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required bool hasScd,
    String? genotype,
    String? location,
  }) async {
    final r = await api.dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'has_scd': hasScd,
        'genotype': genotype,
        'location': location,
        'consent': true,
        'consent_version': kConsentVersion,
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
    required bool hasScd,
    String? genotype,
    String? location,
  }) async {
    final r = await api.dio.patch(
      '/me',
      data: {'has_scd': hasScd, 'genotype': genotype, 'location': location},
    );
    user = Map<String, dynamic>.from(r.data['user']);
    notifyListeners(); // role may have changed; the router re-evaluates
  }

  Future<void> deleteAccount(String password) async {
    await api.dio.delete('/me', data: {'password': password});
    _expired();
  }

  void _expired() {
    api.tokens.clear();
    user = null;
    status = AuthStatus.unauthed;
    notifyListeners();
  }
}
