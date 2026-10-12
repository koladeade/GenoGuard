import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';

// kConsentVersion (app) and CONSENT_VERSION (API) together.
const kConsentText =
    '''GenoGuard helps you understand genotype compatibility and, if you live with sickle cell disease, track your health.

What we collect
- Your email, an encrypted password, and your location (city or state).
- Whether you live with sickle cell disease (SS or SC) and your genotype. This is health information.
- Later: pain logs, reminders and quiz answers you choose to enter. Usage analytics are recorded only if you agree to them separately.

How we use it
- To run your account and show the right side of the app for you.
- Your genotype is never shared with another user unless you confirm each time you share it.
- Anonymous, combined results may be used for the research behind this project.

Your choices
- You can edit your details or delete your account and data at any time from your profile.
- Using GenoGuard is voluntary. This app does not replace advice from a doctor.''';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agree = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Before you start')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              child: SingleChildScrollView(child: Text(kConsentText)),
            ),
            CheckboxListTile(
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I have read this and I agree'),
            ),
            FilledButton(
              onPressed: _agree
                  ? () {
                      context.read<AuthState>().acceptConsent();
                      context.go('/signup');
                    }
                  : null,
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to log in'),
            ),
          ],
        ),
      ),
    ),
  );
}
