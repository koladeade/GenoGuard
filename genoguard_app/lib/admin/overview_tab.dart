import 'package:flutter/material.dart';
import '../community/community_api.dart' show timeAgo;
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/nav_row.dart';
import 'admin_api.dart';
import 'admin_shell.dart' show adminApi;

class OverviewTab extends StatefulWidget {
  const OverviewTab({
    super.key,
    required this.tick,
    required this.onGoToReports,
  });
  final int tick; // changes whenever the tab is opened, so the numbers refresh
  final VoidCallback onGoToReports;

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  Map<String, dynamic>? _d;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OverviewTab old) {
    super.didUpdateWidget(old);
    if (old.tick != widget.tick) _load();
  }

  Future<void> _load() async {
    try {
      final d = await adminApi(context).overview();
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

  int _n(String path) {
    dynamic v = _d;
    for (final k in path.split('.')) {
      v = v is Map ? v[k] : null;
    }
    return (v as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final open = _n('open_post_reports') + _n('open_comment_reports');
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
            // What needs attention first
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onGoToReports,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: open > 0 ? AppColors.redTint : AppColors.greenTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      open > 0
                          ? Icons.flag_outlined
                          : Icons.check_circle_outline,
                      color: open > 0 ? AppColors.error : AppColors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        open > 0
                            ? '$open ${open == 1 ? 'report needs' : 'reports need'} review'
                            : 'No reports waiting',
                        style: AppText.body(
                          18,
                          FontWeight.w700,
                          open > 0 ? AppColors.error : AppColors.green,
                        ),
                      ),
                    ),
                    if (open > 0)
                      const Icon(Icons.chevron_right, color: AppColors.error),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Stat('Patients', _n('users.patient'))),
                const SizedBox(width: 12),
                Expanded(child: _Stat('Explorers', _n('users.explorer'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Stat('New this week', _n('new_users_7d'))),
                const SizedBox(width: 12),
                Expanded(child: _Stat('Disabled', _n('disabled_users'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Stat('Community posts', _n('posts'))),
                const SizedBox(width: 12),
                Expanded(child: _Stat('Quiz answers', _n('quiz_responses'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Stat('Open invitations', _n('open_invitations')),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 20),
            NavRow(
              icon: Icons.history,
              title: 'Activity log',
              subtitle: 'What admins have done',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AuditScreen()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: AppText.heading(32)),
        const SizedBox(height: 2),
        Text(label, style: AppText.body(14, FontWeight.w600, AppColors.muted)),
      ],
    ),
  );
}

String _actionLabel(String a) => switch (a) {
  'post_deleted' => 'Deleted a post',
  'post_kept' => 'Kept a reported post',
  'comment_deleted' => 'Deleted a comment',
  'comment_kept' => 'Kept a reported comment',
  'user_disabled' => 'Disabled an account',
  'user_enabled' => 'Re-enabled an account',
  'user_deleted' => 'Deleted an account',
  'data_exported' => 'Exported research data',
  _ => a,
};

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});
  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<AuditEntry>? _items;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await adminApi(context).audit();
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return AuthScaffold(
      title: 'Activity log',
      subtitle:
          'The latest 100 admin actions. No names or emails are recorded.',
      backTo: '/welcome',
      onBack: () => Navigator.of(context).pop(),
      children: [
        if (_err != null)
          Text(_err!, style: AppText.body(15, FontWeight.w600, AppColors.error))
        else if (items == null)
          const Center(child: CircularProgressIndicator(color: AppColors.gold))
        else if (items.isEmpty)
          Text(
            'Nothing yet.',
            style: AppText.body(16, FontWeight.w500, AppColors.muted),
          )
        else
          for (final e in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _actionLabel(e.action),
                      style: AppText.body(16, FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${e.admin} · ${timeAgo(e.at)}${e.detail == null ? '' : ' · ${e.detail}'}',
                      style: AppText.body(14, FontWeight.w500, AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
