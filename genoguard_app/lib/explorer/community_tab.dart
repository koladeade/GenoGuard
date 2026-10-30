import 'package:flutter/material.dart';
import '../community/community_api.dart';
import '../community/community_screens.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  List<Post> _posts = [];
  bool _loading = true;
  bool _hasMore = false;
  bool _loadingMore = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await communityApi(context).posts();
      if (!mounted) return;
      setState(() {
        _posts = page.posts;
        _hasMore = page.hasMore;
        _err = null;
      });
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _posts.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await communityApi(
        context,
      ).posts(before: _posts.last.createdAt);
      if (!mounted) return;
      final have = _posts.map((p) => p.id).toSet();
      setState(() {
        _posts = [..._posts, ...page.posts.where((p) => !have.contains(p.id))];
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted) snack(context, errMsg(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _share() async {
    final p = await Navigator.of(
      context,
    ).push<Post>(MaterialPageRoute(builder: (_) => const NewPostScreen()));
    if (p != null && mounted) setState(() => _posts = [p, ..._posts]);
  }

  Future<void> _open(Post p) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id)),
    );
    if (mounted)
      _load(); // comment counts, deletions and reports may have changed
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.gold,
    backgroundColor: AppColors.surface,
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text('Community', style: AppText.heading(32))),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _share,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amberTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+ Share',
                  style: AppText.body(17, FontWeight.w700, AppColors.gold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const GuidelinesNotice(),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
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
        else if (_posts.isEmpty)
          AppCard(
            child: Text(
              'No posts yet. Stories shared by the community will appear here.',
              style: AppText.body(17, FontWeight.w500, AppColors.muted),
            ),
          )
        else
          for (final p in _posts) ...[
            _PostCard(post: p, onTap: () => _open(p)),
            const SizedBox(height: 12),
          ],
        if (!_loading && _err == null && _hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SecondaryButton(
              _loadingMore ? 'Loading...' : 'Load more',
              onPressed: _loadingMore ? null : _loadMore,
            ),
          ),
      ],
    ),
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});
  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.author,
                  style: AppText.body(17, FontWeight.w700),
                ),
              ),
              Text(
                timeAgo(post.createdAt),
                style: AppText.body(14, FontWeight.w500, AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.body,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(17, FontWeight.w500).copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                post.commentCount == 1
                    ? '1 comment'
                    : '${post.commentCount} comments',
                style: AppText.body(14, FontWeight.w600, AppColors.muted),
              ),
              const Spacer(),
              if (post.hidden)
                Text(
                  'Under review',
                  style: AppText.body(13, FontWeight.w600, AppColors.hint),
                )
              else if (post.reported)
                Text(
                  'Reported',
                  style: AppText.body(13, FontWeight.w600, AppColors.hint),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
