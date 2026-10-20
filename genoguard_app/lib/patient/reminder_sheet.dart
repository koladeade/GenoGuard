import 'package:flutter/material.dart';
import '../core/auth_state.dart' show errMsg;
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'format.dart';
import 'pill_tabs.dart';
import 'reminder_utils.dart';
import 'reminders_state.dart';

/// "New reminder" / "Edit reminder" sheet. [state] is passed in because the sheet lives on the root
/// navigator, outside the patient shell's provider. [type] pre-selects the type (from the filter chip).
Future<void> showReminderSheet(
  BuildContext context,
  RemindersState state, {
  Reminder? edit,
  String? type,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => _ReminderSheet(state: state, edit: edit, initialType: type),
  );
}

const _types = ['hydration', 'medication', 'appointment'];
const _typeLabels = ['Hydration', 'Medication', 'Appointment'];

// Allowed repeats per type, mirrored on the API.
const _repeats = {
  'hydration': ['once', 'daily', 'every_2_hrs'],
  'medication': ['once', 'daily'],
  'appointment': ['once'],
};
const _repeatLabels = {
  'once': 'Once',
  'daily': 'Daily',
  'every_2_hrs': 'Every 2 hrs',
};

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.state, this.edit, this.initialType});
  final RemindersState state;
  final Reminder? edit;
  final String? initialType;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  final _title = TextEditingController();
  final _dose = TextEditingController();
  final _doctor = TextEditingController();
  final _location = TextEditingController();
  late String _type;
  late String _repeat;
  late TimeOfDay _time;
  late DateTime _date;
  bool _busy = false;
  String? _err;

  bool get _editing => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _type = e.type;
      _repeat = e.recurrence;
      _title.text = e.title;
      _dose.text = e.dose ?? '';
      _doctor.text = e.doctor ?? '';
      _location.text = e.location ?? '';
      _time = e.timeOfDay == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : parseHhmm(e.timeOfDay!);
      _date = e.onDate ?? dateOnly(DateTime.now());
    } else {
      _type = widget.initialType ?? 'hydration';
      _repeat = _defaultRepeat(_type);
      _time = _defaultTime(_type);
      _date = dateOnly(
        DateTime.now().add(Duration(days: _type == 'appointment' ? 1 : 0)),
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _dose.dispose();
    _doctor.dispose();
    _location.dispose();
    super.dispose();
  }

  String _defaultRepeat(String t) =>
      t == 'hydration' ? 'every_2_hrs' : (t == 'medication' ? 'daily' : 'once');
  TimeOfDay _defaultTime(String t) => t == 'appointment'
      ? const TimeOfDay(hour: 10, minute: 0)
      : const TimeOfDay(hour: 9, minute: 0);

  void _setType(String t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      if (!_repeats[t]!.contains(_repeat)) _repeat = _defaultRepeat(t);
      if (t == 'appointment' && _date.isBefore(dateOnly(DateTime.now()))) {
        _date = dateOnly(DateTime.now().add(const Duration(days: 1)));
      }
    });
  }

  void _quick(String type, String title, String repeat) {
    setState(() {
      _type = type;
      _title.text = title;
      _repeat = repeat;
      _time = _defaultTime(type);
    });
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final first = _date.isBefore(today) ? _date : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _err = 'Add a name');
      return;
    }
    final needsDate = _repeat == 'once';
    const needsTime = true;
    if (!_editing && needsDate && needsTime) {
      final at = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );
      if (!at.isAfter(DateTime.now())) {
        setState(() => _err = 'Pick a time in the future');
        return;
      }
    }
    final body = <String, dynamic>{
      'type': _type,
      'title': title,
      'repeat': _repeat,
      if (_type == 'medication' && _dose.text.trim().isNotEmpty)
        'dose': _dose.text.trim(),
      if (_type == 'appointment' && _doctor.text.trim().isNotEmpty)
        'doctor': _doctor.text.trim(),
      if (_type == 'appointment' && _location.text.trim().isNotEmpty)
        'location': _location.text.trim(),
      if (needsTime) 'time_of_day': toHhmm(_time),
      if (needsDate) 'on_date': ymd(_date),
    };
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      if (_editing) {
        await widget.state.update(widget.edit!.id, body);
      } else {
        await widget.state.create(body);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete this reminder?', style: AppText.heading(22)),
        content: Text(
          'This cannot be undone.',
          style: AppText.body(16, FontWeight.w500, AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppText.body(16, FontWeight.w600, AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: AppText.body(16, FontWeight.w700, AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.state.remove(widget.edit!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = errMsg(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final repeats = _repeats[_type]!;
    const showTime = true;
    final showDate = _repeat == 'once';

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? 'Edit reminder' : 'New reminder',
                    style: AppText.heading(26),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: AppText.body(16, FontWeight.w600, AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (!_editing) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _QuickChip(
                    'Drink water',
                    () => _quick('hydration', 'Drink water', 'every_2_hrs'),
                  ),
                  _QuickChip(
                    'Hydroxyurea',
                    () => _quick('medication', 'Hydroxyurea', 'daily'),
                  ),
                  _QuickChip(
                    'Folic acid',
                    () => _quick('medication', 'Folic acid', 'daily'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],

            const FieldLabel('What for'),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.body(16),
              decoration: InputDecoration(
                hintText: _type == 'appointment'
                    ? 'e.g. Haematology review'
                    : 'e.g. Drink water',
              ),
            ),
            const SizedBox(height: 18),

            _Label('TYPE'),
            const SizedBox(height: 10),
            PillTabs(
              labels: _typeLabels,
              selected: _types.indexOf(_type),
              onChanged: (i) => _setType(_types[i]),
            ),
            const SizedBox(height: 18),

            if (_type == 'medication') ...[
              const FieldLabel('Dose (optional)'),
              TextField(
                controller: _dose,
                style: AppText.body(16),
                decoration: const InputDecoration(hintText: 'e.g. 500 mg'),
              ),
              const SizedBox(height: 18),
            ],
            if (_type == 'appointment') ...[
              const FieldLabel('Doctor (optional)'),
              TextField(
                controller: _doctor,
                textCapitalization: TextCapitalization.words,
                style: AppText.body(16),
                decoration: const InputDecoration(hintText: 'e.g. Dr. Sandra'),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Location (optional)'),
              TextField(
                controller: _location,
                textCapitalization: TextCapitalization.words,
                style: AppText.body(16),
                decoration: const InputDecoration(
                  hintText: 'e.g. Lagos University Teaching Hospital',
                ),
              ),
              const SizedBox(height: 18),
            ],

            if (_type != 'appointment') ...[
              _Label('REPEAT'),
              const SizedBox(height: 10),
              PillTabs(
                gold: true,
                labels: [for (final r in repeats) _repeatLabels[r]!],
                selected: repeats.indexOf(_repeat).clamp(0, repeats.length - 1),
                onChanged: (i) => setState(() => _repeat = repeats[i]),
              ),
              const SizedBox(height: 18),
            ],

            Row(
              children: [
                if (showDate)
                  Expanded(
                    child: _PickerField(
                      label: 'Date',
                      value: dateField(_date),
                      icon: Icons.calendar_today_outlined,
                      onTap: _pickDate,
                    ),
                  ),
                if (showDate && showTime) const SizedBox(width: 12),
                if (showTime)
                  Expanded(
                    child: _PickerField(
                      label: _repeat == 'every_2_hrs' ? 'Starting at' : 'Time',
                      value: timeField(_time),
                      icon: Icons.schedule,
                      onTap: _pickTime,
                    ),
                  ),
              ],
            ),
            if (_repeat == 'every_2_hrs') ...[
              const SizedBox(height: 8),
              Text(
                'Repeats every 2 hours until 9 PM each day.',
                style: AppText.body(14, FontWeight.w500, AppColors.muted),
              ),
            ],
            if (_type == 'appointment') ...[
              const SizedBox(height: 8),
              Text(
                'You will be reminded 1 day before, 1 hour before and at the time.',
                style: AppText.body(14, FontWeight.w500, AppColors.muted),
              ),
            ],
            ErrorText(_err),
            const SizedBox(height: 16),
            PrimaryButton(
              _editing ? 'Save changes' : 'Save reminder',
              onPressed: _save,
              busy: _busy,
            ),
            if (_editing)
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _delete,
                  child: Text(
                    'Delete reminder',
                    style: AppText.body(16, FontWeight.w700, AppColors.error),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppText.body(
      14,
      FontWeight.w700,
      AppColors.muted,
    ).copyWith(letterSpacing: 1.2),
  );
}

class _QuickChip extends StatelessWidget {
  const _QuickChip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Text(
        '+ $label',
        style: AppText.body(15, FontWeight.w600, AppColors.gold),
      ),
    ),
  );
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(label),
      InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: AppText.body(17, FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 20, color: AppColors.text),
            ],
          ),
        ),
      ),
    ],
  );
}
