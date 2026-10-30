import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../compat/compat_screens.dart';
import '../match/match_screens.dart';
import '../learn/learn_screens.dart';
import '../community/community_screens.dart';
import '../privacy/privacy_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  void _soon(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    if (user == null)
      return const SizedBox.shrink(); // logged out; the router is redirecting

    final fullName = ((user['full_name'] as String?) ?? '').trim();
    final email = (user['email'] as String?) ?? '';
    final name = fullName.isNotEmpty
        ? fullName
        : (email.contains('@') ? email.split('@').first : 'You');
    final genotype = user['genotype'] as String?;
    final location = ((user['location'] as String?) ?? '').trim();
    final isPatient = auth.role == 'patient';
    final subtitle = [
      isPatient ? 'Patient' : 'Explorer',
      if (genotype != null) '$genotype genotype',
      if (location.isNotEmpty) location,
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      children: [
        Text('Profile', style: AppText.heading(32)),
        const SizedBox(height: 16),

        // Identity card
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.gold,
                child: Text(
                  name[0].toUpperCase(),
                  style: AppText.body(26, FontWeight.w700, AppColors.onGold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppText.body(21, FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.body(15, FontWeight.w500, AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amberTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Edit',
                    style: AppText.body(16, FontWeight.w700, AppColors.gold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (isPatient) ...[
          _MenuRow(
            icon: Icons.monitor_heart_outlined,
            title: 'Test compatibility',
            subtitle: 'Two genotypes, full probabilities',
            onTap: () => openCompatibility(context),
          ),
          _MenuRow(
            icon: Icons.qr_code_2,
            title: 'Match by QR',
            subtitle: 'Share with your approval',
            onTap: () => openMatchByQr(context),
          ),
          _MenuRow(
            icon: Icons.menu_book_outlined,
            title: 'Learn and quiz',
            subtitle: 'Articles and a short quiz',
            onTap: () => openLearn(context),
          ),
          _MenuRow(
            icon: Icons.groups_outlined,
            title: 'Community',
            subtitle: 'Stories from others',
            onTap: () => openCommunity(context),
          ),
        ],
        _MenuRow(
          icon: Icons.shield_outlined,
          title: 'Privacy and data',
          subtitle: 'Consent and usage logs',
          onTap: () => openPrivacy(context),
        ),

        SecondaryButton('Log out', onPressed: () => auth.logout()),
        const SizedBox(height: 12),
        _OutlineDanger(
          label: 'Delete account',
          onTap: () async {
            final err = await confirmAndDeleteAccount(context, auth);
            if (err != null && context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(err)));
            }
          },
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.gold, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(19, FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.body(15, FontWeight.w500, AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.text, size: 26),
          ],
        ),
      ),
    ),
  );
}

class _OutlineDanger extends StatelessWidget {
  const _OutlineDanger({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: onTap,
    child: Container(
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Text(
        label,
        style: AppText.body(17, FontWeight.w700, AppColors.red),
      ),
    ),
  );
}
