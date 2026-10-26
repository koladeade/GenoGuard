import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../learn/learn_content.dart';
import '../learn/learn_screens.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../patient/reminder_utils.dart' show kBlue, kBlueTint;

class LearnTab extends StatelessWidget {
  const LearnTab({super.key});

  static const _sources = [
    (
      'WHO fact sheet on sickle cell disease',
      'https://www.who.int/news-room/fact-sheets/detail/sickle-cell-disease',
    ),
    ('CDC guidance on sickle cell', 'https://www.cdc.gov/sickle-cell/'),
  ];

  Future<void> _open(BuildContext context, String url) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the link')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    children: [
      Text('Learn', style: AppText.heading(32)),
      const SizedBox(height: 16),
      for (final a in kArticles) ...[
        AppCard(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => openArticle(context, a),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: AppText.body(19, FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${a.minutes} min read',
                        style: AppText.body(
                          14,
                          FontWeight.w500,
                          AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: kBlueTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Read',
                    style: AppText.body(15, FontWeight.w700, kBlue),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Trusted sources',
                    style: AppText.body(19, FontWeight.w700),
                  ),
                ),
                const Icon(Icons.open_in_new, size: 22, color: AppColors.text),
              ],
            ),
            for (final s in _sources) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _open(context, s.$2),
                child: Text(
                  s.$1,
                  style: AppText.body(18, FontWeight.w500, AppColors.gold)
                      .copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.gold,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => openQuiz(context),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.gold, width: 1.4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Knowledge quiz',
                      style: AppText.body(19, FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Two quick questions',
                      style: AppText.body(16, FontWeight.w500, AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.text, size: 26),
            ],
          ),
        ),
      ),
    ],
  );
}
