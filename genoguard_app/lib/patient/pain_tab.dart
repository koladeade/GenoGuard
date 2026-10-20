import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart' show errMsg;
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'format.dart';
import 'pain_entry_sheet.dart';
import 'pain_state.dart';

class PainTab extends StatefulWidget {
  const PainTab({super.key});
  @override
  State<PainTab> createState() => _PainTabState();
}

class _PainTabState extends State<PainTab> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();

  bool get _isCurrentMonth =>
      _month.year == DateTime.now().year &&
      _month.month == DateTime.now().month;

  void _shiftMonth(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final pain = context.watch<PainState>();
    final dayEntries = pain.forDay(_selected);
    final history = pain.entries.take(50).toList();

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => pain.load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Row(
            children: [
              Expanded(child: Text('Pain log', style: AppText.heading(32))),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => showPainEntrySheet(context, pain, day: _selected),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amberTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+ New',
                    style: AppText.body(17, FontWeight.w700, AppColors.gold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (pain.error != null && pain.entries.isEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pain.error!,
                    style: AppText.body(15, FontWeight.w600, AppColors.error),
                  ),
                  TextButton(
                    onPressed: () => pain.load(),
                    child: Text(
                      'Try again',
                      style: AppText.body(16, FontWeight.w700, AppColors.gold),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _CalendarCard(
              month: _month,
              selected: _selected,
              entries: pain.entries,
              onSelect: (d) => setState(() => _selected = d),
              onPrev: () => _shiftMonth(-1),
              onNext: _isCurrentMonth ? null : () => _shiftMonth(1),
            ),
            const SizedBox(height: 22),
            _SectionLabel(dayLabel(_selected)),
            const SizedBox(height: 10),
            if (dayEntries.isEmpty)
              AppCard(
                child: Text(
                  'No entry for this day.',
                  style: AppText.body(17, FontWeight.w500, AppColors.muted),
                ),
              )
            else
              for (final e in dayEntries) ...[
                _EntryCard(e, pain),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 10),
            _SectionLabel('HISTORY'),
            const SizedBox(height: 10),
            if (pain.loading && pain.entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (history.isEmpty)
              AppCard(
                child: Text(
                  'Nothing logged yet. Tap + New to add your first entry.',
                  style: AppText.body(17, FontWeight.w500, AppColors.muted),
                ),
              )
            else
              for (final e in history) ...[
                _EntryCard(e, pain),
                const SizedBox(height: 12),
              ],
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: AppText.body(
        15,
        FontWeight.w700,
        AppColors.muted,
      ).copyWith(letterSpacing: 1.3),
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard(this.entry, this.pain);
  final PainEntry entry;
  final PainState pain;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete this entry?', style: AppText.heading(22)),
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
    try {
      await pain.remove(entry.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errMsg(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(entry.intensity);
    final hasNotes = entry.notes != null && entry.notes!.trim().isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entryTitle(entry.at),
                  style: AppText.body(19, FontWeight.w700),
                ),
              ),
              if (entry.isCrisis)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: AppColors.red,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tone.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${entry.intensity}/10',
                  style: AppText.body(15, FontWeight.w700, tone.fg),
                ),
              ),
              const SizedBox(width: 4),
              InkResponse(
                onTap: () => _confirmDelete(context),
                radius: 20,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.delete_outline,
                    size: 22,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          if (entry.areas.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.areas.join(', '),
              style: AppText.body(16, FontWeight.w500, AppColors.muted),
            ),
          ],
          if (hasNotes) ...[
            const SizedBox(height: 6),
            Text(entry.notes!.trim(), style: AppText.body(17)),
          ],
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.selected,
    required this.entries,
    required this.onSelect,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final DateTime selected;
  final List<PainEntry> entries;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    // Highest intensity per day of this month decides the dot color.
    final worst = <int, int>{};
    for (final e in entries) {
      if (e.at.year == month.year && e.at.month == month.month) {
        final cur = worst[e.at.day];
        if (cur == null || e.intensity > cur) worst[e.at.day] = e.intensity;
      }
    }

    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday - 1; // Monday first
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <int?>[
      ...List<int?>.filled(lead, null),
      for (var d = 1; d <= daysInMonth; d++) d,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${monthFull(month.month)} ${month.year}',
                style: AppText.body(19, FontWeight.w700),
              ),
              const SizedBox(width: 4),
              _MonthArrow(icon: Icons.chevron_left, onTap: onPrev),
              _MonthArrow(icon: Icons.chevron_right, onTap: onNext),
              const Spacer(),
              Text(
                'Tap a day',
                style: AppText.body(15, FontWeight.w500, AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final l in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: AppText.body(14, FontWeight.w600, AppColors.muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < cells.length ~/ 7; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _DayCell(
                      day: cells[r * 7 + c],
                      month: month,
                      selected: selected,
                      intensity: cells[r * 7 + c] == null
                          ? null
                          : worst[cells[r * 7 + c]!],
                      onSelect: onSelect,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: const [
              _LegendDot(AppColors.green, 'Mild'),
              SizedBox(width: 20),
              _LegendDot(AppColors.gold, 'Moderate'),
              SizedBox(width: 20),
              _LegendDot(AppColors.red, 'Severe'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    radius: 20,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(
        icon,
        size: 22,
        color: onTap == null ? AppColors.border : AppColors.muted,
      ),
    ),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.month,
    required this.selected,
    required this.intensity,
    required this.onSelect,
  });

  final int? day;
  final DateTime month;
  final DateTime selected;
  final int? intensity;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    if (day == null) return const SizedBox(height: 56);
    final date = DateTime(month.year, month.month, day!);
    final isSelected = sameDay(date, selected);
    final isFuture = date.isAfter(DateTime.now());

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(date),
      child: Container(
        height: 56,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceAlt : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: AppColors.gold, width: 1.4)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: AppText.body(
                18,
                FontWeight.w500,
                isFuture ? AppColors.hint : AppColors.text,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 8,
              child: intensity == null
                  ? null
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: toneFor(intensity!).fg,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(label, style: AppText.body(15, FontWeight.w500, AppColors.muted)),
    ],
  );
}
