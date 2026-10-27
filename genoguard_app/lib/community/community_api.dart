import 'package:dio/dio.dart';

/// Why a post is being reported. Keys match the API; values are what people see.
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
  });
  final String id;
  final String body;
  final String author;
  final DateTime createdAt;
  final bool mine;
  int commentCount;
  bool reported;

  factory Post.fromJson(Map<String, dynamic> j) => Post(
    id: j['id'] as String,
    body: j['body'] as String,
    author: (j['author'] as String?) ?? 'Member',
    createdAt: _time(j['created_at']),
    mine: j['mine'] == true,
    commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
    reported: j['reported'] == true,
  );
}

class Comment {
  Comment({
    required this.id,
    required this.body,
    required this.author,
    required this.createdAt,
    required this.mine,
  });
  final String id;
  final String body;
  final String author;
  final DateTime createdAt;
  final bool mine;

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    id: j['id'] as String,
    body: j['body'] as String,
    author: (j['author'] as String?) ?? 'Member',
    createdAt: _time(j['created_at']),
    mine: j['mine'] == true,
  );
}

/// A post waiting in the admin queue.
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

/// Thin wrapper over the /community endpoints. Errors are thrown as DioException; show them with errMsg().
class CommunityApi {
  CommunityApi(this.dio);
  final Dio dio;

  Future<List<Post>> posts() async {
    final r = await dio.get('/community/posts');
    return ((r.data['posts'] as List?) ?? const [])
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
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

  // Admin
  Future<List<ReportedPost>> reportedPosts() async {
    final r = await dio.get('/community/reports');
    return ((r.data['reports'] as List?) ?? const [])
        .map((e) => ReportedPost.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> keepPost(String postId) =>
      dio.post('/community/reports/$postId/dismiss');
}
