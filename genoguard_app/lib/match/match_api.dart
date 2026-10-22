import 'package:dio/dio.dart';

class CodeInfo {
  const CodeInfo({
    required this.id,
    required this.code,
    required this.expiresIn,
  });
  final String id;
  final String code; // 8 characters
  final int expiresIn; // seconds

  /// "K7M2 QX9P"
  String get pretty => '${code.substring(0, 4)} ${code.substring(4)}';

  /// What the QR contains. Only the code, never a name or genotype.
  String get qrData => 'genoguard:$code';
}

class ShareStatus {
  const ShareStatus({
    required this.status,
    this.otherName,
    this.you,
    this.partner,
  });
  final String status; // open | requested | approved | declined | expired
  final String? otherName;
  final String? you; // only when approved
  final String? partner;

  factory ShareStatus.fromJson(Map<String, dynamic> j) => ShareStatus(
    status: j['status'] as String,
    otherName: j['other_name'] as String?,
    you: j['you'] as String?,
    partner: j['partner'] as String?,
  );
}

/// Thin wrapper over the /qr endpoints. Errors are thrown as DioException; show them with errMsg().
class MatchApi {
  MatchApi(this.dio);
  final Dio dio;

  Future<CodeInfo> createCode() async {
    final r = await dio.post('/qr/shares');
    return CodeInfo(
      id: r.data['id'] as String,
      code: r.data['code'] as String,
      expiresIn: (r.data['expires_in'] as num).toInt(),
    );
  }

  /// Returns the share id and the owner's first name.
  Future<({String id, String ownerName})> claim(String code) async {
    final r = await dio.post('/qr/claim', data: {'code': code});
    return (
      id: r.data['id'] as String,
      ownerName: (r.data['other_name'] as String?) ?? 'them',
    );
  }

  Future<ShareStatus> status(String id) async {
    final r = await dio.get('/qr/shares/$id');
    return ShareStatus.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> decide(String id, bool allow) =>
      dio.post('/qr/shares/$id/decision', data: {'allow': allow});
}
