import 'package:dio/dio.dart';
import 'token_store.dart';

/// Dio client that attaches the access token and, on a 401, refreshes once
/// (single-flight, so parallel requests share one refresh) and retries.
class Api {
  Api(this.tokens) {
    dio = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'API_URL',
          defaultValue: 'http://localhost:3000',
        ),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          final t = tokens.access;
          if (t != null) o.headers['Authorization'] = 'Bearer $t';
          h.next(o);
        },
        onError: (e, h) async {
          final isAuthCall = e.requestOptions.path.startsWith('/auth/');
          if (e.response?.statusCode == 401 &&
              !isAuthCall &&
              e.requestOptions.extra['retried'] != true) {
            if (await refresh()) {
              final o = e.requestOptions..extra['retried'] = true;
              o.headers['Authorization'] = 'Bearer ${tokens.access}';
              try {
                return h.resolve(await dio.fetch(o));
              } on DioException catch (e2) {
                return h.next(e2);
              }
            }
            onSessionExpired?.call();
          }
          h.next(e);
        },
      ),
    );
  }

  final TokenStore tokens;
  late final Dio dio;
  void Function()? onSessionExpired;
  Future<bool>? _refreshing;

  Future<bool> refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final rt = await tokens.refresh;
    if (rt == null) return false;
    try {
      final r = await Dio(
        BaseOptions(baseUrl: dio.options.baseUrl),
      ).post('/auth/refresh', data: {'refresh_token': rt});
      await tokens.save(r.data['access_token'], r.data['refresh_token']);
      return true;
    } on DioException catch (e) {
      // Only drop the session if the server rejected it; keep it on network errors.
      if (e.response?.statusCode == 401) await tokens.clear();
      return false;
    }
  }
}
