import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'pain_entry_sheet.dart';
import 'pain_state.dart';
import 'reminder_utils.dart';
import 'reminders_state.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onGoTo});
  final void Function(int tab) onGoTo;

  static const _profileTab = 3;
  static const _remindersTab = 2;

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final pain = context.watch<PainState>();
    final user = auth.user ?? const <String, dynamic>{};
    final fullName = ((user['full_name'] as String?) ?? '').trim();
    final firstName = fullName.isEmpty ? '' : fullName.split(' ').first;
    final genotype = user['genotype'] as String?;
    final s = pain.summary;

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => pain.load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          // Greeting + avatar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstName.isEmpty
                          ? _greeting()
                          : '${_greeting()}, $firstName',
                      style: AppText.heading(30),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      genotype == null
                          ? 'Patient'
                          : 'Patient · $genotype genotype',
                      style: AppText.body(16, FontWeight.w500, AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => onGoTo(_profileTab),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.surfaceAlt,
                  child: Text(
                    firstName.isEmpty ? '?' : firstName[0].toUpperCase(),
                    style: AppText.body(22, FontWeight.w600, AppColors.gold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (pain.error != null && pain.entries.isEmpty) ...[
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
            ),
            const SizedBox(height: 16),
          ],

          // Days since last crisis
          _CrisisCard(summary: s),
          const SizedBox(height: 16),

          // Recovery
          _RecoveryCard(pain: pain),
          const SizedBox(height: 16),

          // Next reminders
          _RemindersCard(onSeeAll: () => onGoTo(_remindersTab)),
          const SizedBox(height: 16),

          PrimaryButton(
            'Log pain',
            onPressed: () => showPainEntrySheet(context, pain),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Crisis counter ring

class _CrisisCard extends StatelessWidget {
  const _CrisisCard({required this.summary});
  final PainSummary summary;

  @override
  Widget build(BuildContext context) {
    final days = summary.daysSinceCrisis;
    final best = summary.personalBest;
    final progress = (days == null || best == null || best == 0)
        ? 0.0
        : (days / best).clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(250, 250),
                  painter: _RingPainter(progress),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      days == null ? '–' : '$days',
                      style: AppText.heading(76),
                    ),
                    Text(
                      days == null
                          ? 'no crisis logged yet'
                          : (days == 1
                                ? 'day since last crisis'
                                : 'days since last crisis'),
                      style: AppText.body(17, FontWeight.w500, AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (best != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.amberTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Personal best: $best days',
                style: AppText.body(16, FontWeight.w700, AppColors.gold),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.surfaceAlt,
    );
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = AppColors.gold,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ---------------------------------------------------------------------------
// Recovery chart

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.pain});
  final PainState pain;

  @override
  Widget build(BuildContext context) {
    final s = pain.summary;
    final hasChart = s.points.length >= 2;
    final pct = s.changePct;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recovery since last crisis',
                  style: AppText.body(19, FontWeight.w700),
                ),
              ),
              if (hasChart && pct != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: pct >= 0 ? AppColors.greenTint : AppColors.redTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    pct >= 0 ? '↓ $pct% pain' : '↑ ${-pct}% pain',
                    style: AppText.body(
                      14,
                      FontWeight.w700,
                      pct >= 0 ? AppColors.green : AppColors.red,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _WindowToggle(value: pain.window, onChanged: pain.setWindow),
          const SizedBox(height: 14),
          if (hasChart) ...[
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(painter: _ChartPainter(s.points, s.spanDays)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Crisis',
                  style: AppText.body(15, FontWeight.w500, AppColors.muted),
                ),
                if (s.spanDays >= 2)
                  Text(
                    'Day ${(s.spanDays / 2).round()}',
                    style: AppText.body(15, FontWeight.w500, AppColors.muted),
                  ),
                Text(
                  s.reachesToday ? 'Today' : 'Day ${s.spanDays}',
                  style: AppText.body(15, FontWeight.w500, AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Average daily pain (0 to 10) after your last crisis. Lower is better.',
              style: AppText.body(15, FontWeight.w500, AppColors.muted),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                s.hasCrisis
                    ? 'Log your pain on a few days after a crisis to see your recovery here.'
                    : 'Mark a pain entry as a crisis to start tracking your recovery.',
                style: AppText.body(15, FontWeight.w500, AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _WindowToggle extends StatelessWidget {
  const _WindowToggle({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border, width: 1.2),
    ),
    child: Row(
      children: [
        for (final d in const [7, 14, 30])
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(d),
              child: Container(
                margin: const EdgeInsets.all(4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: d == value ? AppColors.surfaceAlt : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '$d days',
                  style: AppText.body(
                    16,
                    FontWeight.w700,
                    d == value ? AppColors.text : AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points, this.span);
  final List<RecoveryPoint> points;
  final int span;

  @override
  void paint(Canvas canvas, Size size) {
    const padX = 10.0, padY = 12.0;
    final w = size.width - padX * 2;
    final h = size.height - padY * 2;

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = padY + h * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    Offset at(RecoveryPoint p) {
      final x = padX + (span == 0 ? w / 2 : w * p.day / span);
      final y = padY + h * (1 - p.avg / 10);
      return Offset(x, y);
    }

    final pts = points.map(at).toList();
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, padY + h)
      ..lineTo(pts.first.dx, padY + h)
      ..close();

    canvas.drawPath(fill, Paint()..color = const Color(0x2E63A68A));
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = AppColors.green,
    );
    canvas.drawCircle(pts.first, 7, Paint()..color = AppColors.red);
    canvas.drawCircle(pts.last, 7, Paint()..color = AppColors.green);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points || old.span != span;
}

// ---------------------------------------------------------------------------
// Next reminders

class _RemindersCard extends StatelessWidget {
  const _RemindersCard({required this.onSeeAll});
  final VoidCallback onSeeAll;

  String _when(DateTime at) {
    final now = DateTime.now();
    final t = label12(
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
    );
    if (RemindersState.sameDate(at, now)) return t;
    if (RemindersState.sameDate(at, now.add(const Duration(days: 1))))
      return 'Tomorrow $t';
    return '${dayShort(at)} $t';
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<RemindersState>();
    final next = st.nextUp();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Next reminders',
                  style: AppText.body(19, FontWeight.w700),
                ),
              ),
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  'See all',
                  style: AppText.body(16, FontWeight.w700, AppColors.gold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (next.isEmpty)
            Text(
              'No reminders yet.',
              style: AppText.body(16, FontWeight.w500, AppColors.muted),
            )
          else
            for (final n in next)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    // Scheduled medication due today can be ticked off right here.
                    if (n.reminder.isMedication &&
                        RemindersState.sameDate(n.at, DateTime.now()))
                      GestureDetector(
                        onTap: () => st.setTaken(n.reminder.id, true),
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.6,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(left: 9, right: 21),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: n.reminder.isAppointment
                              ? AppColors.green
                              : (n.reminder.type == 'hydration'
                                    ? kBlue
                                    : AppColors.gold),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        n.reminder.displayTitle,
                        style: AppText.body(17, FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _when(n.at),
                      style: AppText.body(15, FontWeight.w500, AppColors.muted),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
