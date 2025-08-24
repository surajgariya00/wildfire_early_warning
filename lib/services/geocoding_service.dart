import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final String displayName;
  final double lat;
  final double lon;

  GeocodingResult({required this.displayName, required this.lat, required this.lon});
}

class GeocodingService {
  static const _endpoint = 'https://nominatim.openstreetmap.org/search';

  Future<List<GeocodingResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '0',
      'limit': '5',
    });
    final res = await http.get(uri, headers: {
      'User-Agent': 'WildfireEarlyWarning/1.0 (educational, contact: example@example.com)'
    });
    if (res.statusCode != 200) return [];
    final List data = jsonDecode(res.body) as List;
    return data.map((e) => GeocodingResult(
      displayName: e['display_name'],
      lat: double.parse(e['lat']),
      lon: double.parse(e['lon']),
    )).toList();
  }
}
