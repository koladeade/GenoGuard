import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../widgets/common.dart';

class ResetScreen extends StatefulWidget {
  const ResetScreen({super.key});
  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _pw = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job, {VoidCallback? onOk}) async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await job();
      onOk?.call();
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    return AuthScaffold(
      title: 'Reset your password',
      backTo: '/login',
      subtitle: _codeSent
          ? 'If that email has an account, a 6-digit code is on its way. It expires in 15 minutes.'
          : 'Enter your email and we will send you a 6-digit code to choose a new password.',
      children: [
        AppTextField(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 16),
        if (!_codeSent) ...[
          ErrorText(_err),
          const SizedBox(height: 8),
          PrimaryButton(
            'Send reset code',
            busy: _busy,
            onPressed: () {
              if (!_email.text.contains('@')) {
                setState(() => _err = 'Enter a valid email');
                return;
              }
              _run(
                () => auth.forgotPassword(_email.text.trim().toLowerCase()),
                onOk: () => setState(() => _codeSent = true),
              );
            },
          ),
        ] else ...[
          AppTextField(
            label: '6-digit code',
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'New password',
            controller: _pw,
            password: true,
            helper: 'At least 8 characters',
          ),
          ErrorText(_err),
          const SizedBox(height: 20),
          PrimaryButton(
            'Set new password',
            busy: _busy,
            onPressed: () => _run(
              () => auth.resetPassword(
                _email.text.trim().toLowerCase(),
                _code.text.trim(),
                _pw.text,
              ),
              onOk: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password updated. Log in with your new password.',
                    ),
                  ),
                );
                context.go('/login');
              },
            ),
          ),
        ],
      ],
    );
  }
}
