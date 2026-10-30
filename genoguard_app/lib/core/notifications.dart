import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../patient/reminders_state.dart';
import '../patient/reminder_utils.dart';

/// Local (on-device) notifications. They fire at the reminder time even when the app is closed,
/// and need no push server.
class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifier.init failed: $e');
    }
  }

  Future<bool> isEnabled() async {
    await init();
    if (!_ready) return false;
    try {
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return (await ios?.checkPermissions())?.isEnabled ?? false;
      }
      if (Platform.isAndroid) {
        final a = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await a?.areNotificationsEnabled() ?? false;
      }
    } catch (e) {
      debugPrint('Notifier.isEnabled failed: $e');
    }
    return false;
  }

  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      if (Platform.isAndroid) {
        final a = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await a?.requestNotificationsPermission() ?? false;
      }
    } catch (e) {
      debugPrint('Notifier.requestPermission failed: $e');
    }
    return false;
  }

  Future<void> preview() async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        0,
        'GenoGuard reminder',
        'This is how your reminders will look.',
        _details,
      );
    } catch (e) {
      debugPrint('Notifier.preview failed: $e');
    }
  }

  /// Cancels everything and schedules the current set again.
  Future<void> reschedule(List<Reminder> reminders) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      var id = 1;
      final now = tz.TZDateTime.now(tz.local);

      for (final r in reminders) {
        if (!r.enabled || r.timeOfDay == null) continue;
        final t = parseHhmm(r.timeOfDay!);

        if (r.type == 'appointment') {
          final d = r.onDate;
          if (d == null) continue;
          final at = tz.TZDateTime(
            tz.local,
            d.year,
            d.month,
            d.day,
            t.hour,
            t.minute,
          );
          final who = r.doctor == null
              ? r.title
              : '${r.title} with ${r.doctor}';
          final dayBefore = at.subtract(const Duration(days: 1));
          final hourBefore = at.subtract(const Duration(hours: 1));
          if (dayBefore.isAfter(now))
            await _once(
              id++,
              'Appointment tomorrow',
              '$who at ${label12(r.timeOfDay!)}',
              dayBefore,
            );
          if (hourBefore.isAfter(now))
            await _once(id++, 'Appointment in 1 hour', who, hourBefore);
          if (at.isAfter(now))
            await _once(
              id++,
              'Appointment now',
              '$who at ${label12(r.timeOfDay!)}',
              at,
            );
          continue;
        }

        final title = r.type == 'medication'
            ? 'Time for your medication'
            : 'Time to hydrate';
        final body = r.displayTitle;

        switch (r.recurrence) {
          case 'once':
            {
              final d = r.onDate;
              if (d == null) continue;
              final at = tz.TZDateTime(
                tz.local,
                d.year,
                d.month,
                d.day,
                t.hour,
                t.minute,
              );
              if (at.isAfter(now)) await _once(id++, title, body, at);
            }
          case 'daily':
            await _daily(id++, title, body, t.hour, t.minute, now);
          case 'every_2_hrs':
            for (final m in r.slotMinutes) {
              await _daily(id++, title, body, m ~/ 60, m % 60, now);
            }
        }
      }
    } catch (e) {
      debugPrint('Notifier.reschedule failed: $e');
    }
  }

  Future<void> _once(int id, String title, String body, tz.TZDateTime at) =>
      _plugin.zonedSchedule(
        id,
        title,
        body,
        at,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

  Future<void> _daily(
    int id,
    String title,
    String body,
    int h,
    int m,
    tz.TZDateTime now,
  ) {
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      at,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
