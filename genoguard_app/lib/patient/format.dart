import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const kPainAreas = [
  'Back',
  'Chest',
  'Legs',
  'Arms',
  'Abdomen',
  'Joints',
  'Head',
];

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _monthsFull = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String two(int n) => n.toString().padLeft(2, '0');

String monthFull(int month) => _monthsFull[month - 1];

String entryTitle(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_monthsShort[d.month - 1]} · ${two(d.hour)}:${two(d.minute)}';

String dayLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_monthsShort[d.month - 1]}'
        .toUpperCase();

String dateField(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

String timeField(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  return '${two(h)}:${two(t.minute)} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Colors for the pain scale: 0-3 mild, 4-6 moderate, 7-10 severe.
class PainTone {
  const PainTone(this.fg, this.bg);
  final Color fg;
  final Color bg;
}

PainTone toneFor(int intensity) {
  if (intensity >= 7) return const PainTone(AppColors.red, AppColors.redTint);
  if (intensity >= 4)
    return const PainTone(AppColors.gold, AppColors.amberTint);
  return const PainTone(AppColors.green, AppColors.greenTint);
}
