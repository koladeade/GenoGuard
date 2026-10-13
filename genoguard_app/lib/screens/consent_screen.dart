import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

// TODO: replace with the wording from your approved ethics/consent form, then bump
// kConsentVersion (app) and CONSENT_VERSION (API) together.
const _collected = [
  'Account details: name, email, password (stored hashed)',
  'Your genotype, as you report it',
  'Health logs you add: pain, medication, reminders',
  'Quiz answers with date and time',
  'Usage logs: checks you complete and learning items you open',
];

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  // Off by default: usage logging is opt-in. The design shows it on; flip this to true to match it.
  bool _usageLogs = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: IconBadge(icon: Icons.shield_outlined, size: 96),
          ),
          const SizedBox(height: 20),
          Text('Before you start', style: AppText.heading(34)),
          const SizedBox(height: 14),
          Text(
            'GenoGuard collects the data below to work. You can review or delete it any time in Profile.',
            style: AppText.body(17, FontWeight.w500, AppColors.muted),
          ),
          const SizedBox(height: 22),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What we collect',
                  style: AppText.body(19, FontWeight.w700),
                ),
                const SizedBox(height: 12),
                for (final item in _collected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 9,
                            right: 12,
                            left: 6,
                          ),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.muted,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: AppText.body(
                              17,
                              FontWeight.w500,
                              AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record usage logs',
                        style: AppText.body(19, FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Used only to improve the app and for the study',
                        style: AppText.body(
                          16,
                          FontWeight.w500,
                          AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _usageLogs,
                  onChanged: (v) => setState(() => _usageLogs = v),
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.green,
                  inactiveThumbColor: AppColors.muted,
                  inactiveTrackColor: AppColors.surfaceAlt,
                  trackOutlineColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            'I understand, continue',
            onPressed: () {
              context.read<AuthState>().acceptConsent(usageLogs: _usageLogs);
              context.go('/signup');
            },
          ),
          TextButton(
            onPressed: () => context.go('/welcome'),
            child: Text(
              'Back',
              style: AppText.body(16, FontWeight.w600, AppColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}
