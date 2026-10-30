import 'dart:async';
import 'package:flutter/material.dart';
import '../community/community_api.dart' show timeAgo;
import '../community/community_screens.dart' show confirmDialog, snack;
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'admin_api.dart';
import 'admin_shell.dart' show adminApi;

/// Account basics only: name, email, role, joined, status. Never genotype, pain logs or reminders.
class UsersTab extends StatefulWidget {
  const UsersTab({super.key});
  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final _search = TextEditingController();
  List<AdminUser> _users = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _err;
  final Set<String> _busy = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await adminApi(context).users(q: _search.text);
      if (!mounted) return;
      setState(() {
        _users = r.users;
        _hasMore = r.hasMore;
        _err = null;
      });
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _more() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final r = await adminApi(
        context,
      ).users(q: _search.text, offset: _users.length);
      if (!mounted) return;
      final have = _users.map((u) => u.id).toSet();
      setState(() {
        _users = [..._users, ...r.users.where((u) => !have.contains(u.id))];
        _hasMore = r.hasMore;
      });
    } catch (e) {
      if (mounted) snack(context, errMsg(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _toggle(AdminUser u) async {
    final disabling = !u.disabled;
    if (disabling) {
      final ok = await confirmDialog(
        context,
        title: 'Disable this account?',
        message:
            'They will be signed out and cannot sign in until you re-enable it. Their data is kept.',
        action: 'Disable',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy.add(u.id));
    try {
      final api = adminApi(context);
      if (disabling) {
        await api.disable(u.id);
      } else {
        await api.enable(u.id);
      }
      if (mounted) setState(() => u.disabled = disabling);
    } catch (e) {
      if (mounted) snack(context, errMsg(e));
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  Future<void> _delete(AdminUser u) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this account?',
      message:
          'The account and everything its owner created will be removed for good. This cannot be undone.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(u.id));
    try {
      await adminApi(context).deleteUser(u.id);
      if (!mounted) return;
      setState(() => _users = _users.where((x) => x.id != u.id).toList());
      snack(context, 'Account deleted');
    } catch (e) {
      if (mounted) snack(context, errMsg(e));
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  Widget _chip(String text, Color color, Color tint) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: AppText.body(12, FontWeight.w700, color)),
  );

  Widget _card(AdminUser u) {
    final busy = _busy.contains(u.id);
    final isAdmin = u.role == 'admin';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    u.name.isEmpty ? u.email : u.name,
                    style: AppText.body(17, FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _chip(u.role, AppColors.gold, AppColors.amberTint),
                if (u.disabled) ...[
                  const SizedBox(width: 6),
                  _chip('disabled', AppColors.error, AppColors.redTint),
                ],
              ],
            ),
            if (u.name.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                u.email,
                style: AppText.body(14, FontWeight.w500, AppColors.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Joined ${timeAgo(u.createdAt)}',
              style: AppText.body(13, FontWeight.w500, AppColors.hint),
            ),
            if (!isAdmin) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      u.disabled ? 'Re-enable' : 'Disable',
                      onPressed: busy ? null : () => _toggle(u),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SecondaryButton(
                      'Delete',
                      color: AppColors.error,
                      onPressed: busy ? null : () => _delete(u),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.gold,
    backgroundColor: AppColors.surface,
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        TextField(
          controller: _search,
          onChanged: _onSearch,
          style: AppText.body(16),
          decoration: const InputDecoration(
            hintText: 'Search name or email',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          )
        else if (_err != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _err!,
                  style: AppText.body(15, FontWeight.w600, AppColors.error),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _loading = true);
                    _load();
                  },
                  child: Text(
                    'Try again',
                    style: AppText.body(16, FontWeight.w700, AppColors.gold),
                  ),
                ),
              ],
            ),
          )
        else if (_users.isEmpty)
          Text(
            'No accounts found.',
            style: AppText.body(16, FontWeight.w500, AppColors.muted),
          )
        else ...[
          for (final u in _users) _card(u),
          if (_hasMore)
            SecondaryButton(
              _loadingMore ? 'Loading...' : 'Load more',
              onPressed: _loadingMore ? null : _more,
            ),
        ],
      ],
    ),
  );
}
