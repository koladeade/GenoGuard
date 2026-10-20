import 'package:flutter/material.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// 2026-10-20, the day format the API uses.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

DateTime parseYmd(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String toHhmm(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

TimeOfDay parseHhmm(String s) {
  final p = s.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

/// "20:00" -> "8:00 PM"
String label12(String hhmm) {
  final t = parseHhmm(hhmm);
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${_two(t.minute)} ${t.hour < 12 ? 'AM' : 'PM'}';
}

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = [
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

/// "Tue, 15 Sep"
String dayShort(DateTime d) =>
    '${_wd[d.weekday - 1]}, ${d.day} ${_mo[d.month - 1]}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Icon-square colours per reminder type.
const kBlueTint = Color(0xFF25375F);
const kBlue = Color(0xFF7C9BE0);
