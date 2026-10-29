import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'auth_state.dart';

/// Records a usage event, but only when the signed-in user has switched usage logs on.
/// The API checks the consent again on every call, so nothing is stored without it.
/// Events are names only (never what the user typed or any health data):
///   compat_check, qr_match, learning_open (+ item: an article id or 'quiz').
class Usage {
  static void log(BuildContext context, String event, {String? item}) {
    try {
      final auth = context.read<AuthState>();
      if (auth.user?['usage_logs_consent'] != true) return;
      unawaited(
        auth.api.dio
            .post(
              '/usage',
              data: {'event': event, if (item != null) 'item': item},
            )
            .then<void>((_) {}, onError: (_) {}),
      );
    } catch (_) {
      // Logging must never break the app.
    }
  }
}
