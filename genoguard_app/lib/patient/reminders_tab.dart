import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'pill_tabs.dart';
import 'reminder_sheet.dart';
import 'reminder_utils.dart';
import 'reminders_state.dart';

class RemindersTab extends StatefulWidget {
  const RemindersTab({super.key});
  @override
  State<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<RemindersTab> {
  static const _filters = ['All', 'Meds', 'Hydration', 'Appts'];
  static const _filterTypes = [null, 'medication', 'hydration', 'appointment'];
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<RemindersState>();
    final type = _filterTypes[_filter];
    final today = dateOnly(DateTime.now());

    final shown = st.reminders
        .where((r) => type == null || r.type == type)
        .toList();
    bool isOnce(Reminder r) => r.recurrence == 'once';
    int byTime(Reminder a, Reminder b) =>
        (a.timeOfDay ?? '').compareTo(b.timeOfDay ?? '');
    int byDateTime(Reminder a, Reminder b) {
      final c = a.onDate!.compareTo(b.onDate!);
      return c != 0 ? c : byTime(a, b);
    }

    final todayList =
        shown
            .where(
              (r) => (!isOnce(r) || (r.onDate != null && r.onDate == today)),
            )
            .toList()
          ..sort(byTime);
    final upcoming =
        shown
            .where(
              (r) => isOnce(r) && r.onDate != null && r.onDate!.isAfter(today),
            )
            .toList()
          ..sort(byDateTime);

    final showWater = type == null || type == 'hydration';
    final empty = todayList.isEmpty && upcoming.isEmpty;

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => st.load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Row(
            children: [
              Expanded(child: Text('Reminders', style: AppText.heading(32))),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => showReminderSheet(context, st, type: type),
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
          PillTabs(
            labels: _filters,
            selected: _filter,
            onChanged: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 16),
          if (st.error != null && st.reminders.isEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    st.error!,
                    style: AppText.body(15, FontWeight.w600, AppColors.error),
                  ),
                  TextButton(
                    onPressed: () => st.load(),
                    child: Text(
                      'Try again',
                      style: AppText.body(16, FontWeight.w700, AppColors.gold),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (showWater) ...[_WaterCard(st: st), const SizedBox(height: 20)],
            if (st.loading && st.reminders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (empty)
              AppCard(
                child: Text(
                  'Nothing here yet. Tap + New to add a reminder.',
                  style: AppText.body(17, FontWeight.w500, AppColors.muted),
                ),
              )
            else ...[
              _Section('TODAY', todayList, st),
              _Section('UPCOMING', upcoming, st),
            ],
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.items, this.st, {this.dim = false});
  final String title;
  final List<Reminder> items;
  final RemindersState st;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
          child: Text(
            title,
            style: AppText.body(
              15,
              FontWeight.w700,
              AppColors.muted,
            ).copyWith(letterSpacing: 1.3),
          ),
        ),
        for (final r in items) ...[
          Opacity(
            opacity: dim ? 0.55 : 1,
            child: _ReminderRow(r: r, st: st, past: dim),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 6),
      ],
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.st});
  final RemindersState st;

  @override
  Widget build(BuildContext context) {
    final n = st.glasses;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Water today',
                  style: AppText.body(19, FontWeight.w700),
                ),
              ),
              _RoundBtn(
                icon: Icons.remove,
                onTap: n > 0 ? () => st.setGlasses(n - 1) : null,
              ),
              const SizedBox(width: 10),
              _RoundBtn(
                icon: Icons.add,
                onTap: n < kWaterMax ? () => st.setGlasses(n + 1) : null,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$n', style: AppText.heading(40)),
                TextSpan(
                  text: n >= kWaterGoal
                      ? (n == 1 ? ' glass' : ' glasses')
                      : ' / $kWaterGoal glasses',
                  style: AppText.body(17, FontWeight.w500, AppColors.muted),
                ),
              ],
            ),
          ),
          if (n >= kWaterGoal) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.greenTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Daily goal reached',
                style: AppText.body(14, FontWeight.w700, AppColors.green),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < kWaterGoal; i++) ...[
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: i < n
                          ? (n >= kWaterGoal ? AppColors.green : kBlue)
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                if (i < kWaterGoal - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? kBlueTint : Colors.transparent,
        border: filled ? null : Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Icon(
        icon,
        size: 22,
        color: onTap == null
            ? AppColors.border
            : (filled ? kBlue : AppColors.muted),
      ),
    ),
  );
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.r, required this.st, required this.past});
  final Reminder r;
  final RemindersState st;
  final bool past;

  (Color bg, Color dot) get _colors => switch (r.type) {
    'medication' => (AppColors.amberTint, AppColors.gold),
    'hydration' => (kBlueTint, kBlue),
    _ => (AppColors.greenTint, AppColors.green),
  };

  /// Only scheduled medication due today can be ticked off.
  bool get _tickable => r.isMedication && !past;

  String get _subtitle {
    if (r.isAppointment) {
      final parts = <String>[
        if (r.doctor != null) r.doctor!,
        if (r.location != null) r.location!,
        if (r.onDate != null) dayShort(r.onDate!),
      ];
      return parts.join(' · ');
    }
    if (r.recurrence == 'once' && r.onDate != null)
      return 'Once · ${dayShort(r.onDate!)}';
    return r.repeatLabel;
  }

  @override
  Widget build(BuildContext context) {
    final (bg, dot) = _colors;
    final taken = r.isMedication && r.takenCount > 0;

    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showReminderSheet(context, st, edit: r),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tickable ? () => st.setTaken(r.id, !taken) : null,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: taken ? AppColors.greenTint : bg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: taken
                      ? const Icon(
                          Icons.check,
                          color: AppColors.green,
                          size: 28,
                        )
                      : Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.displayTitle,
                    style: AppText.body(19, FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    taken ? 'Taken · $_subtitle' : _subtitle,
                    style: AppText.body(
                      15,
                      FontWeight.w500,
                      taken ? AppColors.green : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label12(r.timeOfDay ?? '00:00'),
                  style: AppText.body(18, FontWeight.w700),
                ),
                if (!past) ...[
                  const SizedBox(height: 6),
                  Switch(
                    value: r.enabled,
                    onChanged: (v) => st.setEnabled(r.id, v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.green,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: AppColors.surfaceAlt,
                    trackOutlineColor: WidgetStateProperty.all(
                      Colors.transparent,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
