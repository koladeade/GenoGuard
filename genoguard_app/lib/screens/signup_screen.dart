import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _loc = TextEditingController();
  bool? _hasScd;
  String? _geno;
  bool _busy = false;
  bool _googleBusy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    // Arriving from "Continue with Google" on the login screen
    final g = context.read<AuthState>().pendingGoogle;
    if (g != null) _name.text = (g['name'] as String?) ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    _loc.dispose();
    super.dispose();
  }

  List<String> get _genoOptions =>
      _hasScd == true ? ['SS', 'SC'] : ['AA', 'AS', 'AC', 'CC'];

  bool _valid(bool google) {
    if (_name.text.trim().isEmpty) return false;
    if (!google) {
      if (!_email.text.contains('@') || !_email.text.contains('.'))
        return false;
      if (_pw.text.length < 8) return false;
    }
    if (_hasScd == null) return false;
    if (_hasScd! && _geno == null) return false;
    return true;
  }

  String? _loc0() => _loc.text.trim().isEmpty ? null : _loc.text.trim();

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthState>();
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      if (auth.pendingGoogle != null) {
        await auth.completeGoogleSignup(
          fullName: _name.text.trim(),
          hasScd: _hasScd!,
          genotype: _geno,
          location: _loc0(),
        );
      } else {
        await auth.register(
          fullName: _name.text.trim(),
          email: _email.text.trim().toLowerCase(),
          password: _pw.text,
          hasScd: _hasScd!,
          genotype: _geno,
          location: _loc0(),
        );
      }
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
      if (needsProfile && mounted) {
        setState(() {
          if (_name.text.trim().isEmpty)
            _name.text = (auth.pendingGoogle?['name'] as String?) ?? '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = errMsg(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final googleEmail = auth.pendingGoogle?['email'] as String?;
    final google = googleEmail != null;

    return AuthScaffold(
      title: 'Create your account',
      backTo: '/welcome',
      children: [
        Form(
          key: _form,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (google) ...[
                AppCard(
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Google account: $googleEmail',
                          style: AppText.body(15, FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.read<AuthState>().cancelGoogle(),
                        child: Text(
                          'Change',
                          style: AppText.body(
                            15,
                            FontWeight.w700,
                            AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              AppTextField(
                label: 'Full name',
                controller: _name,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              ),
              if (!google) ...[
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v != null && v.contains('@') && v.contains('.'))
                      ? null
                      : 'Enter a valid email',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  controller: _pw,
                  password: true,
                  showStrength: true,
                  helper: 'At least 8 characters',
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v ?? '').length >= 8 ? null : 'At least 8 characters',
                ),
              ],
              const SizedBox(height: 16),
              AppTextField(
                label: 'City or area',
                controller: _loc,
                hint: 'e.g. Lagos',
                helper: 'Used only for weather tips. You can change it later.',
                textInputAction: TextInputAction.done,
              ),
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
                  if (!_genoOptions.contains(_geno)) _geno = null;
                }),
              ),
              if (_hasScd == true)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'The patient side is for people with SS or SC. Everyone else gets the Explore side.',
                    style: AppText.body(15, FontWeight.w500, AppColors.muted),
                  ),
                ),
              if (_hasScd != null) ...[
                const SizedBox(height: 16),
                FieldLabel(
                  _hasScd! ? 'Your genotype' : 'Your genotype (optional)',
                ),
                DropdownButtonFormField<String>(
                  value: _geno,
                  dropdownColor: AppColors.surface,
                  style: AppText.body(16),
                  icon: Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
                  decoration: const InputDecoration(hintText: 'Choose'),
                  items: [
                    for (final g in _genoOptions)
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => setState(() => _geno = v),
                  validator: (v) =>
                      (_hasScd == true && v == null) ? 'Choose SS or SC' : null,
                ),
              ],
            ],
          ),
        ),
        ErrorText(_err),
        const SizedBox(height: 20),
        PrimaryButton(
          google ? 'Finish sign-up' : 'Create account',
          busy: _busy,
          onPressed: _valid(google) ? _submit : null,
        ),
        if (!google) ...[
          const OrDivider(),
          GoogleButton(
            label: 'Sign up with Google',
            onPressed: _google,
            busy: _googleBusy,
          ),
        ],
      ],
    );
  }
}
