import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Rounded gold square with an icon (logo / section badge).
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.size = 96});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, color: AppColors.onGold, size: size * 0.3),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border, width: 1.2),
    ),
    child: child,
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 58,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.onGold,
        disabledBackgroundColor: AppColors.goldDisabled,
        disabledForegroundColor: AppColors.onGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: AppText.body(18, FontWeight.w700),
      ),
      child: busy
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.onGold,
              ),
            )
          : Text(label),
    ),
  );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.color = AppColors.gold,
    this.leading,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 58,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: color,
        side: const BorderSide(color: AppColors.border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: AppText.body(17, FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Text(label),
        ],
      ),
    ),
  );
}

/// "Continue with Google". The "G" is a plain placeholder: swap in Google's official
/// logo asset before release (see Google's branding guidelines).
class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.label = 'Continue with Google',
  });
  final VoidCallback? onPressed;
  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) => SecondaryButton(
    busy ? 'Connecting...' : label,
    onPressed: busy ? null : onPressed,
    color: AppColors.text,
    leading: Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        'G',
        style: AppText.body(16, FontWeight.w800, const Color(0xFF4285F4)),
      ),
    ),
  );
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 1.2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: AppText.body(15, FontWeight.w600, AppColors.muted),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 1.2)),
      ],
    ),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: AppText.body(15, FontWeight.w600, AppColors.muted),
    ),
  );
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            message!,
            style: AppText.body(14, FontWeight.w600, AppColors.error),
          ),
        );
}

/// Label above a filled field; optional "Show / Hide" pill for passwords.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.keyboardType,
    this.password = false,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final bool password;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final int? maxLength;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      obscureText: widget.password && _hidden,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      maxLength: widget.maxLength,
      style: AppText.body(16),
      decoration: InputDecoration(hintText: widget.hint, counterText: ''),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label),
        if (!widget.password)
          field
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 12),
              SizedBox(
                height: 58,
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _hidden = !_hidden),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _hidden ? 'Show' : 'Hide',
                        style: AppText.body(
                          15,
                          FontWeight.w700,
                          AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.helper!,
              style: AppText.body(15, FontWeight.w500, AppColors.muted),
            ),
          ),
      ],
    );
  }
}

/// Two-option Yes / No selector. Nothing is selected until the user taps.
class YesNoToggle extends StatelessWidget {
  const YesNoToggle({super.key, required this.value, required this.onChanged});
  final bool? value;
  final ValueChanged<bool> onChanged;

  Widget _segment(String label, bool v) {
    final selected = value == v;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(v),
        child: Container(
          margin: const EdgeInsets.all(5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            label,
            style: AppText.body(
              17,
              FontWeight.w700,
              selected ? AppColors.onGold : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 60,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border, width: 1.2),
    ),
    child: Row(children: [_segment('Yes', true), _segment('No', false)]),
  );
}

/// Screen with a "< Back" link, serif title, optional subtitle, then the children.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.backTo = '/welcome',
  });

  final String title;
  final String? subtitle;
  final String backTo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go(backTo),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(right: 12),
              ),
              icon: const Icon(Icons.chevron_left, color: AppColors.muted),
              label: Text(
                'Back',
                style: AppText.body(17, FontWeight.w500, AppColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: AppText.heading(32)),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              subtitle!,
              style: AppText.body(16, FontWeight.w500, AppColors.muted),
            ),
          ],
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
}
