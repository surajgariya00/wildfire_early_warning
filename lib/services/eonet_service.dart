import 'dart:convert';
import 'package:http/http.dart' as http;

class EonetEvent {
  final String id;
  final String title;
  final DateTime date;
  final double lat;
  final double lon;

  EonetEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.lat,
    required this.lon,
  });
}

class EonetService {
  static const _base = 'https://eonet.gsfc.nasa.gov/api/v3/events';

  /// bbox: [minLon, maxLat, maxLon, minLat]
  static List<double> makeBBox(dynamic center, double degrees) {
    final double lat, lon;
    if (center is List<double>) {
      lat = center[0]; lon = center[1];
    } else {
      // center is a LatLng-like object with .latitude/.longitude
      lat = center.latitude; lon = center.longitude;
    }
    final minLon = lon - degrees;
    final maxLon = lon + degrees;
    final minLat = lat - degrees;
    final maxLat = lat + degrees;
    return [minLon, maxLat, maxLon, minLat];
  }

  Future<List<EonetEvent>> fetchWildfires({List<double>? bbox, int days = 7, int limit = 200}) async {
    final params = <String, String>{
      'category': 'wildfires',
      'status': 'open',
      'days': days.toString(),
      'limit': limit.toString(),
    };
    if (bbox != null) {
      params['bbox'] = bbox.join(',');
    }
    final uri = Uri.parse(_base).replace(queryParameters: params);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('EONET error: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final events = (data['events'] as List).where((e) {
      final cats = (e['categories'] as List);
      return cats.any((c) => (c['id'] == 8) || (c['title']?.toString().toLowerCase() == 'wildfires'));
    }).map((e) {
      final geoms = e['geometry'] as List;
      // Use latest geometry
      geoms.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
      final last = geoms.last;
      final coords = (last['coordinates'] as List);
      // GeoJSON order: [lon, lat]
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      return EonetEvent(
        id: e['id'],
        title: e['title'],
        date: DateTime.parse(last['date']).toUtc(),
        lat: lat,
        lon: lon,
      );
    }).toList();
    return events;
  }
}
