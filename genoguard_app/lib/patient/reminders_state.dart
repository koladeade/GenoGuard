import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import '../core/api.dart';
import '../core/auth_state.dart' show errMsg;
import '../core/notifications.dart';
import 'reminder_utils.dart';

const kWaterGoal = 8; // daily target
const kWaterMax = 20; // the counter stops here

class Reminder {
  Reminder({
    required this.id,
    required this.type,
    required this.title,
    required this.recurrence,
    required this.enabled,
    required this.takenCount,
    this.dose,
    this.doctor,
    this.location,
    this.timeOfDay,
    this.onDate,
  });

  final String id;
  final String type; // medication | hydration | appointment
  final String title;
  final String? dose;
  final String? doctor;
  final String? location;
  final String recurrence; // once | daily | every_2_hrs | as_needed
  final String? timeOfDay; // "HH:MM" local
  final DateTime? onDate; // local date, for once / appointments
  final bool enabled;
  final int takenCount; // times logged today

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    id: j['id'] as String,
    type: j['type'] as String,
    title: j['title'] as String,
    dose: j['dose'] as String?,
    doctor: j['doctor'] as String?,
    location: j['location'] as String?,
    recurrence: j['recurrence'] as String,
    timeOfDay: j['time_of_day'] as String?,
    onDate: j['on_date'] == null ? null : parseYmd(j['on_date'] as String),
    enabled: j['enabled'] as bool,
    takenCount: (j['taken_count'] as num?)?.toInt() ?? 0,
  );

  Reminder copyWith({bool? enabled, int? takenCount}) => Reminder(
    id: id,
    type: type,
    title: title,
    dose: dose,
    doctor: doctor,
    location: location,
    recurrence: recurrence,
    timeOfDay: timeOfDay,
    onDate: onDate,
    enabled: enabled ?? this.enabled,
    takenCount: takenCount ?? this.takenCount,
  );

  String get displayTitle =>
      (dose == null || dose!.isEmpty) ? title : '$title $dose';

  bool get isAsNeeded => recurrence == 'as_needed';
  bool get isMedication => type == 'medication';
  bool get isAppointment => type == 'appointment';

  /// Minutes-from-midnight for "every 2 hrs": the start time, then every 2 hours until 9 PM.
  List<int> get slotMinutes {
    if (timeOfDay == null) return const [];
    final t = parseHhmm(timeOfDay!);
    final start = t.hour * 60 + t.minute;
    final out = <int>[];
    for (var m = start; m <= 21 * 60 && out.length < 8; m += 120) {
      out.add(m);
    }
    return out.isEmpty ? [start] : out;
  }

  String get repeatLabel => switch (recurrence) {
    'once' => 'Once',
    'daily' => 'Daily',
    'every_2_hrs' => 'Every 2 hrs',
    _ => 'As needed',
  };

  /// Next time this fires, or null
  DateTime? next(DateTime now) {
    if (timeOfDay == null) return null;
    final t = parseHhmm(timeOfDay!);
    DateTime at(DateTime d, int h, int m) =>
        DateTime(d.year, d.month, d.day, h, m);
    switch (recurrence) {
      case 'once':
        {
          if (onDate == null) return null;
          final a = at(onDate!, t.hour, t.minute);
          return a.isAfter(now) ? a : null;
        }
      case 'daily':
        {
          final a = at(now, t.hour, t.minute);
          return a.isAfter(now) ? a : a.add(const Duration(days: 1));
        }
      case 'every_2_hrs':
        {
          for (final m in slotMinutes) {
            final a = at(now, m ~/ 60, m % 60);
            if (a.isAfter(now)) return a;
          }
          final first = slotMinutes.first;
          return at(now.add(const Duration(days: 1)), first ~/ 60, first % 60);
        }
    }
    return null;
  }
}

/// One list for medication, hydration and appointment reminders, plus the daily water counter.
class RemindersState extends ChangeNotifier with WidgetsBindingObserver {
  RemindersState(this.api) {
    WidgetsBinding.instance.addObserver(this);
    _armMidnight();
  }
  final Api api;

  Timer? _midnight;
  String _loadedDay = ymd(DateTime.now());

  void _armMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 2);
    _midnight = Timer(next.difference(now), () {
      load(silent: true);
      _armMidnight();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _armMidnight();
    if (ymd(DateTime.now()) != _loadedDay) load(silent: true);
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<Reminder> reminders = [];
  int glasses = 0;
  bool loading = true;
  bool notifOn = false;
  String? error;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final day = ymd(DateTime.now());
      final r = await api.dio.get('/reminders', queryParameters: {'day': day});
      reminders = [
        for (final e in r.data['reminders'] as List)
          Reminder.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
      await _purgeFinished();
      final w = await api.dio.get(
        '/reminders/water',
        queryParameters: {'day': day},
      );
      glasses = (w.data['glasses'] as num).toInt();
      error = null;
      Notifier.instance.reschedule(reminders);
      notifOn = await Notifier.instance.isEnabled();
    } catch (e) {
      error = errMsg(e);
    }
    loading = false;
    notifyListeners();
  }

  /// One-off reminders delete themselves once their time has passed. Daily and every-2-hours stay.
  Future<void> _purgeFinished() async {
    final now = DateTime.now();
    final done = reminders
        .where((r) => r.recurrence == 'once' && r.next(now) == null)
        .toList();
    final gone = <String>{};
    for (final r in done) {
      try {
        await api.dio.delete('/reminders/${r.id}');
        gone.add(r.id);
      } catch (_) {
        // Keep it; we'll try again on the next refresh.
      }
    }
    if (gone.isNotEmpty)
      reminders = reminders.where((r) => !gone.contains(r.id)).toList();
  }

  /// Soonest upcoming reminders, for the Home card.
  List<({Reminder reminder, DateTime at})> nextUp({int limit = 3}) {
    final now = DateTime.now();
    final out = <({Reminder reminder, DateTime at})>[];
    for (final r in reminders) {
      if (!r.enabled) continue;
      final a = r.next(now);
      if (a == null) continue;
      // A medication already ticked off today shouldn't keep showing for today.
      if (r.isMedication && r.takenCount > 0 && sameDate(a, now)) continue;
      out.add((reminder: r, at: a));
    }
    out.sort((x, y) => x.at.compareTo(y.at));
    return out.take(limit).toList();
  }

  static bool sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // The calls below throw on failure so the sheet can show the message.

  Future<void> create(Map<String, dynamic> body) async {
    await api.dio.post('/reminders', data: body);
    await _afterChange();
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    await api.dio.put('/reminders/$id', data: body);
    await _afterChange();
  }

  Future<void> remove(String id) async {
    await api.dio.delete('/reminders/$id');
    await _afterChange();
  }

  Future<void> _afterChange() async {
    await load(silent: true);
    if (!notifOn) {
      notifOn = await Notifier.instance.requestPermission();
      if (notifOn) Notifier.instance.reschedule(reminders);
      notifyListeners();
    }
  }

  // The calls below update the screen first, then sync, and roll back on failure.

  Future<void> setEnabled(String id, bool value) async {
    final before = reminders;
    reminders = [
      for (final r in reminders) r.id == id ? r.copyWith(enabled: value) : r,
    ];
    notifyListeners();
    try {
      await api.dio.patch('/reminders/$id', data: {'enabled': value});
      Notifier.instance.reschedule(reminders);
    } catch (e) {
      reminders = before;
      error = errMsg(e);
      notifyListeners();
    }
  }

  /// Tick or untick a scheduled dose for today.
  Future<void> setTaken(String id, bool taken) async {
    final before = reminders;
    reminders = [
      for (final r in reminders)
        r.id == id ? r.copyWith(takenCount: taken ? 1 : 0) : r,
    ];
    notifyListeners();
    try {
      final day = ymd(DateTime.now());
      if (taken) {
        await api.dio.post('/reminders/$id/log', data: {'day': day});
      } else {
        await api.dio.delete(
          '/reminders/$id/log',
          queryParameters: {'day': day},
        );
      }
    } catch (e) {
      reminders = before;
      error = errMsg(e);
      notifyListeners();
    }
  }

  Future<void> setGlasses(int value) async {
    final v = value.clamp(0, kWaterMax);
    final before = glasses;
    glasses = v;
    notifyListeners();
    try {
      await api.dio.put(
        '/reminders/water',
        data: {'day': ymd(DateTime.now()), 'glasses': v},
      );
    } catch (e) {
      glasses = before;
      error = errMsg(e);
      notifyListeners();
    }
  }

  Future<void> previewNotification() async {
    notifOn = await Notifier.instance.requestPermission();
    await Notifier.instance.preview();
    notifyListeners();
  }
}
