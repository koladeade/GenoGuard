import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../community/community_api.dart';
import '../community/community_screens.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Admin home: the queue of reported posts. "Keep" closes the reports, "Delete" removes the post.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  List<ReportedPost> _items = [];
  bool _loading = true;
  String? _err;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await communityApi(context).reportedPosts();
      if (!mounted) return;
      setState(() {
        _items = r;
        _err = null;
      });
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(ReportedPost item, {required bool delete}) async {
    if (delete) {
      final ok = await confirmDialog(
        context,
        title: 'Delete this post?',
        message:
            'The post, its comments and its reports will be removed. This cannot be undone.',
        action: 'Delete',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy.add(item.postId));
    try {
      final api = communityApi(context);
      if (delete) {
        await api.deletePost(item.postId);
      } else {
        await api.keepPost(item.postId);
      }
      if (!mounted) return;
      setState(
        () => _items = _items.where((x) => x.postId != item.postId).toList(),
      );
      snack(context, delete ? 'Post deleted' : 'Post kept');
    } catch (e) {
      if (mounted) snack(context, errMsg(e));
    } finally {
      if (mounted) setState(() => _busy.remove(item.postId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Reported posts'),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline, color: AppColors.gold),
          onPressed: () => context.go('/profile'),
        ),
      ],
    ),
    body: SafeArea(
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.surface,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  if (_err != null)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _err!,
                            style: AppText.body(
                              15,
                              FontWeight.w600,
                              AppColors.error,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _loading = true);
                              _load();
                            },
                            child: Text(
                              'Try again',
                              style: AppText.body(
                                16,
                                FontWeight.w700,
                                AppColors.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_items.isEmpty)
                    AppCard(
                      child: Text(
                        'Nothing to review. Reported posts will appear here.',
                        style: AppText.body(
                          17,
                          FontWeight.w500,
                          AppColors.muted,
                        ),
                      ),
                    )
                  else
                    for (final item in _items) ...[
                      _ReportCard(
                        item: item,
                        busy: _busy.contains(item.postId),
                        onKeep: () => _act(item, delete: false),
                        onDelete: () => _act(item, delete: true),
                      ),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
            ),
    ),
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.item,
    required this.busy,
    required this.onKeep,
    required this.onDelete,
  });
  final ReportedPost item;
  final bool busy;
  final VoidCallback onKeep;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                item.reportCount == 1
                    ? '1 report'
                    : '${item.reportCount} reports',
                style: AppText.body(14, FontWeight.w700, AppColors.error),
              ),
            ),
            const Spacer(),
            Text(
              '${item.author} · ${timeAgo(item.postedAt)}',
              style: AppText.body(14, FontWeight.w500, AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          item.body,
          style: AppText.body(17, FontWeight.w500).copyWith(height: 1.45),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in item.reasons)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  kReportReasons[r] ?? r,
                  style: AppText.body(13, FontWeight.w600, AppColors.muted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                'Keep post',
                onPressed: busy ? null : onKeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                'Delete',
                color: AppColors.error,
                onPressed: busy ? null : onDelete,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
