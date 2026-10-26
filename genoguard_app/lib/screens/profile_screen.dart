import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/location_field.dart';

String homeRoute(String? role) => switch (role) {
  'admin' => '/admin',
  'patient' => '/patient',
  _ => '/explorer',
};

/// Confirms and deletes the account. Returns an error message, or null on success / cancel.
Future<String?> confirmAndDeleteAccount(
  BuildContext context,
  AuthState auth,
) async {
  final hasPassword = (auth.user?['has_password'] as bool?) ?? true;
  final pw = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Delete account?', style: AppText.heading(22)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasPassword
                ? 'This permanently deletes your account and data. Enter your password to confirm.'
                : 'This permanently deletes your account and data.',
            style: AppText.body(15, FontWeight.w500, AppColors.muted),
          ),
          if (hasPassword) ...[
            const SizedBox(height: 14),
            TextField(
              controller: pw,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Password'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(
            'Cancel',
            style: AppText.body(16, FontWeight.w700, AppColors.muted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(
            'Delete',
            style: AppText.body(16, FontWeight.w700, AppColors.error),
          ),
        ),
      ],
    ),
  );
  final password = pw.text;
  pw.dispose();
  if (confirmed != true) return null;
  try {
    await auth.deleteAccount(hasPassword ? password : null);
    return null;
  } catch (e) {
    return errMsg(e);
  }
}

class ProfileScreen extends StatefulWidget {
  /// Edit-profile page. Opened from the Profile tab (patients) or the /profile route.
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _loc;
  late bool _hasScd;
  String? _geno;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthState>().user!;
    _name = TextEditingController(text: (u['full_name'] as String?) ?? '');
    _loc = TextEditingController(text: (u['location'] as String?) ?? '');
    _hasScd = u['has_scd'] as bool;
    _geno = u['genotype'] as String?;
  }

  @override
  void dispose() {
    _name.dispose();
    _loc.dispose();
    super.dispose();
  }

  List<String> get _options => _hasScd ? ['SS', 'SC'] : ['AA', 'AS', 'AC'];

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'Enter your name');
      return;
    }
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
        fullName: _name.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    if (user == null)
      return const SizedBox.shrink(); // logged out; the router is redirecting

    return AuthScaffold(
      title: 'Edit profile',
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).pop()
          : null,
      backTo: homeRoute(auth.role),
      subtitle: user['email'] as String,
      children: [
        AppTextField(label: 'Full name', controller: _name),
        const SizedBox(height: 16),
        LocationField(controller: _loc),
        const SizedBox(height: 22),
        Text(
          'DO YOU LIVE WITH SICKLE CELL DISEASE (SS OR SC)?',
          style: AppText.body(
            14,
            FontWeight.w700,
            AppColors.muted,
          ).copyWith(letterSpacing: 1.1),
        ),
        const SizedBox(height: 10),
        YesNoToggle(
          value: _hasScd,
          onChanged: (v) => setState(() {
            _hasScd = v;
            if (!_options.contains(_geno)) _geno = null;
          }),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Genotype'),
        DropdownButtonFormField<String>(
          value: _geno,
          dropdownColor: AppColors.surface,
          style: AppText.body(16),
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
          decoration: const InputDecoration(hintText: 'Choose'),
          items: [
            for (final g in _options)
              DropdownMenuItem(value: g, child: Text(g)),
          ],
          onChanged: (v) => setState(() => _geno = v),
        ),
        ErrorText(_err),
        const SizedBox(height: 20),
        PrimaryButton('Save changes', onPressed: _save, busy: _busy),
      ],
    );
  }
}
