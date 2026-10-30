import 'package:dio/dio.dart';

class AdminUser {
  AdminUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    required this.disabled,
  });
  final String id;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;
  bool disabled;

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['id'] as String,
    email: j['email'] as String,
    name: (j['name'] as String?) ?? '',
    role: j['role'] as String,
    createdAt:
        DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
    disabled: j['disabled'] == true,
  );
}

class AuditEntry {
  AuditEntry({
    required this.admin,
    required this.action,
    required this.detail,
    required this.at,
  });
  final String admin;
  final String action;
  final String? detail;
  final DateTime at;

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    admin: (j['admin'] as String?) ?? 'Admin',
    action: j['action'] as String,
    detail: j['detail'] as String?,
    at: DateTime.tryParse('${j['at']}')?.toLocal() ?? DateTime.now(),
  );
}

class AdminApi {
  AdminApi(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> overview() async =>
      Map<String, dynamic>.from((await dio.get('/admin/overview')).data as Map);

  Future<({List<AdminUser> users, bool hasMore})> users({
    String q = '',
    int offset = 0,
  }) async {
    final r = await dio.get(
      '/admin/users',
      queryParameters: {
        'offset': offset,
        'limit': 30,
        if (q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final list = ((r.data['users'] as List?) ?? const [])
        .map((e) => AdminUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (users: list, hasMore: r.data['has_more'] == true);
  }

  Future<void> disable(String id) => dio.post('/admin/users/$id/disable');
  Future<void> enable(String id) => dio.post('/admin/users/$id/enable');
  Future<void> deleteUser(String id) => dio.delete('/admin/users/$id');

  Future<Map<String, dynamic>> researchSummary() async =>
      Map<String, dynamic>.from(
        (await dio.get('/admin/research/summary')).data as Map,
      );

  /// 'quiz' or 'usage'. Returns the CSV text.
  Future<String> exportCsv(String kind) async {
    final r = await dio.get<String>(
      '/admin/research/export',
      queryParameters: {'kind': kind},
      options: Options(responseType: ResponseType.plain),
    );
    return r.data ?? '';
  }

  Future<List<AuditEntry>> audit() async {
    final r = await dio.get('/admin/audit');
    return ((r.data['entries'] as List?) ?? const [])
        .map((e) => AuditEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
