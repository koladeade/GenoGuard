import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

void openPrivacy(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()));
}

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

String _date(dynamic iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return 'Not available';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  int? _count;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final r = await context.read<AuthState>().api.dio.get('/usage');
      if (mounted)
        setState(() => _count = (r.data['count'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  Future<void> _toggle(bool on) async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<AuthState>().setUsageLogs(on);
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete usage data?', style: AppText.heading(22)),
        content: Text(
          'All usage events stored for your account will be removed. This cannot be undone.',
          style: AppText.body(16, FontWeight.w500, AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppText.body(16, FontWeight.w700, AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: AppText.body(16, FontWeight.w700, AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<AuthState>().api.dio.delete('/usage');
      if (!mounted) return;
      setState(() => _count = 0);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Usage data deleted')));
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppText.body(16, FontWeight.w500, AppColors.muted),
          ),
        ),
        Text(value, style: AppText.body(16, FontWeight.w700)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user ?? const <String, dynamic>{};
    final on = user['usage_logs_consent'] == true;
    final version = (user['consent_version'] as String?) ?? kConsentVersion;

    return AuthScaffold(
      title: 'Privacy and data',
      subtitle: 'Your consent and what the app records',
      backTo: '/welcome',
      onBack: () => Navigator.of(context).pop(),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your consent', style: AppText.body(19, FontWeight.w700)),
              const SizedBox(height: 8),
              _row('Consent version', version),
              _row('Given on', _date(user['consented_at'])),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Usage logs',
                      style: AppText.body(19, FontWeight.w700),
                    ),
                  ),
                  Switch(
                    value: on,
                    onChanged: _busy ? null : _toggle,
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
              const SizedBox(height: 6),
              Text(
                on
                    ? 'On. The app records the checks you complete and the learning items you open, with the time.'
                    : 'Off. Nothing about how you use the app is recorded.',
                style: AppText.body(15, FontWeight.w500, AppColors.muted),
              ),
              const SizedBox(height: 10),
              Text(
                'Never recorded in usage logs: what you type, your pain entries, your genotype or your posts. '
                'You can switch this off at any time.',
                style: AppText.body(14, FontWeight.w500, AppColors.hint),
              ),
              if (_err != null) ...[
                const SizedBox(height: 10),
                Text(
                  _err!,
                  style: AppText.body(15, FontWeight.w600, AppColors.error),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stored usage data',
                style: AppText.body(19, FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _count == null
                    ? 'Loading...'
                    : (_count == 1
                          ? '1 event recorded'
                          : '$_count events recorded'),
                style: AppText.body(16, FontWeight.w500, AppColors.muted),
              ),
              const SizedBox(height: 14),
              SecondaryButton(
                'Delete my usage data',
                color: AppColors.error,
                onPressed: (_busy || (_count ?? 0) == 0) ? null : _deleteData,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Deleting your account in Profile removes all of your data, including usage logs.',
          style: AppText.body(14, FontWeight.w500, AppColors.muted),
        ),
      ],
    );
  }
}
