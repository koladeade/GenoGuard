import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final name =
        (context.watch<AuthState>().user?['full_name'] as String?) ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.gold),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: Center(
        child: Text(
          name.isEmpty ? title : 'Hi, $name',
          style: AppText.heading(28),
        ),
      ),
    );
  }
}
