import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../explorer/community_tab.dart';
import '../patient/reminder_utils.dart' show kBlue, kBlueTint;
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'community_api.dart';

const kGuidelines =
    'Be kind and share from experience. This is not medical advice. Admins may remove posts that break the guidelines.';

CommunityApi communityApi(BuildContext context) =>
    CommunityApi(context.read<AuthState>().api.dio);

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title, style: AppText.heading(22)),
      content: Text(
        message,
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
            action,
            style: AppText.body(16, FontWeight.w700, AppColors.error),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Opens Community as its own page (used by the patient Profile menu).
void openCommunity(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(
              Icons.chevron_left,
              color: AppColors.muted,
              size: 30,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const SafeArea(child: CommunityTab()),
      ),
    ),
  );
}

/// The guidelines notice shown above the feed and on the new-post screen.
class GuidelinesNotice extends StatelessWidget {
  const GuidelinesNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kBlueTint,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: kBlue, width: 1.2),
    ),
    child: Text(kGuidelines, style: AppText.body(17, FontWeight.w500)),
  );
}

/// Bottom sheet to pick a reason. Returns true when the report was sent.
/// Pass [comment] = true when [id] is a comment id.
Future<bool> showReportSheet(
  BuildContext context,
  String id, {
  bool comment = false,
}) async {
  final api = communityApi(context);
  final reason = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              comment ? 'Report this comment' : 'Report this post',
              style: AppText.heading(24),
            ),
            const SizedBox(height: 6),
            Text(
              'Why are you reporting it? An admin will review it.',
              style: AppText.body(15, FontWeight.w500, AppColors.muted),
            ),
            const SizedBox(height: 8),
            for (final e in kReportReasons.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.value, style: AppText.body(17, FontWeight.w600)),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                ),
                onTap: () => Navigator.of(sheetCtx).pop(e.key),
              ),
          ],
        ),
      ),
    ),
  );
  if (reason == null) return false;
  try {
    if (comment) {
      await api.reportComment(id, reason);
    } else {
      await api.report(id, reason);
    }
    if (context.mounted)
      snack(
        context,
        comment
            ? 'Thanks. An admin will review this comment.'
            : 'Thanks. An admin will review this post.',
      );
    return true;
  } catch (e) {
    if (context.mounted) snack(context, errMsg(e));
    return false;
  }
}

// ---------------------------------------------------------------------------
// New post

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _body = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _body.text.trim();
    if (text.isEmpty) {
      setState(() => _err = 'Write something first');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final p = await communityApi(context).createPost(text);
      if (mounted) Navigator.of(context).pop(p);
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Share with the community',
    subtitle: 'Only your first name is shown.',
    backTo: '/welcome',
    onBack: () => Navigator.of(context).pop(),
    children: [
      const GuidelinesNotice(),
      const SizedBox(height: 16),
      TextField(
        controller: _body,
        minLines: 6,
        maxLines: 10,
        maxLength: 1000,
        style: AppText.body(16),
        decoration: const InputDecoration(
          hintText: 'Share your story, a tip, or a question',
        ),
      ),
      if (_err != null) ...[
        const SizedBox(height: 6),
        Text(_err!, style: AppText.body(15, FontWeight.w600, AppColors.error)),
      ],
      const SizedBox(height: 16),
      PrimaryButton('Post', busy: _busy, onPressed: _post),
    ],
  );
}

// ---------------------------------------------------------------------------
// Post detail with comments

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  List<Comment> _comments = [];
  String? _err;
  bool _loading = true;
  bool _sending = false;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await communityApi(context).detail(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = d.post;
        _comments = d.comments;
        _err = null;
      });
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final c = await communityApi(context).addComment(widget.postId, text);
      if (!mounted) return;
      _input.clear();
      setState(() {
        _comments = [..._comments, c];
        _post?.commentCount = _comments.length;
      });
    } catch (e) {
      if (mounted) snack(context, errMsg(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deletePost() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this post?',
      message: 'It and its comments will be removed.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await communityApi(context).deletePost(widget.postId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) snack(context, errMsg(e));
    }
  }

  Future<void> _deleteComment(Comment c) async {
    try {
      await communityApi(context).deleteComment(c.id);
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((x) => x.id != c.id).toList();
        _post?.commentCount = _comments.length;
      });
    } catch (e) {
      if (mounted) snack(context, errMsg(e));
    }
  }

  Future<void> _report() async {
    final sent = await showReportSheet(context, widget.postId);
    if (sent && mounted) setState(() => _post?.reported = true);
  }

  Future<void> _reportComment(Comment c) async {
    final sent = await showReportSheet(context, c.id, comment: true);
    if (sent && mounted) setState(() => c.reported = true);
  }

  @override
  Widget build(BuildContext context) {
    final p = _post;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            color: AppColors.muted,
            size: 30,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Post'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : (p == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _err ?? 'Post not found',
                              style: AppText.body(
                                16,
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
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                            children: [
                              AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.author,
                                            style: AppText.body(
                                              17,
                                              FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          timeAgo(p.createdAt),
                                          style: AppText.body(
                                            14,
                                            FontWeight.w500,
                                            AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      p.body,
                                      style: AppText.body(
                                        17,
                                        FontWeight.w500,
                                      ).copyWith(height: 1.45),
                                    ),
                                    if (p.hidden) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        'Under review: other people can\'t see this post right now.',
                                        style: AppText.body(
                                          14,
                                          FontWeight.w600,
                                          AppColors.hint,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    if (p.mine)
                                      TextButton.icon(
                                        onPressed: _deletePost,
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.error,
                                          size: 20,
                                        ),
                                        label: Text(
                                          'Delete',
                                          style: AppText.body(
                                            15,
                                            FontWeight.w700,
                                            AppColors.error,
                                          ),
                                        ),
                                      )
                                    else
                                      TextButton.icon(
                                        onPressed: p.reported ? null : _report,
                                        icon: Icon(
                                          Icons.flag_outlined,
                                          color: p.reported
                                              ? AppColors.hint
                                              : AppColors.muted,
                                          size: 20,
                                        ),
                                        label: Text(
                                          p.reported ? 'Reported' : 'Report',
                                          style: AppText.body(
                                            15,
                                            FontWeight.w700,
                                            p.reported
                                                ? AppColors.hint
                                                : AppColors.muted,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                _comments.isEmpty
                                    ? 'No comments yet'
                                    : (_comments.length == 1
                                          ? '1 comment'
                                          : '${_comments.length} comments'),
                                style: AppText.body(
                                  15,
                                  FontWeight.w700,
                                  AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (final c in _comments)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                c.author,
                                                style: AppText.body(
                                                  15,
                                                  FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              timeAgo(c.createdAt),
                                              style: AppText.body(
                                                13,
                                                FontWeight.w500,
                                                AppColors.muted,
                                              ),
                                            ),
                                            if (c.mine)
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                tooltip: 'Delete comment',
                                                icon: const Icon(
                                                  Icons.close,
                                                  size: 18,
                                                  color: AppColors.muted,
                                                ),
                                                onPressed: () =>
                                                    _deleteComment(c),
                                              )
                                            else
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                tooltip: c.reported
                                                    ? 'Reported'
                                                    : 'Report comment',
                                                icon: Icon(
                                                  Icons.flag_outlined,
                                                  size: 18,
                                                  color: c.reported
                                                      ? AppColors.hint
                                                      : AppColors.muted,
                                                ),
                                                onPressed: c.reported
                                                    ? null
                                                    : () => _reportComment(c),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          c.body,
                                          style: AppText.body(
                                            16,
                                            FontWeight.w500,
                                          ).copyWith(height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                          decoration: const BoxDecoration(
                            color: AppColors.bg,
                            border: Border(
                              top: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  minLines: 1,
                                  maxLines: 4,
                                  maxLength: 500,
                                  style: AppText.body(16),
                                  decoration: const InputDecoration(
                                    hintText: 'Write a comment',
                                    counterText: '',
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _sending ? null : _send,
                                icon: _sending
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.gold,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send_rounded,
                                        color: AppColors.gold,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )),
      ),
    );
  }
}
