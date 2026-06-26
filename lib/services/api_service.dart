import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/flea_market.dart';

class ApiService {
  // Für Entwicklung: localhost, für Produktion: deine Domain
  static const String baseUrl = 'http://10.0.2.2:8000/api'; // Android Emulator
  // Ersetze mit deiner echten URL für Play Store Build

  /// Alle Märkte mit Filtern
  Future<Map<String, dynamic>> getMarkets({
    double? lat,
    double? lng,
    double radius = 20,
    String? dateFrom,
    String? dateTo,
    String? category,
    String? city,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (lat != null) params['lat'] = lat.toString();
    if (lng != null) params['lng'] = lng.toString();
    if (radius != 20) params['radius'] = radius.toString();
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (category != null) params['category'] = category;
    if (city != null) params['city'] = city;

    final uri = Uri.parse('$baseUrl/markets').replace(queryParameters: params);
    final resp = await http.get(uri);

    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return {
        'markets': (data['markets'] as List)
            .map((m) => FleaMarket.fromJson(m))
            .toList(),
        'total': data['total'] ?? 0,
        'page': data['page'] ?? 1,
        'pages': data['pages'] ?? 1,
      };
    }
    throw Exception('API error: ${resp.statusCode}');
  }

  /// Alle Märkte für die Karte
  Future<List<FleaMarket>> getMarketsForMap({
    String? dateFrom,
    String? dateTo,
    String? category,
  }) async {
    final params = <String, String>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (category != null) params['category'] = category;

    final uri = Uri.parse('$baseUrl/markets/map')
        .replace(queryParameters: params);
    final resp = await http.get(uri);

    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return (data['markets'] as List)
          .map((m) => FleaMarket.fromJson(m))
          .toList();
    }
    throw Exception('API error: ${resp.statusCode}');
  }

  /// Einzelnen Markt abrufen
  Future<FleaMarket> getMarket(int id) async {
    final resp = await http.get(Uri.parse('$baseUrl/markets/$id'));
    if (resp.statusCode == 200) {
      return FleaMarket.fromJson(json.decode(resp.body));
    }
    throw Exception('API error: ${resp.statusCode}');
  }

  /// Kategorien mit Anzahl
  Future<List<Map<String, dynamic>>> getCategories() async {
    final resp = await http.get(Uri.parse('$baseUrl/categories'));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return List<Map<String, dynamic>>.from(data['categories'] ?? []);
    }
    throw Exception('API error: ${resp.statusCode}');
  }

  /// Städte-Suche
  Future<List<Map<String, dynamic>>> searchCities(String query) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/cities').replace(queryParameters: {'q': query}),
    );
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      return List<Map<String, dynamic>>.from(data['cities'] ?? []);
    }
    return [];
  }
}
