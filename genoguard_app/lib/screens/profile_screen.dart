import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late bool _hasScd;
  String? _geno;
  late final TextEditingController _loc;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthState>().user!;
    _hasScd = u['has_scd'] as bool;
    _geno = u['genotype'] as String?;
    _loc = TextEditingController(text: (u['location'] as String?) ?? '');
  }

  List<String> get _options =>
      _hasScd ? ['SS', 'SC'] : ['AA', 'AS', 'AC', 'CC'];

  Future<void> _save() async {
    if (_hasScd && _geno == null) {
      setState(() => _err = 'Choose SS or SC');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<AuthState>().updateProfile(
        hasScd: _hasScd,
        genotype: _geno,
        location: _loc.text.trim().isEmpty ? null : _loc.text.trim(),
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final pw = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This permanently deletes your account and data. Enter your password to confirm.',
            ),
            TextField(
              controller: pw,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AuthState>().deleteAccount(pw.text);
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: BackButton(onPressed: () => context.go(homeRoute(auth.role))),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              auth.user!['email'] as String,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _loc,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 16),
            const Text('I live with sickle cell disease (SS or SC)'),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Yes')),
                ButtonSegment(value: false, label: Text('No')),
              ],
              selected: {_hasScd},
              onSelectionChanged: (s) => setState(() {
                _hasScd = s.first;
                if (!_options.contains(_geno)) _geno = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _geno,
              decoration: const InputDecoration(labelText: 'Genotype'),
              items: [
                for (final g in _options)
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: (v) => setState(() => _geno = v),
            ),
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
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => auth.logout(),
              child: const Text('Log out'),
            ),
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete account'),
            ),
          ],
        ),
      ),
    );
  }
}

String homeRoute(String? role) => switch (role) {
  'admin' => '/admin',
  'patient' => '/patient',
  _ => '/explorer',
};
