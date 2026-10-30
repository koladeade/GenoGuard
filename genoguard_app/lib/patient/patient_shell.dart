import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../widgets/bottom_nav.dart';
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

  static const _navItems = [
    (Icons.home_outlined, 'Home'),
    (Icons.monitor_heart_outlined, 'Pain'),
    (Icons.notifications_none, 'Reminders'),
    (Icons.person_outline, 'Profile'),
  ];

  void _go(int i) {
    setState(() => _tab = i);
    // Refresh water intake "today" whenever the user lands on Home or Reminders.
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
      bottomNavigationBar: AppBottomNav(
        items: _navItems,
        index: _tab,
        onTap: _go,
      ),
    ),
  );
}
