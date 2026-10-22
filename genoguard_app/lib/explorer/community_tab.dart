import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/soon.dart';
import '../patient/reminder_utils.dart' show kBlue, kBlueTint;

class CommunityTab extends StatelessWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    children: [
      Row(
        children: [
          Expanded(child: Text('Community', style: AppText.heading(32))),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showSoon(context, 'Sharing'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kBlueTint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBlue, width: 1.2),
        ),
        child: Text(
          'Be kind and share from experience. This is not medical advice. Admins may remove posts that break the guidelines.',
          style: AppText.body(17, FontWeight.w500),
        ),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Text(
          'No posts yet. Stories shared by the community will appear here.',
          style: AppText.body(17, FontWeight.w500, AppColors.muted),
        ),
      ),
    ],
  );
}
