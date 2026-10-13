import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/api.dart';
import 'core/auth_state.dart';
import 'core/token_store.dart';
import 'router.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthState(Api(TokenStore()))..boot();
  runApp(
    ChangeNotifierProvider.value(value: auth, child: const GenoGuardApp()),
  );
}

class GenoGuardApp extends StatefulWidget {
  const GenoGuardApp({super.key});
  @override
  State<GenoGuardApp> createState() => _GenoGuardAppState();
}

class _GenoGuardAppState extends State<GenoGuardApp> {
  late final GoRouter _router = buildRouter(context.read<AuthState>());

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'GenoGuard',
    debugShowCheckedModeBanner: false,
    routerConfig: _router,
    theme: buildTheme(),
  );
}
