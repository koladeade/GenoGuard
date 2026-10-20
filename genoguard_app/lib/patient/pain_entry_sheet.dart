import 'package:flutter/material.dart';
import '../core/auth_state.dart' show errMsg;
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'format.dart';
import 'pain_state.dart';

/// Opens the "New pain entry" bottom sheet. [state] is passed in because the sheet lives on the
/// root navigator, outside the patient shell's provider.
Future<void> showPainEntrySheet(
  BuildContext context,
  PainState state, {
  DateTime? day,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => _PainEntrySheet(state: state, day: day),
  );
}

class _PainEntrySheet extends StatefulWidget {
  const _PainEntrySheet({required this.state, this.day});
  final PainState state;
  final DateTime? day;

  @override
  State<_PainEntrySheet> createState() => _PainEntrySheetState();
}

class _PainEntrySheetState extends State<_PainEntrySheet> {
  late DateTime _date;
  late TimeOfDay _time;
  double _intensity = 4;
  final Set<String> _areas = {};
  final _notes = TextEditingController();
  bool _crisis = false;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final d = widget.day ?? now;
    _date = DateTime(d.year, d.month, d.day);
    _time = sameDay(_date, now)
        ? TimeOfDay.fromDateTime(now)
        : const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_areas.isEmpty) {
      setState(() => _err = 'Choose where it hurts');
      return;
    }
    final at = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    if (at.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      setState(() => _err = 'That time is in the future');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final notes = _notes.text.trim();
      await widget.state.add(
        at: at,
        intensity: _intensity.round(),
        areas: kPainAreas.where(_areas.contains).toList(),
        notes: notes.isEmpty ? null : notes,
        crisis: _crisis,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final tone = toneFor(_intensity.round());

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
                  child: Text('New pain entry', style: AppText.heading(26)),
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: 'Date',
                    value: dateField(_date),
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerField(
                    label: 'Time',
                    value: timeField(_time),
                    icon: Icons.schedule,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Intensity',
                    style: AppText.body(19, FontWeight.w600),
                  ),
                ),
                Text(
                  '${_intensity.round()}/10',
                  style: AppText.body(28, FontWeight.w700, tone.fg),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.gold,
                inactiveTrackColor: const Color(0xFF3A3F55),
                thumbColor: AppColors.gold,
                overlayColor: AppColors.gold.withAlpha(40),
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
                tickMarkShape: SliderTickMarkShape.noTickMark,
              ),
              child: Slider(
                value: _intensity,
                min: 0,
                max: 10,
                divisions: 10,
                onChanged: (v) => setState(() => _intensity = v),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'WHERE DOES IT HURT?',
              style: AppText.body(
                14,
                FontWeight.w700,
                AppColors.muted,
              ).copyWith(letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final a in kPainAreas)
                  _AreaChip(
                    label: a,
                    selected: _areas.contains(a),
                    onTap: () => setState(() {
                      if (!_areas.remove(a)) _areas.add(a);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const FieldLabel('Notes'),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              style: AppText.body(16),
              decoration: const InputDecoration(
                hintText: 'What helped? What triggered it?',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Likely a crisis',
                          style: AppText.body(19, FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Saving will reset the counter to 0',
                          style: AppText.body(
                            15,
                            FontWeight.w500,
                            AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _crisis,
                    onChanged: (v) => setState(() => _crisis = v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.green,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: AppColors.surfaceAlt,
                    trackOutlineColor: WidgetStateProperty.all(
                      Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
            ErrorText(_err),
            const SizedBox(height: 16),
            PrimaryButton('Save entry', onPressed: _save, busy: _busy),
          ],
        ),
      ),
    );
  }
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

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.gold : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.border,
          width: 1.2,
        ),
      ),
      child: Text(
        label,
        style: AppText.body(
          16,
          FontWeight.w700,
          selected ? AppColors.onGold : AppColors.muted,
        ),
      ),
    ),
  );
}
