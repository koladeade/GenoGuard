import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Strength bar plus a checklist of what makes a password strong. Updates as the user types.
class PasswordStrength extends StatelessWidget {
  const PasswordStrength({super.key, required this.controller});
  final TextEditingController controller;

  static const _common = {
    'password',
    'password1',
    'password123',
    '12345678',
    '123456789',
    '1234567890',
    'qwertyui',
    'qwerty123',
    'iloveyou',
    'genoguard',
    'abcd1234',
    '11111111',
  };

  static bool _hasCase(String p) =>
      RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p);
  static bool _hasNumber(String p) => RegExp(r'\d').hasMatch(p);
  static bool _hasSymbol(String p) => RegExp(r'[^A-Za-z0-9]').hasMatch(p);

  /// 0 = too short, 1 = weak, 2 = fair, 3 = good, 4 = strong
  static int score(String p) {
    if (p.length < 8) return 0;
    if (_common.contains(p.toLowerCase())) return 1;
    var s = 0;
    if (p.length >= 12) s++;
    if (_hasCase(p)) s++;
    if (_hasNumber(p)) s++;
    if (_hasSymbol(p)) s++;
    return s.clamp(1, 4);
  }

  Widget _rule(String text, bool ok, bool typed) {
    final color = ok ? AppColors.green : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppText.body(14, FontWeight.w500, color)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, v, _) {
          final p = v.text;
          final typed = p.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (typed && _common.contains(p.toLowerCase()))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'This is a very common password.',
                      style: AppText.body(14, FontWeight.w600, AppColors.error),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'A strong password has:',
                  style: AppText.body(14, FontWeight.w600, AppColors.muted),
                ),
                _rule('At least 8 characters (required)', p.length >= 8, typed),
                _rule('Upper and lowercase letters', _hasCase(p), typed),
                _rule('A number', _hasNumber(p), typed),
                _rule('A symbol, like ! @ # ?', _hasSymbol(p), typed),
              ],
            ),
          );
        },
      );
}
