import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../widgets/fire_risk_badge.dart';

class FireRisk {
  final int score; // 0-100
  final RiskLevel level;
  final String label;
  final String summary;
  final String details;

  FireRisk({
    required this.score,
    required this.level,
    required this.label,
    required this.summary,
    required this.details,
  });
}

class OpenMeteoService {
  static const _base = 'https://api.open-meteo.com/v1/forecast';

  Future<FireRisk> getRisk(double lat, double lon) async {
    final params = {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'hourly': [
        'temperature_2m',
        'relative_humidity_2m',
        'wind_speed_10m',
        'precipitation',
        'precipitation_probability',
        'vapour_pressure_deficit'
      ].join(','),
      'timezone': 'auto',
      'past_days': '2', // include 2 days back to accumulate rain
      'forecast_days': '3',
      'windspeed_unit': 'kmh',
    };
    final uri = Uri.parse(_base).replace(queryParameters: params);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Open-Meteo error: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final t = (hourly['temperature_2m'] as List).cast<num>().map((e)=>e.toDouble()).toList();
    final rh = (hourly['relative_humidity_2m'] as List).cast<num>().map((e)=>e.toDouble()).toList();
    final wind = (hourly['wind_speed_10m'] as List).cast<num>().map((e)=>e.toDouble()).toList();
    final precip = (hourly['precipitation'] as List).cast<num>().map((e)=>e.toDouble()).toList();
    final vpd = (hourly['vapour_pressure_deficit'] as List?)?.cast<num>().map((e)=>e.toDouble()).toList() ?? List<double>.filled(times.length, 0);

    // Consider next 24h (and past 72h rain)
    final nowIdx = 0; // API starts at 00:00 local today; approx
    final nextH = min(24, times.length - nowIdx);
    final last72h = min(72, times.length);

    final avgTemp = _avg(t.sublist(nowIdx, nowIdx + nextH));
    final minRH = rh.sublist(nowIdx, nowIdx + nextH).reduce(min);
    final maxWind = wind.sublist(nowIdx, nowIdx + nextH).reduce(max);
    final sumPrecip72 = precip.sublist(max(0, last72h - 72), last72h).fold<double>(0.0, (a, b) => a + b);
    final maxVPD = vpd.sublist(nowIdx, nowIdx + nextH).reduce(max);

    // Heuristic scoring 0..100
    // temp: 20..38C -> 0..30
    final tempScore = _scale(avgTemp, 20, 38) * 30;
    // humidity: 60%..20% -> 0..25
    final rhScore = _scale(60 - minRH, 0, 40) * 25;
    // wind: 10..40 km/h -> 0..25
    final windScore = _scale(maxWind, 10, 40) * 25;
    // dry: 0..6 mm rain in last 72h -> 25..0 (inverse, dryer = more risk)
    final dryScore = (1 - _scale(sumPrecip72, 0, 6)) * 15;
    // VPD: 0.4..2.2 kPa -> 0..5
    final vpdScore = _scale(maxVPD, 0.4, 2.2) * 5;

    final score = (tempScore + rhScore + windScore + dryScore + vpdScore).clamp(0, 100).round();

    final level = score < 15 ? RiskLevel.veryLow
        : score < 35 ? RiskLevel.low
        : score < 55 ? RiskLevel.moderate
        : score < 75 ? RiskLevel.high
        : RiskLevel.extreme;

    final label = switch (level) {
      RiskLevel.veryLow => 'Very Low',
      RiskLevel.low => 'Low',
      RiskLevel.moderate => 'Moderate',
      RiskLevel.high => 'High',
      RiskLevel.extreme => 'Extreme',
    };

    final summary = 'Temp ${avgTemp.toStringAsFixed(0)}°C • RH ${minRH.toStringAsFixed(0)}% • Wind ${maxWind.toStringAsFixed(0)} km/h';
    final details = 'Rain last 72h: ${sumPrecip72.toStringAsFixed(1)} mm • Max VPD: ${maxVPD.toStringAsFixed(1)} kPa';

    return FireRisk(score: score, level: level, label: label, summary: summary, details: details);
  }

  double _avg(List<double> xs) => xs.isEmpty ? 0 : xs.reduce((a,b)=>a+b) / xs.length;

  double _scale(double x, double a, double b) {
    if (x <= a) return 0;
    if (x >= b) return 1;
    return (x - a) / (b - a);
  }
}
