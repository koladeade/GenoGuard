import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  bool _googleBusy = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() => _err = 'Enter your email and password');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<AuthState>().login(
        _email.text.trim().toLowerCase(),
        _pw.text,
      );
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    final auth = context.read<AuthState>();
    setState(() {
      _googleBusy = true;
      _err = null;
    });
    try {
      final needsProfile = await auth.signInWithGoogle();
      if (needsProfile && mounted)
        context.go(auth.consentAccepted ? '/signup' : '/consent');
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Welcome back',
    children: [
      AppTextField(
        label: 'Email',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      AppTextField(
        label: 'Password',
        controller: _pw,
        password: true,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => context.go('/reset'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            'Forgot password?',
            style: AppText.body(16, FontWeight.w700, AppColors.gold),
          ),
        ),
      ),
      ErrorText(_err),
      const SizedBox(height: 8),
      PrimaryButton('Log in', onPressed: _submit, busy: _busy),
      const OrDivider(),
      GoogleButton(onPressed: _google, busy: _googleBusy),
      const SizedBox(height: 16),
      Center(
        child: TextButton(
          onPressed: () => context.go('/consent'),
          child: Text(
            'New here? Create account',
            style: AppText.body(16, FontWeight.w700, AppColors.gold),
          ),
        ),
      ),
    ],
  );
}
