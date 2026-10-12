import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/api.dart';
import 'core/auth_state.dart';
import 'core/token_store.dart';
import 'router.dart';

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
    routerConfig: _router,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFFB3261E),
      useMaterial3: true,
      brightness: Brightness.light,
    ),
  );
}
