import 'package:dio/dio.dart';
import '../core/ng_states.dart';

enum WeatherKind { heat, cold, harmattan }

class WeatherAlert {
  const WeatherAlert({
    required this.kind,
    required this.title,
    required this.summary,
    required this.tips,
  });
  final WeatherKind kind;
  final String title;
  final String summary;
  final List<String> tips;
}

/// Fetches today's weather for the user's saved location from Open-Meteo
/// (free, no API key) and turns it into an alert only when conditions warrant.
class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  final Map<String, ({double lat, double lon, String name})> _places = {};
  final Map<String, ({DateTime at, WeatherAlert? alert})> _cache = {};

  /// Returns an alert, or null when the weather is fine, the location is empty
  /// or can't be found, or the network fails. Never throws.
  Future<WeatherAlert?> alertFor(String? location, {bool force = false}) async {
    final key = (location ?? '').trim().toLowerCase();
    if (key.isEmpty) return null;

    final hit = _cache[key];
    if (!force &&
        hit != null &&
        DateTime.now().difference(hit.at) < const Duration(minutes: 60)) {
      return hit.alert;
    }

    try {
      final place = _places[key] ?? await _geocode(location!.trim());
      if (place == null) return null;
      _places[key] = place;

      final results = await Future.wait([
        _forecast(place.lat, place.lon),
        _air(place.lat, place.lon),
      ]);
      final f = results[0];
      final a = results[1];
      if (f == null) return null;

      final alert = evaluate(
        place: place.name,
        maxTemp: f['max'],
        minTemp: f['min'],
        feelsMax: f['feels'],
        humidity: f['humidity'],
        dust: a?['dust'],
        pm10: a?['pm10'],
        month: DateTime.now().month,
      );
      _cache[key] = (at: DateTime.now(), alert: alert);
      return alert;
    } catch (_) {
      return null;
    }
  }

  double? _num(dynamic v) => v is num ? v.toDouble() : null;
  double? _first(dynamic list) =>
      (list is List && list.isNotEmpty) ? _num(list.first) : null;

  /// "Ikeja, Lagos" → tries "Ikeja", then "Lagos". Prefers a Nigerian match.
  Future<({double lat, double lon, String name})?> _geocode(
    String location,
  ) async {
    final parts = location
        .split(',')
        .map((s) => weatherPlaceFor(s.trim()))
        .where((s) => s.isNotEmpty)
        .take(2);
    for (final part in parts) {
      final res = await _dio.get(
        'https://geocoding-api.open-meteo.com/v1/search',
        queryParameters: {
          'name': part,
          'count': 10,
          'language': 'en',
          'format': 'json',
        },
      );
      final list = (res.data is Map ? res.data['results'] : null) as List?;
      if (list == null || list.isEmpty) continue;
      final pick = list.cast<Map>().firstWhere(
        (r) => r['country_code'] == 'NG',
        orElse: () => list.first as Map,
      );
      final lat = _num(pick['latitude']);
      final lon = _num(pick['longitude']);
      if (lat == null || lon == null) continue;
      return (lat: lat, lon: lon, name: (pick['name'] as String?) ?? part);
    }
    return null;
  }

  Future<Map<String, double?>?> _forecast(double lat, double lon) async {
    final res = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'current': 'temperature_2m,relative_humidity_2m,apparent_temperature',
        'daily':
            'temperature_2m_max,temperature_2m_min,apparent_temperature_max',
        'timezone': 'auto',
        'forecast_days': 1,
      },
    );
    final d = res.data;
    if (d is! Map) return null;
    final daily = d['daily'];
    final cur = d['current'];
    return {
      'max': daily is Map ? _first(daily['temperature_2m_max']) : null,
      'min': daily is Map ? _first(daily['temperature_2m_min']) : null,
      'feels': daily is Map ? _first(daily['apparent_temperature_max']) : null,
      'humidity': cur is Map ? _num(cur['relative_humidity_2m']) : null,
    };
  }

  /// Dust and PM10 (µg/m³). Optional: failure just means no dust reading.
  Future<Map<String, double?>?> _air(double lat, double lon) async {
    try {
      final res = await _dio.get(
        'https://air-quality-api.open-meteo.com/v1/air-quality',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': 'dust,pm10',
          'timezone': 'auto',
        },
      );
      final cur = res.data is Map ? res.data['current'] : null;
      if (cur is! Map) return null;
      return {'dust': _num(cur['dust']), 'pm10': _num(cur['pm10'])};
    } catch (_) {
      return null;
    }
  }

  /// Pure decision logic. Heat is checked first, then harmattan, then cold.
  static WeatherAlert? evaluate({
    required String place,
    double? maxTemp,
    double? minTemp,
    double? feelsMax,
    double? humidity,
    double? dust,
    double? pm10,
    required int month,
  }) {
    // Heat: hot day or it feels very hot.
    if ((maxTemp != null && maxTemp >= 35) ||
        (feelsMax != null && feelsMax >= 38)) {
      final t = (maxTemp ?? feelsMax)!.round();
      return WeatherAlert(
        kind: WeatherKind.heat,
        title: 'Hot weather today',
        summary:
            'Up to $t°C in $place. Heat dries you out faster, which can trigger a crisis.',
        tips: const [
          'Drink extra water through the day, not only when thirsty.',
          'Stay out of direct sun between 12 and 4 PM.',
          'Wear light clothing and rest in the shade or a cool room.',
        ],
      );
    }

    // Harmattan: dusty air, or very dry air in the harmattan months (Nov to Mar).
    final harmattanSeason = month >= 11 || month <= 3;
    final dusty =
        (dust != null && dust >= 100) || (pm10 != null && pm10 >= 150);
    final veryDry = harmattanSeason && humidity != null && humidity <= 30;
    if (dusty || veryDry) {
      return WeatherAlert(
        kind: WeatherKind.harmattan,
        title: dusty ? 'Dusty, dry air today' : 'Very dry air today',
        summary:
            'Harmattan conditions in $place. Dry air dehydrates you and irritates the chest.',
        tips: const [
          'Drink more water than usual.',
          'Moisturise your skin and lips, and protect your eyes from dust.',
          'Cover your nose and mouth in dust. Call your doctor for cough, chest pain or fast breathing.',
        ],
      );
    }

    // Cold: cool night or morning.
    if (minTemp != null && minTemp <= 17) {
      return WeatherAlert(
        kind: WeatherKind.cold,
        title: 'Cold weather today',
        summary:
            'Down to ${minTemp.round()}°C in $place. Cold can trigger pain, so keep warm.',
        tips: const [
          'Dress in layers and keep your hands, feet and chest warm.',
          'Avoid sudden cold, such as cold showers or a fan or AC blowing on you.',
          'Have warm drinks and keep up your water.',
        ],
      );
    }

    return null;
  }
}
