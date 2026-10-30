import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'password_strength.dart';

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
          ? SizedBox(
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
    this.color,
    this.leading,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color? color; // defaults to gold
  final Widget? leading;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 58,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: color ?? AppColors.gold,
        side: BorderSide(color: AppColors.border, width: 1.2),
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

/// Google's four-colour "G" mark, drawn unmodified (do not recolour, stretch or crop it).
const _googleGSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>''';

/// "Continue with Google" / "Sign up with Google". Uses Google's official "G" mark.
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
    leading: SvgPicture.string(_googleGSvg, width: 22, height: 22),
  );
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        Expanded(child: Divider(color: AppColors.border, thickness: 1.2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: AppText.body(15, FontWeight.w600, AppColors.muted),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border, thickness: 1.2)),
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
    this.showStrength = false,
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
  final bool showStrength;

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
        if (widget.showStrength)
          PasswordStrength(controller: widget.controller),
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
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final String backTo;
  final bool showBack;
  final VoidCallback? onBack; // overrides the default go(backTo)
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          if (showBack)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onBack ?? () => context.go(backTo),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(right: 12),
                ),
                icon: Icon(Icons.chevron_left, color: AppColors.muted),
                label: Text(
                  'Back',
                  style: AppText.body(17, FontWeight.w500, AppColors.muted),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
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
