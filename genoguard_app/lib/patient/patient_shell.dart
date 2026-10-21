import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import 'home_tab.dart';
import 'pain_state.dart';
import 'pain_tab.dart';
import 'profile_tab.dart';
import 'reminders_state.dart';
import 'reminders_tab.dart';

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});
  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _tab = 0;
  late final PainState _pain;
  late final RemindersState _reminders;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthState>().api;
    _pain = PainState(api)..load();
    _reminders = RemindersState(api)..load();
  }

  @override
  void dispose() {
    _pain.dispose();
    _reminders.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _tab = i);
    // Refresh "today" (taken ticks, water) whenever the user lands on Home or Reminders.
    if (i == 0 || i == 2) _reminders.load(silent: true);
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider<PainState>.value(value: _pain),
      ChangeNotifierProvider<RemindersState>.value(value: _reminders),
    ],
    child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            HomeTab(onGoTo: _go),
            const PainTab(),
            const RemindersTab(),
            const ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _NavBar(index: _tab, onTap: _go),
    ),
  );
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_outlined, 'Home'),
    (Icons.monitor_heart_outlined, 'Pain'),
    (Icons.notifications_none, 'Reminders'),
    (Icons.person_outline, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.navBar,
      border: Border(top: BorderSide(color: AppColors.border, width: 1.2)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 40,
                        decoration: BoxDecoration(
                          color: i == index
                              ? AppColors.gold
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _items[i].$1,
                          size: 26,
                          color: i == index
                              ? AppColors.onGold
                              : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _items[i].$2,
                        style: AppText.body(
                          13,
                          i == index ? FontWeight.w700 : FontWeight.w500,
                          i == index ? AppColors.gold : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
