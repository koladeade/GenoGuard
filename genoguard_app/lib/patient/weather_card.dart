import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'weather_service.dart';

/// Shows a weather alert on the patient Home screen. Renders nothing when the
/// weather is fine, the location is missing, or the lookup fails.
/// The patient can close it with the X; it stays closed until the app restarts
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key, required this.location});
  final String? location;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  late Future<WeatherAlert?> _future;

  // Remembered for the app session, e.g. "2026-10-26-heat".
  static String? _dismissedKey;

  String _keyFor(WeatherAlert a) {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}-${a.kind.name}';
  }

  @override
  void initState() {
    super.initState();
    _future = WeatherService.instance.alertFor(widget.location);
  }

  @override
  void didUpdateWidget(covariant WeatherCard old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) {
      _future = WeatherService.instance.alertFor(widget.location);
    }
  }

  static const _coldBlue = Color(0xFF7FA8D6);
  static const _coldTint = Color(0xFF22344A);

  ({Color color, Color tint, IconData icon}) _style(WeatherKind k) {
    switch (k) {
      case WeatherKind.heat:
        return (
          color: AppColors.red,
          tint: AppColors.redTint,
          icon: Icons.wb_sunny_outlined,
        );
      case WeatherKind.harmattan:
        return (
          color: AppColors.gold,
          tint: AppColors.amberTint,
          icon: Icons.air,
        );
      case WeatherKind.cold:
        return (color: _coldBlue, tint: _coldTint, icon: Icons.ac_unit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherAlert?>(
      future: _future,
      builder: (context, snap) {
        final a = snap.data;
        if (a == null) return const SizedBox.shrink();
        if (_dismissedKey == _keyFor(a)) return const SizedBox.shrink();
        final s = _style(a.kind);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: s.tint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(s.icon, color: s.color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(a.title, style: AppText.heading(20))),
                    IconButton(
                      tooltip: 'Dismiss',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.muted,
                        size: 22,
                      ),
                      onPressed: () =>
                          setState(() => _dismissedKey = _keyFor(a)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  a.summary,
                  style: AppText.body(15, FontWeight.w500, AppColors.muted),
                ),
                const SizedBox(height: 12),
                for (final tip in a.tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tip,
                            style: AppText.body(
                              15,
                              FontWeight.w500,
                              AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
