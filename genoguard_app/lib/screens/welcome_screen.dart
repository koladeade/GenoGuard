import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const IconBadge(icon: Icons.monitor_heart_outlined, size: 112),
            const SizedBox(height: 20),
            Text('GenoGuard', style: AppText.heading(44)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Genotype awareness, pre-marital screening and day-to-day sickle cell care.',
                textAlign: TextAlign.center,
                style: AppText.body(17, FontWeight.w500, AppColors.muted),
              ),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              'Create account',
              onPressed: () => context.go('/consent'),
            ),
            const SizedBox(height: 16),
            SecondaryButton('Log in', onPressed: () => context.go('/login')),
          ],
        ),
      ),
    ),
  );
}
