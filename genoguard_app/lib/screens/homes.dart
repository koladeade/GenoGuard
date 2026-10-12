import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder landing page per role; the real patient tabs, explore flow and
/// admin moderation queue replace these.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        IconButton(
          icon: const Icon(Icons.person),
          onPressed: () => context.go('/profile'),
        ),
      ],
    ),
    body: Center(child: Text(title)),
  );
}
