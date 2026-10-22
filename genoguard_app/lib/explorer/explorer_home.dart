import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/nav_row.dart';
import '../widgets/soon.dart';
import '../compat/compat_screens.dart';

class ExplorerHome extends StatelessWidget {
  const ExplorerHome({super.key, required this.onGoTo});
  final void Function(int tab) onGoTo;

  static const _learnTab = 1;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user ?? const <String, dynamic>{};
    final fullName = ((user['full_name'] as String?) ?? '').trim();
    final first = fullName.isEmpty ? '' : fullName.split(' ').first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          first.isEmpty ? 'Hello' : 'Hello, $first',
          style: AppText.heading(32),
        ),
        const SizedBox(height: 4),
        Text(
          'Explorer account',
          style: AppText.body(16, FontWeight.w500, AppColors.muted),
        ),
        const SizedBox(height: 20),
        NavRow(
          icon: Icons.monitor_heart_outlined,
          title: 'Test compatibility',
          subtitle: 'Pick two genotypes and see the chances',
          onTap: () => openCompatibility(context),
        ),
        NavRow(
          icon: Icons.qr_code_2,
          title: 'Match by QR',
          subtitle: 'Share by short-lived code, with your approval',
          onTap: () => showSoon(context, 'Match by QR'),
        ),
        NavRow(
          icon: Icons.menu_book_outlined,
          title: 'Learn about screening',
          subtitle: 'Articles and a short quiz',
          onTap: () => onGoTo(_learnTab),
        ),
      ],
    );
  }
}
