import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _loc = TextEditingController();
  bool? _hasScd;
  String? _geno;
  bool _busy = false;
  String? _err;

  List<String> get _options =>
      _hasScd == true ? ['SS', 'SC'] : ['AA', 'AS', 'AC', 'CC'];

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_hasScd == null) {
      setState(() => _err = 'Please answer the sickle cell question');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<AuthState>().register(
        email: _email.text.trim().toLowerCase(),
        password: _pw.text,
        hasScd: _hasScd!,
        genotype: _geno,
        location: _loc.text.trim().isEmpty ? null : _loc.text.trim(),
      );
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create account')),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  (v != null && v.contains('@') && v.contains('.'))
                  ? null
                  : 'Enter a valid email',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pw,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (8+ characters)',
              ),
              validator: (v) =>
                  (v ?? '').length >= 8 ? null : 'At least 8 characters',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _loc,
              decoration: const InputDecoration(
                labelText: 'Location (city or state, optional)',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Do you live with sickle cell disease (SS or SC)?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(value: true, label: Text('Yes')),
                ButtonSegment(value: false, label: Text('No')),
              ],
              selected: _hasScd == null ? <bool>{} : {_hasScd!},
              onSelectionChanged: (s) => setState(() {
                _hasScd = s.isEmpty ? null : s.first;
                _geno = null;
              }),
            ),
            if (_hasScd == true)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'The patient side is for people with SS or SC. Everyone else gets the Explore side.',
                ),
              ),
            if (_hasScd != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _geno,
                decoration: InputDecoration(
                  labelText: _hasScd!
                      ? 'Your genotype'
                      : 'Your genotype (optional)',
                ),
                items: [
                  for (final g in _options)
                    DropdownMenuItem(value: g, child: Text(g)),
                ],
                onChanged: (v) => setState(() => _geno = v),
                validator: (v) =>
                    (_hasScd == true && v == null) ? 'Choose SS or SC' : null,
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
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Creating...' : 'Create account'),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
    ),
  );
}
