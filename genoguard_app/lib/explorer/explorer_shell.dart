import 'package:flutter/material.dart';
import '../patient/profile_tab.dart';
import '../widgets/bottom_nav.dart';
import 'community_tab.dart';
import 'explorer_home.dart';
import 'learn_tab.dart';

/// Signed-in area for people who do not live with sickle cell (role = explorer).
class ExplorerShell extends StatefulWidget {
  const ExplorerShell({super.key});
  @override
  State<ExplorerShell> createState() => _ExplorerShellState();
}

class _ExplorerShellState extends State<ExplorerShell> {
  int _tab = 0;

  static const _navItems = [
    (Icons.home_outlined, 'Home'),
    (Icons.menu_book_outlined, 'Learn'),
    (Icons.groups_outlined, 'Community'),
    (Icons.person_outline, 'Profile'),
  ];

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: IndexedStack(
        index: _tab,
        children: [
          ExplorerHome(onGoTo: _go),
          const LearnTab(),
          const CommunityTab(),
          const ProfileTab(),
        ],
      ),
    ),
    bottomNavigationBar: AppBottomNav(
      items: _navItems,
      index: _tab,
      onTap: _go,
    ),
  );
}
