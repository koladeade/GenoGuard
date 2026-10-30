import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/geno_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          children: [
            const Spacer(flex: 3),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const GenoLogo(width: 84),
            ),
            const SizedBox(height: 28),
            Text('GenoGuard', style: AppText.heading(40)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: Text(
                'Know your genotype.\nLive well with sickle cell.',
                textAlign: TextAlign.center,
                style: AppText.body(
                  17,
                  FontWeight.w500,
                  AppColors.muted,
                ).copyWith(height: 1.4),
              ),
            ),
            const Spacer(flex: 4),
            PrimaryButton(
              'Create account',
              onPressed: () => context.go('/consent'),
            ),
            const SizedBox(height: 14),
            SecondaryButton('Log in', onPressed: () => context.go('/login')),
          ],
        ),
      ),
    ),
  );
}
