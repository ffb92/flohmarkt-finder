import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/flea_market.dart';

/// API-Service für Supabase (REST API – kein SDK nötig)
///
/// Vorteil gegenüber supabase_flutter SDK:
/// - Kein zusätzliches Package nötig
/// - Funktioniert sofort, nur URL + Anon Key nötig
class SupabaseService {
  // Nach Projekt-Erstellung ersetzen:
  static const String _url = 'https://bwdesgbbwajmruiabbml.supabase.co';
  static const String _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3ZGVzZ2Jid2FqbXJ1aWFiYm1sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2NDI4NjEsImV4cCI6MjA5NjIxODg2MX0.lRBUxqGS2IiSgMs1lq40JO2OL2l-5rWxN_ncbVbEnr0';

  static Map<String, String> get _headers => {
    'apikey': _anonKey,
    'Authorization': 'Bearer $_anonKey',
    'Content-Type': 'application/json',
  };

  /// Alle Märkte mit Filtern (PostGIS-Umkreissuche serverseitig)
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
    // PostGIS-Umkreissuche via RPC
    if (lat != null && lng != null) {
      final Map<String, dynamic> body = {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_km': radius,
        'p_limit': limit,
      };
      if (category != null) body['p_category'] = category;
      if (dateFrom != null) body['p_date_from'] = dateFrom;

      final resp = await http.post(
        Uri.parse('$_url/rest/v1/rpc/nearby_markets'),
        headers: _headers,
        body: json.encode(body),
      );
      if (resp.statusCode == 200) {
        final markets = (json.decode(resp.body) as List)
            .map((m) => FleaMarket.fromJson(m))
            .toList();
        return {'markets': markets, 'total': markets.length, 'page': 1, 'pages': 1};
      }
    }

    // Fallback: einfache Query mit Filtern
    final params = <String, String>{
      'select': '*',
      'order': 'date.asc',
      'limit': limit.toString(),
      'offset': ((page - 1) * limit).toString(),
    };
    if (dateFrom != null) params['date'] = 'gte.$dateFrom';
    if (dateTo != null) params['date'] = 'lte.$dateTo';
    if (category != null) params['category'] = 'eq.$category';
    if (city != null) params['city'] = 'ilike.*$city*';

    final uri = Uri.parse('$_url/rest/v1/flea_markets')
        .replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);

    if (resp.statusCode == 200) {
      final markets = (json.decode(resp.body) as List)
          .map((m) => FleaMarket.fromJson(m))
          .toList();
      // Count query
      final countUri = Uri.parse('$_url/rest/v1/flea_markets')
          .replace(queryParameters: {'select': 'count', ...params}..remove('select'));
      final countResp = await http.get(countUri, headers: {'apikey': _anonKey, 'Authorization': 'Bearer $_anonKey', 'Prefer': 'count=exact'});
      final total = countResp.headers['content-range'] != null
          ? int.parse(countResp.headers['content-range']!.split('/').last)
          : markets.length;

      return {'markets': markets, 'total': total, 'page': page, 'pages': (total / limit).ceil()};
    }
    throw Exception('Supabase error: ${resp.statusCode} ${resp.body}');
  }

  /// Alle Märkte für die Karte (nur mit Koordinaten)
  Future<List<FleaMarket>> getMarketsForMap({String? dateFrom}) async {
    final params = <String, String>{
      'select': 'id,title,lat,lng,date,city,plz,street,category,date_end',
      'lat': 'not.is.null',
      'order': 'date.asc',
      'limit': '500',
    };
    if (dateFrom != null) params['date'] = 'gte.$dateFrom';
    final uri = Uri.parse('$_url/rest/v1/flea_markets')
        .replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);

    if (resp.statusCode == 200) {
      return (json.decode(resp.body) as List)
          .map((m) => FleaMarket.fromJson(m))
          .toList();
    }
    throw Exception('Supabase error: ${resp.statusCode}');
  }

  /// Flohmärkte dieses Wochenende (Sa + So)
  Future<List<FleaMarket>> getThisWeekend() async {
    final now = DateTime.now();
    // Nächsten Samstag finden
    final daysUntilSat = (6 - now.weekday) % 7;
    final sat = DateTime(now.year, now.month, now.day + daysUntilSat);
    final sun = sat.add(const Duration(days: 1));
    final satStr = '${sat.year}-${sat.month.toString().padLeft(2, '0')}-${sat.day.toString().padLeft(2, '0')}';
    final sunStr = '${sun.year}-${sun.month.toString().padLeft(2, '0')}-${sun.day.toString().padLeft(2, '0')}';

    // Supabase or-filter: date between sat and sun
    final params = {
      'select': '*',
      'or': '(date.gte.$satStr,date.lte.$sunStr)',
      'order': 'date.asc',
      'limit': '100',
    };
    final uri = Uri.parse('$_url/rest/v1/flea_markets')
        .replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);

    if (resp.statusCode == 200) {
      return (json.decode(resp.body) as List)
          .map((m) => FleaMarket.fromJson(m))
          .toList();
    }
    // Fallback: alle zukünftigen (wenn or-Filter Probleme macht)
    final fallback = await getMarketsForMap(dateFrom: satStr);
    return fallback.where((m) =>
      m.date.isAfter(sat.subtract(const Duration(days: 1))) &&
      m.date.isBefore(sun.add(const Duration(days: 1)))
    ).toList();
  }

  /// Märkte für heute
  Future<List<FleaMarket>> getToday() async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final params = {
      'select': '*',
      'date': 'eq.$todayStr',
      'order': 'city.asc',
      'limit': '50',
    };
    final uri = Uri.parse('$_url/rest/v1/flea_markets')
        .replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);

    if (resp.statusCode == 200) {
      return (json.decode(resp.body) as List)
          .map((m) => FleaMarket.fromJson(m))
          .toList();
    }
    return [];
  }

  /// Count upcoming markets
  Future<int> getUpcomingCount() async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final resp = await http.get(
        Uri.parse('$_url/rest/v1/flea_markets?select=count&date=gte.$todayStr'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Prefer': 'count=exact',
        },
      );
      if (resp.statusCode == 200 || resp.statusCode == 206) {
        final range = resp.headers['content-range'];
        if (range != null) {
          return int.parse(range.split('/').last);
        }
      }
    } catch (_) {}
    return 290; // fallback
  }

  /// Einzelnen Markt
  Future<FleaMarket> getMarket(int id) async {
    final resp = await http.get(
      Uri.parse('$_url/rest/v1/flea_markets?id=eq.$id&select=*'),
      headers: _headers,
    );
    if (resp.statusCode == 200) {
      final list = json.decode(resp.body) as List;
      if (list.isNotEmpty) return FleaMarket.fromJson(list[0]);
    }
    throw Exception('Not found');
  }
}
