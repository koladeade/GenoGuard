import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../community/community_api.dart';
import '../community/community_screens.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Admin home: the queues of reported posts and reported comments.
/// "Keep" closes the reports, "Delete" removes the post or comment.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  List<ReportedPost> _items = [];
  List<ReportedComment> _comments = [];
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
      final api = communityApi(context);
      final r = await api.reportedPosts();
      final c = await api.reportedComments();
      if (!mounted) return;
      setState(() {
        _items = r;
        _comments = c;
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

  Future<void> _actComment(ReportedComment item, {required bool delete}) async {
    if (delete) {
      final ok = await confirmDialog(
        context,
        title: 'Delete this comment?',
        message:
            'The comment and its reports will be removed. This cannot be undone.',
        action: 'Delete',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy.add(item.commentId));
    try {
      final api = communityApi(context);
      if (delete) {
        await api.deleteComment(item.commentId);
      } else {
        await api.keepComment(item.commentId);
      }
      if (!mounted) return;
      setState(
        () => _comments = _comments
            .where((x) => x.commentId != item.commentId)
            .toList(),
      );
      snack(context, delete ? 'Comment deleted' : 'Comment kept');
    } catch (e) {
      if (mounted) snack(context, errMsg(e));
    } finally {
      if (mounted) setState(() => _busy.remove(item.commentId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Reported content'),
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
                  else if (_items.isEmpty && _comments.isEmpty)
                    AppCard(
                      child: Text(
                        'Nothing to review. Reported posts and comments will appear here.',
                        style: AppText.body(
                          17,
                          FontWeight.w500,
                          AppColors.muted,
                        ),
                      ),
                    )
                  else ...[
                    if (_items.isNotEmpty) _heading('Posts (${_items.length})'),
                    for (final item in _items) ...[
                      _ReportCard(
                        count: item.reportCount,
                        meta: '${item.author} · ${timeAgo(item.postedAt)}',
                        body: item.body,
                        reasons: item.reasons,
                        busy: _busy.contains(item.postId),
                        onKeep: () => _act(item, delete: false),
                        onDelete: () => _act(item, delete: true),
                        keepLabel: 'Keep post',
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_comments.isNotEmpty)
                      _heading('Comments (${_comments.length})'),
                    for (final item in _comments) ...[
                      _ReportCard(
                        count: item.reportCount,
                        meta: '${item.author} · ${timeAgo(item.postedAt)}',
                        body: item.body,
                        reasons: item.reasons,
                        busy: _busy.contains(item.commentId),
                        onKeep: () => _actComment(item, delete: false),
                        onDelete: () => _actComment(item, delete: true),
                        keepLabel: 'Keep comment',
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ],
              ),
            ),
    ),
  );
}

Widget _heading(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(2, 6, 0, 10),
  child: Text(text, style: AppText.body(15, FontWeight.w700, AppColors.muted)),
);

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.count,
    required this.meta,
    required this.body,
    required this.reasons,
    required this.busy,
    required this.onKeep,
    required this.onDelete,
    required this.keepLabel,
  });
  final int count;
  final String meta;
  final String body;
  final List<String> reasons;
  final bool busy;
  final VoidCallback onKeep;
  final VoidCallback onDelete;
  final String keepLabel;

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
                count == 1 ? '1 report' : '$count reports',
                style: AppText.body(14, FontWeight.w700, AppColors.error),
              ),
            ),
            const Spacer(),
            Text(
              meta,
              style: AppText.body(14, FontWeight.w500, AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: AppText.body(17, FontWeight.w500).copyWith(height: 1.45),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in reasons)
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
                keepLabel,
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
