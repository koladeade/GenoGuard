import 'package:flutter/material.dart';

/// Placeholder for features that are designed but not built yet.
void showSoon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what is coming soon')));
}
