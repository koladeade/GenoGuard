import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'pain_state.dart';

// ---------------------------------------------------------------------------
// Rules. Recovery uses only pain the person actually logged. A day with no log is
// never read as "no pain" and never counted as a number.

/// Recovered = a log at or below this share of the first crisis log of the episode.
const int kRecoveryPercent = 30;

/// Crisis-flagged logs within this many days of the previous one belong to the same episode.
const int kEpisodeGapDays = 3;

/// With no log for this many days the card stops showing an old status.
const int kStaleDays = 7;

enum RecoveryStatus { none, stale, noLogsSince, inCrisis, improving, recovered }

class Recovery {
  const Recovery(
    this.status, {
    this.crisis,
    this.threshold = 0,
    this.latest,
    this.points = const [],
  });

  final RecoveryStatus status;
  final PainEntry? crisis; // first crisis log of the current episode
  final int threshold; // recovered at or below this pain level
  final PainEntry? latest; // latest log after the crisis log, if any
  final List<PainEntry>
  points; // crisis log and the logs after it, oldest first
}

int calendarDaysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

Recovery computeRecovery(List<PainEntry> entries, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final all = [...entries]..sort((a, b) => a.at.compareTo(b.at));

  PainEntry? start;
  DateTime? lastCrisisAt;
  var recovered = false;
  var threshold = 0;
  var episode = <PainEntry>[];

  for (final e in all) {
    if (e.isCrisis) {
      // A crisis log starts a new episode when there is none yet, when the last one already
      // recovered, or when it comes more than kEpisodeGapDays after the previous crisis log.
      final isNew =
          start == null ||
          recovered ||
          e.at.difference(lastCrisisAt!) >
              const Duration(days: kEpisodeGapDays);
      if (isNew) {
        start = e;
        threshold = (e.intensity * kRecoveryPercent) ~/ 100;
        episode = [e];
        recovered = false;
      } else {
        episode.add(e);
        if (e.intensity <= threshold) recovered = true;
      }
      lastCrisisAt = e.at;
    } else if (start != null) {
      episode.add(e);
      if (e.intensity <= threshold) recovered = true;
    }
  }

  final crisis = start;
  if (crisis == null) return const Recovery(RecoveryStatus.none);

  final latest = episode.length > 1 ? episode.last : null;
  final lastAt = (latest ?? crisis).at;
  final stale = t.difference(lastAt) > const Duration(days: kStaleDays);

  RecoveryStatus status;
  if (latest == null) {
    status = stale ? RecoveryStatus.stale : RecoveryStatus.noLogsSince;
  } else if (latest.intensity <= threshold) {
    status = stale ? RecoveryStatus.none : RecoveryStatus.recovered;
  } else if (latest.intensity >= crisis.intensity) {
    status = stale ? RecoveryStatus.stale : RecoveryStatus.inCrisis;
  } else {
    status = stale ? RecoveryStatus.stale : RecoveryStatus.improving;
  }

  if (status == RecoveryStatus.none) return const Recovery(RecoveryStatus.none);
  return Recovery(
    status,
    crisis: crisis,
    threshold: threshold,
    latest: latest,
    points: episode,
  );
}

// ---------------------------------------------------------------------------
// Card

const _months = [
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

String _ago(DateTime at, DateTime now) {
  final d = calendarDaysBetween(at, now);
  if (d <= 0) return 'today';
  if (d == 1) return 'yesterday';
  return '$d days ago';
}

String _dayLabel(DateTime at, DateTime now) => calendarDaysBetween(at, now) <= 0
    ? 'Today'
    : '${at.day} ${_months[at.month - 1]}';

class RecoveryCard extends StatelessWidget {
  const RecoveryCard({super.key, required this.pain});
  final PainState pain;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final r = computeRecovery(pain.entries, now: now);
    final crisis = r.crisis;
    final latest = r.latest;

    String? badge;
    Color badgeColor = AppColors.muted;
    Color badgeTint = AppColors.surfaceAlt;
    switch (r.status) {
      case RecoveryStatus.inCrisis:
        badge = 'Still in crisis';
        badgeColor = AppColors.red;
        badgeTint = AppColors.redTint;
      case RecoveryStatus.improving:
        badge = 'Improving';
        badgeColor = AppColors.gold;
        badgeTint = AppColors.amberTint;
      case RecoveryStatus.recovered:
        badge = 'Recovered';
        badgeColor = AppColors.green;
        badgeTint = AppColors.greenTint;
      default:
        break;
    }

    String message;
    switch (r.status) {
      case RecoveryStatus.none:
        message =
            'Mark a pain entry as a crisis to start tracking your recovery.';
      case RecoveryStatus.stale:
        message =
            'Log how you\'re feeling. Your last log was ${_ago((latest ?? crisis!).at, now)}.';
      case RecoveryStatus.noLogsSince:
        message =
            'Crisis logged at ${crisis!.intensity}/10 ${_ago(crisis.at, now)}. '
            'No logs since, so we can\'t tell how you\'re doing.';
      case RecoveryStatus.inCrisis:
        message =
            'Last log: ${latest!.intensity}/10 ${_ago(latest.at, now)}. '
            'Still at or above your crisis level (${crisis!.intensity}/10).';
      case RecoveryStatus.improving:
        message =
            'Last log: ${latest!.intensity}/10 ${_ago(latest.at, now)}. '
            'Down from ${crisis!.intensity}/10 at your crisis.';
      case RecoveryStatus.recovered:
        message =
            'Your pain was logged at ${latest!.intensity}/10 ${_ago(latest.at, now)}, '
            'within your recovery level (${r.threshold}/10 or lower).';
    }

    final showChart =
        r.points.length >= 2 &&
        (r.status == RecoveryStatus.inCrisis ||
            r.status == RecoveryStatus.improving ||
            r.status == RecoveryStatus.recovered);

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
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    badge,
                    style: AppText.body(14, FontWeight.w700, badgeColor),
                  ),
                ),
            ],
          ),
          if (showChart) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(painter: _LogsPainter(r.points, r.threshold)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Crisis · ${_dayLabel(crisis!.at, now)}',
                  style: AppText.body(15, FontWeight.w500, AppColors.muted),
                ),
                Text(
                  _dayLabel(latest!.at, now),
                  style: AppText.body(15, FontWeight.w500, AppColors.muted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            message,
            style: AppText.body(
              16,
              FontWeight.w500,
              r.status == RecoveryStatus.none
                  ? AppColors.muted
                  : AppColors.text,
            ),
          ),
          if (r.status != RecoveryStatus.none) ...[
            const SizedBox(height: 10),
            Text(
              'Based only on the pain you log. Recovered means a log at or below ${r.threshold}/10 '
              '($kRecoveryPercent% of your crisis pain)${showChart ? ', shown as the dotted line' : ''}.',
              style: AppText.body(13, FontWeight.w500, AppColors.hint),
            ),
          ],
        ],
      ),
    );
  }
}

/// One dot per log, joined in time order.
class _LogsPainter extends CustomPainter {
  _LogsPainter(this.points, this.threshold);
  final List<PainEntry> points;
  final int threshold;

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

    double yFor(num pain) => padY + h * (1 - pain / 10);

    // Recovery level
    final ty = yFor(threshold);
    final dash = Paint()
      ..color = AppColors.green
      ..strokeWidth = 1.6;
    for (var x = padX; x < size.width - padX; x += 10) {
      canvas.drawLine(
        Offset(x, ty),
        Offset(math.min(x + 5, size.width - padX), ty),
        dash,
      );
    }

    final t0 = points.first.at.millisecondsSinceEpoch.toDouble();
    final span = points.last.at.millisecondsSinceEpoch - t0;
    Offset at(PainEntry e) {
      final x = span <= 0
          ? padX + w / 2
          : padX + w * (e.at.millisecondsSinceEpoch - t0) / span;
      return Offset(x, yFor(e.intensity));
    }

    final pts = points.map(at).toList();
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.gold,
    );

    for (var i = 0; i < pts.length; i++) {
      final isCrisis = i == 0;
      canvas.drawCircle(
        pts[i],
        isCrisis ? 6.5 : 4.5,
        Paint()..color = isCrisis ? AppColors.red : AppColors.gold,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogsPainter old) => true;
}
