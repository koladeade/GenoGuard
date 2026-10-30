import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../community/community_screens.dart' show snack;
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'admin_shell.dart' show adminApi;

const _eventLabels = {
  'compat_check': 'Compatibility checks',
  'qr_match': 'QR matches',
  'learning_open': 'Learning items opened',
};

/// Aggregate research data only. Nothing here identifies a person.
class DataTab extends StatefulWidget {
  const DataTab({super.key});
  @override
  State<DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<DataTab> {
  Map<String, dynamic>? _d;
  String? _err;
  String? _copying;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await adminApi(context).researchSummary();
      if (mounted) {
        setState(() {
          _d = d;
          _err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    }
  }

  Future<void> _copy(String kind) async {
    setState(() => _copying = kind);
    try {
      final csv = await adminApi(context).exportCsv(kind);
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted)
        snack(context, 'Copied. Paste it into a spreadsheet or a .csv file.');
    } catch (e) {
      if (mounted) snack(context, errMsg(e));
    } finally {
      if (mounted) setState(() => _copying = null);
    }
  }

  Widget _rating(String title, Map<String, dynamic> m) {
    final counts = ((m['counts'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toList();
    final top = counts.fold<int>(1, (a, b) => b > a ? b : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: AppText.body(16, FontWeight.w700)),
            ),
            Text(
              m['average'] == null ? 'No data' : 'Average ${m['average']}',
              style: AppText.body(15, FontWeight.w700, AppColors.gold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < counts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: Text(
                    '${i + 1}',
                    style: AppText.body(14, FontWeight.w600, AppColors.muted),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: counts[i] / top,
                      minHeight: 10,
                      backgroundColor: AppColors.surfaceAlt,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${counts[i]}',
                    textAlign: TextAlign.right,
                    style: AppText.body(14, FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final quiz = d == null ? null : Map<String, dynamic>.from(d['quiz'] as Map);
    final usage = d == null
        ? null
        : Map<String, dynamic>.from(d['usage'] as Map);
    final events = ((usage?['events'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          if (_err != null && d == null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _err!,
                    style: AppText.body(15, FontWeight.w600, AppColors.error),
                  ),
                  TextButton(
                    onPressed: _load,
                    child: Text(
                      'Try again',
                      style: AppText.body(16, FontWeight.w700, AppColors.gold),
                    ),
                  ),
                ],
              ),
            )
          else if (d == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            )
          else ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Knowledge quiz',
                    style: AppText.body(19, FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${quiz!['responses']} answers from ${quiz['participants']} people',
                    style: AppText.body(15, FontWeight.w500, AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  _rating(
                    'Intention to get tested',
                    Map<String, dynamic>.from(quiz['intention'] as Map),
                  ),
                  const SizedBox(height: 16),
                  _rating(
                    'Confidence to talk about genotype',
                    Map<String, dynamic>.from(quiz['confidence'] as Map),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Usage logs', style: AppText.body(19, FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${usage!['users_with_consent']} people have usage logs switched on',
                    style: AppText.body(15, FontWeight.w500, AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  if (events.isEmpty)
                    Text(
                      'No events yet.',
                      style: AppText.body(15, FontWeight.w500, AppColors.muted),
                    )
                  else
                    for (final e in events)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_eventLabels[e['event']] ?? e['event']}${e['item'] == null ? '' : ' (${e['item']})'}',
                                style: AppText.body(15, FontWeight.w500),
                              ),
                            ),
                            Text(
                              '${e['count']}',
                              style: AppText.body(15, FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export', style: AppText.body(19, FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'One row per answer or event. People appear as a code, never a name or email. Each export is recorded in the activity log.',
                    style: AppText.body(14, FontWeight.w500, AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  SecondaryButton(
                    _copying == 'quiz'
                        ? 'Copying...'
                        : 'Copy quiz answers (CSV)',
                    onPressed: _copying != null ? null : () => _copy('quiz'),
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    _copying == 'usage'
                        ? 'Copying...'
                        : 'Copy usage events (CSV)',
                    onPressed: _copying != null ? null : () => _copy('usage'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
