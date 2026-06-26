import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flea_market.dart';

/// Lokale Persistenz: Favoriten, letzte Suche, Einstellungen
class StorageService {
  static const _favKey = 'favorites';

  // ── Favoriten ──────────────────────────────────────

  /// Alle gespeicherten Favoriten-IDs
  static Future<Set<int>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favKey) ?? [];
    return raw.map((s) => int.parse(s)).toSet();
  }

  /// Einzelnen Markt favorisieren / entfernen → liefert neuen Status
  static Future<bool> toggleFavorite(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favKey) ?? [];
    final ids = raw.map((s) => int.parse(s)).toSet();

    final isNowFav = !ids.contains(id);
    if (isNowFav) {
      ids.add(id);
    } else {
      ids.remove(id);
    }

    await prefs.setStringList(_favKey, ids.map((i) => i.toString()).toList());
    return isNowFav;
  }

  /// Prüfen ob ein Markt favorisiert ist
  static Future<bool> isFavorite(int id) async {
    final ids = await getFavoriteIds();
    return ids.contains(id);
  }

  /// Favoriten als JSON serialisieren (für Backup / Übergabe an andere Screens)
  static Future<List<Map<String, dynamic>>> getFavoriteData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('favorites_data') ?? '[]';
    return (json.decode(raw) as List).cast<Map<String, dynamic>>();
  }

  static Future<void> cacheFavoriteData(List<FleaMarket> markets) async {
    final prefs = await SharedPreferences.getInstance();
    final data = markets.map((m) => {
      'id': m.id,
      'title': m.title,
      'city': m.city,
      'plz': m.plz,
      'street': m.street,
      'date': m.date.toIso8601String(),
      'date_end': m.dateEnd?.toIso8601String(),
      'lat': m.lat,
      'lng': m.lng,
      'category': m.category,
      'organizer': m.organizer,
      'description': m.description,
      'entry_fee': m.entryFee,
      'venue_type': m.venueType,
      'source': m.source,
    }).toList();
    await prefs.setString('favorites_data', json.encode(data));
  }

  // ── Letzte Suche ───────────────────────────────────

  static Future<String?> getLastCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_city');
  }

  static Future<void> setLastCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_city', city);
  }
}
