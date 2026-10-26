import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../explorer/learn_tab.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'learn_content.dart';

/// Opens the full Learn page (articles, sources, quiz) from anywhere, e.g. the patient Profile.
void openLearn(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.chevron_left,
              color: AppColors.muted,
              size: 30,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const SafeArea(child: LearnTab()),
      ),
    ),
  );
}

void openArticle(BuildContext context, Article a) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => ArticleScreen(article: a)));
}

void openQuiz(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const QuizScreen()));
}

// ---------------------------------------------------------------------------
// Article reader

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: article.title,
    subtitle: '${article.minutes} min read',
    backTo: '/welcome',
    onBack: () => Navigator.of(context).pop(),
    children: [for (final b in article.blocks) _BlockView(b)],
  );
}

class _BlockView extends StatelessWidget {
  const _BlockView(this.block);
  final Block block;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case BlockType.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(block.text, style: AppText.heading(22)),
        );
      case BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            block.text,
            style: AppText.body(17, FontWeight.w500).copyWith(height: 1.5),
          ),
        );
      case BlockType.bullets:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in block.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: AppText.body(
                            17,
                            FontWeight.w500,
                          ).copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case BlockType.note:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amberTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              block.text,
              style: AppText.body(15, FontWeight.w600, AppColors.gold),
            ),
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Knowledge quiz: two 5-point ratings, saved with the date and time by the API.

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int? _intention;
  int? _confidence;
  bool _busy = false;
  bool _done = false;
  String? _err;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<AuthState>().api.dio.post(
        '/quiz',
        data: {'intention': _intention, 'confidence': _confidence},
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return AuthScaffold(
        title: 'Thank you',
        subtitle: 'Your answers were saved.',
        backTo: '/welcome',
        onBack: () => Navigator.of(context).pop(),
        children: [
          const SizedBox(height: 8),
          PrimaryButton('Done', onPressed: () => Navigator.of(context).pop()),
        ],
      );
    }

    final ready = _intention != null && _confidence != null;
    return AuthScaffold(
      title: 'Knowledge quiz',
      subtitle: 'Two quick questions. There are no wrong answers.',
      backTo: '/welcome',
      onBack: () => Navigator.of(context).pop(),
      children: [
        _RatingQuestion(
          question:
              'How likely are you to get your genotype tested, or to encourage a partner or relative to?',
          low: 'Not at all likely',
          high: 'Very likely',
          value: _intention,
          onChanged: (v) => setState(() => _intention = v),
        ),
        const SizedBox(height: 26),
        _RatingQuestion(
          question:
              'How confident do you feel talking about genotype with a partner or family?',
          low: 'Not at all confident',
          high: 'Very confident',
          value: _confidence,
          onChanged: (v) => setState(() => _confidence = v),
        ),
        const SizedBox(height: 18),
        Text(
          'Your answers are saved with today\'s date and time.',
          style: AppText.body(14, FontWeight.w500, AppColors.muted),
        ),
        if (_err != null) ...[
          const SizedBox(height: 10),
          Text(
            _err!,
            style: AppText.body(15, FontWeight.w600, AppColors.error),
          ),
        ],
        const SizedBox(height: 18),
        Opacity(
          opacity: ready ? 1 : 0.45,
          child: PrimaryButton(
            'Submit',
            busy: _busy,
            onPressed: ready && !_busy ? _submit : null,
          ),
        ),
      ],
    );
  }
}

class _RatingQuestion extends StatelessWidget {
  const _RatingQuestion({
    required this.question,
    required this.low,
    required this.high,
    required this.value,
    required this.onChanged,
  });
  final String question;
  final String low;
  final String high;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        question,
        style: AppText.body(18, FontWeight.w700).copyWith(height: 1.35),
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 1; i <= 5; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value == i ? AppColors.gold : AppColors.surface,
                  border: Border.all(
                    color: value == i ? AppColors.gold : AppColors.border,
                    width: 1.4,
                  ),
                ),
                child: Text(
                  '$i',
                  style: AppText.body(
                    20,
                    FontWeight.w700,
                    value == i ? AppColors.onGold : AppColors.text,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(low, style: AppText.body(13, FontWeight.w500, AppColors.muted)),
          Text(high, style: AppText.body(13, FontWeight.w500, AppColors.muted)),
        ],
      ),
    ],
  );
}
