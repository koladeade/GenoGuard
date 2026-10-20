import 'package:flutter/foundation.dart';
import '../core/api.dart';
import '../core/auth_state.dart' show errMsg;
import 'format.dart';

class PainEntry {
  PainEntry({
    required this.id,
    required this.at,
    required this.intensity,
    required this.areas,
    required this.isCrisis,
    this.notes,
  });

  final String id;
  final DateTime at; // local time
  final int intensity;
  final List<String> areas;
  final String? notes;
  final bool isCrisis;

  factory PainEntry.fromJson(Map<String, dynamic> j) => PainEntry(
    id: j['id'] as String,
    at: DateTime.parse(j['occurred_at'] as String).toLocal(),
    intensity: (j['intensity'] as num).toInt(),
    areas: List<String>.from(j['areas'] as List),
    notes: j['notes'] as String?,
    isCrisis: j['is_crisis'] as bool,
  );
}

class RecoveryPoint {
  const RecoveryPoint(this.day, this.avg);
  final int day;
  final double avg;
}

class PainSummary {
  const PainSummary({
    this.daysSinceCrisis,
    this.personalBest,
    this.points = const [],
    this.spanDays = 0,
    this.reachesToday = false,
    this.changePct,
  });

  final int? daysSinceCrisis;
  final int? personalBest;
  final List<RecoveryPoint> points;
  final int spanDays;
  final bool reachesToday;
  final int? changePct;

  bool get hasCrisis => daysSinceCrisis != null;

  factory PainSummary.fromJson(Map<String, dynamic> j) {
    final rec = Map<String, dynamic>.from(j['recovery'] as Map);
    return PainSummary(
      daysSinceCrisis: (j['days_since_crisis'] as num?)?.toInt(),
      personalBest: (j['personal_best'] as num?)?.toInt(),
      points: [
        for (final p in rec['points'] as List)
          RecoveryPoint(
            (p['day'] as num).toInt(),
            (p['avg'] as num).toDouble(),
          ),
      ],
      spanDays: (rec['span_days'] as num).toInt(),
      reachesToday: rec['reaches_today'] as bool,
      changePct: (rec['change_pct'] as num?)?.toInt(),
    );
  }
}

/// Shared by the Home and Pain tabs so a new entry updates both.
class PainState extends ChangeNotifier {
  PainState(this.api);
  final Api api;

  List<PainEntry> entries = []; // newest first
  PainSummary summary = const PainSummary();
  int window = 14; // recovery chart: 7, 14 or 30 days
  bool loading = true;
  String? error;

  static int get _tzOffsetMinutes => DateTime.now().timeZoneOffset.inMinutes;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final from = DateTime.now()
          .subtract(const Duration(days: 400))
          .toUtc()
          .toIso8601String();
      final r = await api.dio.get(
        '/pain',
        queryParameters: {'from': from, 'limit': 1000},
      );
      entries = [
        for (final e in r.data['entries'] as List)
          PainEntry.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
      await _loadSummary();
      error = null;
    } catch (e) {
      error = errMsg(e);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _loadSummary() async {
    final r = await api.dio.get(
      '/pain/summary',
      queryParameters: {'tz_offset': _tzOffsetMinutes, 'days': window},
    );
    summary = PainSummary.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> setWindow(int days) async {
    window = days;
    notifyListeners();
    try {
      await _loadSummary();
    } catch (e) {
      error = errMsg(e);
    }
    notifyListeners();
  }

  /// Throws on failure so the entry sheet can show the message.
  Future<void> add({
    required DateTime at,
    required int intensity,
    required List<String> areas,
    String? notes,
    required bool crisis,
  }) async {
    await api.dio.post(
      '/pain',
      data: {
        'occurred_at': at.toUtc().toIso8601String(),
        'intensity': intensity,
        'areas': areas,
        if (notes != null) 'notes': notes,
        'is_crisis': crisis,
      },
    );
    await load(silent: true);
  }

  Future<void> remove(String id) async {
    await api.dio.delete('/pain/$id');
    await load(silent: true);
  }

  List<PainEntry> forDay(DateTime d) =>
      entries.where((e) => sameDay(e.at, d)).toList();
}
