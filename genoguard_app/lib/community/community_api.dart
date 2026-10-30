import 'package:dio/dio.dart';

/// Why a post is being reported
const kReportReasons = <String, String>{
  'harmful_advice': 'Harmful medical advice',
  'abuse': 'Abusive or hurtful',
  'spam': 'Spam',
  'privacy': 'Shares private information',
  'other': 'Something else',
};

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return '${t.day}/${t.month}/${t.year}';
}

DateTime _time(dynamic v) =>
    DateTime.tryParse('$v')?.toLocal() ?? DateTime.now();

class Post {
  Post({
    required this.id,
    required this.body,
    required this.author,
    required this.createdAt,
    required this.mine,
    required this.commentCount,
    required this.reported,
    this.hidden = false,
  });
  final String id;
  final String body;
  final String author;
  final DateTime createdAt;
  final bool mine;
  int commentCount;
  bool reported;
  final bool
  hidden; // reported by several people; only the author still sees it, until an admin decides

  factory Post.fromJson(Map<String, dynamic> j) => Post(
    id: j['id'] as String,
    body: j['body'] as String,
    author: (j['author'] as String?) ?? 'Member',
    createdAt: _time(j['created_at']),
    mine: j['mine'] == true,
    commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
    reported: j['reported'] == true,
    hidden: j['hidden'] == true,
  );
}

class Comment {
  Comment({
    required this.id,
    required this.body,
    required this.author,
    required this.createdAt,
    required this.mine,
    this.reported = false,
  });
  final String id;
  final String body;
  final String author;
  final DateTime createdAt;
  final bool mine;
  bool reported;

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    id: j['id'] as String,
    body: j['body'] as String,
    author: (j['author'] as String?) ?? 'Member',
    createdAt: _time(j['created_at']),
    mine: j['mine'] == true,
    reported: j['reported'] == true,
  );
}

/// comments waiting in the admin queue.
class ReportedComment {
  ReportedComment({
    required this.commentId,
    required this.body,
    required this.author,
    required this.postedAt,
    required this.reportCount,
    required this.reasons,
  });
  final String commentId;
  final String body;
  final String author;
  final DateTime postedAt;
  final int reportCount;
  final List<String> reasons;

  factory ReportedComment.fromJson(Map<String, dynamic> j) => ReportedComment(
    commentId: j['comment_id'] as String,
    body: j['body'] as String,
    author: (j['author'] as String?) ?? 'Member',
    postedAt: _time(j['posted_at']),
    reportCount: (j['report_count'] as num?)?.toInt() ?? 1,
    reasons: ((j['reasons'] as List?) ?? const []).map((e) => '$e').toList(),
  );
}

/// posts waiting in the admin queue.
class ReportedPost {
  ReportedPost({
    required this.postId,
    required this.body,
    required this.author,
    required this.postedAt,
    required this.reportCount,
    required this.reasons,
  });
  final String postId;
  final String body;
  final String author;
  final DateTime postedAt;
  final int reportCount;
  final List<String> reasons;

  factory ReportedPost.fromJson(Map<String, dynamic> j) => ReportedPost(
    postId: j['post_id'] as String,
    body: j['body'] as String,
    author: (j['author'] as String?) ?? 'Member',
    postedAt: _time(j['posted_at']),
    reportCount: (j['report_count'] as num?)?.toInt() ?? 1,
    reasons: ((j['reasons'] as List?) ?? const []).map((e) => '$e').toList(),
  );
}

class CommunityApi {
  CommunityApi(this.dio);
  final Dio dio;

  static const pageSize = 20;

  Future<({List<Post> posts, bool hasMore})> posts({DateTime? before}) async {
    final r = await dio.get(
      '/community/posts',
      queryParameters: {
        'limit': pageSize,
        if (before != null) 'before': before.toUtc().toIso8601String(),
      },
    );
    final list = ((r.data['posts'] as List?) ?? const [])
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (posts: list, hasMore: r.data['has_more'] == true);
  }

  Future<Post> createPost(String body) async {
    final r = await dio.post('/community/posts', data: {'body': body});
    return Post.fromJson(Map<String, dynamic>.from(r.data['post'] as Map));
  }

  Future<({Post post, List<Comment> comments})> detail(String id) async {
    final r = await dio.get('/community/posts/$id');
    return (
      post: Post.fromJson(Map<String, dynamic>.from(r.data['post'] as Map)),
      comments: ((r.data['comments'] as List?) ?? const [])
          .map((e) => Comment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Future<void> deletePost(String id) => dio.delete('/community/posts/$id');

  Future<Comment> addComment(String postId, String body) async {
    final r = await dio.post(
      '/community/posts/$postId/comments',
      data: {'body': body},
    );
    return Comment.fromJson(
      Map<String, dynamic>.from(r.data['comment'] as Map),
    );
  }

  Future<void> deleteComment(String id) =>
      dio.delete('/community/comments/$id');

  Future<void> report(String postId, String reason) =>
      dio.post('/community/posts/$postId/report', data: {'reason': reason});

  Future<void> reportComment(String commentId, String reason) => dio.post(
    '/community/comments/$commentId/report',
    data: {'reason': reason},
  );

  // Admin
  Future<List<ReportedPost>> reportedPosts() async {
    final r = await dio.get('/community/reports');
    return ((r.data['reports'] as List?) ?? const [])
        .map((e) => ReportedPost.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> keepPost(String postId) =>
      dio.post('/community/reports/$postId/dismiss');

  Future<List<ReportedComment>> reportedComments() async {
    final r = await dio.get('/community/reports/comments');
    return ((r.data['reports'] as List?) ?? const [])
        .map(
          (e) => ReportedComment.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> keepComment(String commentId) =>
      dio.post('/community/reports/comments/$commentId/dismiss');
}
