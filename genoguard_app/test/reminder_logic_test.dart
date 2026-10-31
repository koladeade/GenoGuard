import 'package:flutter_test/flutter_test.dart';
import 'package:genoguard_app/patient/reminder_utils.dart';
import 'package:genoguard_app/patient/reminders_state.dart';

Reminder make(String recurrence, {String? time, DateTime? on}) => Reminder(
  id: '1',
  type: 'medication',
  title: 'Folic acid',
  recurrence: recurrence,
  enabled: true,
  takenCount: 0,
  timeOfDay: time,
  onDate: on,
);

void main() {
  group('Date and time helpers', () {
    test('ymd pads month and day', () {
      expect(ymd(DateTime(2026, 3, 5)), '2026-03-05');
    });

    test('parseYmd is the inverse of ymd', () {
      expect(ymd(parseYmd('2026-10-31')), '2026-10-31');
    });

    test('label12 shows 12-hour times', () {
      expect(label12('20:00'), '8:00 PM');
      expect(label12('00:30'), '12:30 AM');
      expect(label12('12:00'), '12:00 PM');
    });
  });

  group('Next reminder time', () {
    final morning = DateTime(2026, 10, 31, 8, 0);
    final evening = DateTime(2026, 10, 31, 20, 30);

    test('daily reminder later today fires today', () {
      expect(
        make('daily', time: '09:00').next(morning),
        DateTime(2026, 10, 31, 9, 0),
      );
    });

    test('daily reminder already passed fires tomorrow', () {
      expect(
        make('daily', time: '09:00').next(evening),
        DateTime(2026, 11, 1, 9, 0),
      );
    });

    test('every 2 hours starts at the start time and ends by 9 PM', () {
      final r = make('every_2_hrs', time: '08:00');
      expect(r.slotMinutes, [
        480,
        600,
        720,
        840,
        960,
        1080,
        1200,
      ]); // 08:00 ... 20:00
    });

    test('every 2 hours picks the next slot today', () {
      final r = make('every_2_hrs', time: '08:00');
      expect(
        r.next(DateTime(2026, 10, 31, 9, 0)),
        DateTime(2026, 10, 31, 10, 0),
      );
    });

    test('every 2 hours after the last slot rolls to tomorrow morning', () {
      final r = make('every_2_hrs', time: '08:00');
      expect(r.next(evening), DateTime(2026, 11, 1, 8, 0));
    });

    test('a one-off in the past has no next time, so it can be cleaned up', () {
      final r = make('once', time: '09:00', on: DateTime(2026, 10, 30));
      expect(r.next(morning), isNull);
    });

    test('a one-off in the future fires at its date and time', () {
      final r = make('once', time: '09:00', on: DateTime(2026, 11, 2));
      expect(r.next(morning), DateTime(2026, 11, 2, 9, 0));
    });

    test('as-needed reminders never fire on a schedule', () {
      expect(make('as_needed').next(morning), isNull);
    });
  });
}
