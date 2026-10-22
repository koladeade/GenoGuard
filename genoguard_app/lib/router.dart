import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/auth_state.dart';
import 'explorer/explorer_shell.dart';
import 'patient/patient_shell.dart';
import 'screens/consent_screen.dart';
import 'screens/homes.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reset_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

const _publicRoutes = {'/welcome', '/login', '/consent', '/signup', '/reset'};

String homeFor(String? role) => switch (role) {
  'admin' => '/admin',
  'patient' => '/patient',
  _ => '/explorer',
};

/// Single place where role routing happens. The role comes from the server (/me),
/// never from decoding the JWT on the device, and the API enforces it again per request.
GoRouter buildRouter(AuthState auth) => GoRouter(
  initialLocation: '/splash',
  refreshListenable: auth,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    if (auth.status == AuthStatus.unknown)
      return loc == '/splash' ? null : '/splash';

    if (auth.status == AuthStatus.unauthed) {
      if (!_publicRoutes.contains(loc)) return '/welcome';
      if (loc == '/signup' && !auth.consentAccepted) return '/consent';
      return null;
    }

    final home = homeFor(auth.role);
    if (_publicRoutes.contains(loc) || loc == '/splash') return home;
    if (loc.startsWith('/patient') && auth.role != 'patient') return home;
    if (loc.startsWith('/explorer') && auth.role != 'explorer') return home;
    if (loc.startsWith('/admin') && auth.role != 'admin') return home;
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, __) => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      ),
    ),
    GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/consent', builder: (_, __) => const ConsentScreen()),
    GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
    GoRoute(path: '/reset', builder: (_, __) => const ResetScreen()),
    GoRoute(path: '/patient', builder: (_, __) => const PatientShell()),
    GoRoute(path: '/explorer', builder: (_, __) => const ExplorerShell()),
    GoRoute(
      path: '/admin',
      builder: (_, __) => const HomeShell(title: 'Admin'),
    ),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
  ],
);
