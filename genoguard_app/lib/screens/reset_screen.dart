import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            if (!_codeSent) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => auth.forgotPassword(
                          _email.text.trim().toLowerCase(),
                        ),
                        onOk: () => setState(() => _codeSent = true),
                      ),
                child: const Text('Send code'),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'If that email has an account, a 6-digit code is on its way. It expires in 15 minutes.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: '6-digit code'),
              ),
              TextField(
                controller: _pw,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password (8+ characters)',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(
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
                child: const Text('Set new password'),
              ),
            ],
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _err!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to log in'),
            ),
          ],
        ),
      ),
    );
  }
}
