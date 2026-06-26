import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/flea_market.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import 'detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final SupabaseService _api = SupabaseService();
  final MapController _mapController = MapController();

  List<FleaMarket> _allMarkets = [];
  List<FleaMarket> _visibleMarkets = [];
  Set<int> _favoriteIds = {};
  bool _loading = true;
  String? _error;

  // Filter
  String? _activeFilter; // null = alle, 'today', 'weekend', 'future'
  LatLngBounds? _currentBounds;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getMarketsForMap(),
        StorageService.getFavoriteIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _allMarkets = results[0] as List<FleaMarket>;
        _favoriteIds = results[1] as Set<int>;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Filter-Logik ─────────────────────────────────

  void _setFilter(String? filter) {
    setState(() => _activeFilter = _activeFilter == filter ? null : filter);
    _applyFilters();
  }

  void _applyFilters() {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final weekendEnd = _nextSundayEnd();

    var filtered = _allMarkets.toList();

    if (_activeFilter == 'today') {
      filtered = filtered.where((m) =>
        m.date.isBefore(todayEnd.add(const Duration(days: 1))) &&
        m.date.isAfter(now.subtract(const Duration(hours: 6)))
      ).toList();
    } else if (_activeFilter == 'weekend') {
      filtered = filtered.where((m) =>
        m.date.isAfter(now) && m.date.isBefore(weekendEnd)
      ).toList();
    } else if (_activeFilter == 'future') {
      filtered = filtered.where((m) => m.date.isAfter(now)).toList();
    }

    // Bounds-Filter (nur was im sichtbaren Kartenausschnitt liegt)
    if (_currentBounds != null) {
      filtered = filtered.where((m) {
        if (m.lat == null || m.lng == null) return false;
        return _currentBounds!.contains(LatLng(m.lat!, m.lng!));
      }).toList();
    }

    // Max 100 Marker auf einmal (Performance)
    if (filtered.length > 100) {
      // Behalte die nächsten (nach Datum sortiert)
      filtered.sort((a, b) => a.date.compareTo(b.date));
      filtered = filtered.take(100).toList();
    }

    setState(() => _visibleMarkets = filtered);
  }

  DateTime _nextSundayEnd() {
    final now = DateTime.now();
    final daysUntilSun = (7 - now.weekday) % 7;
    final sun = DateTime(now.year, now.month, now.day + daysUntilSun);
    return DateTime(sun.year, sun.month, sun.day, 23, 59, 59);
  }

  // ── Marker-Farbe (nach Zeit & Favorit) ──────────

  Color _markerColor(FleaMarket m) {
    final now = DateTime.now();
    final diff = m.date.difference(now).inDays;
    final isFav = _favoriteIds.contains(m.id);

    if (isFav) return Colors.redAccent;
    if (diff <= 0) return const Color(0xFFFF4444);    // Heute → Rot
    if (diff <= 2) return const Color(0xFFFF8F00);    // Dieses WE → Orange
    if (diff <= 7) return const Color(0xFF448AFF);    // Nächste Woche → Blau
    return const Color(0xFF78909C);                     // Später → Grau
  }

  double _markerSize(FleaMarket m) {
    final now = DateTime.now();
    final diff = m.date.difference(now).inDays;
    return diff <= 1 ? 42.0 : 34.0; // Heute/Morgen etwas größer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('⚠️ $_error', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadAll,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Erneut versuchen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      // ── Karte ──────────────────
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(51.1657, 10.4515),
                          initialZoom: 6.0,
                          minZoom: 5.0,
                          maxZoom: 17.0,
                          onMapEvent: (evt) {
                            if (evt is MapEventMoveEnd || evt is MapEventFlingAnimationEnd) {
                              final bounds = _mapController.camera.visibleBounds;
                              if (_currentBounds != bounds) {
                                _currentBounds = bounds;
                                _applyFilters();
                              }
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'de.flohmarkt.app',
                          ),
                          MarkerLayer(
                            markers: _visibleMarkets.map((m) {
                              final size = _markerSize(m);
                              return Marker(
                                point: LatLng(m.lat!, m.lng!),
                                width: size + 8,
                                height: size + 8,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _showPreview(m),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _favoriteIds.contains(m.id)
                                            ? Icons.favorite
                                            : Icons.location_on,
                                        color: _markerColor(m),
                                        size: size,
                                        shadows: const [
                                          Shadow(color: Colors.black54, blurRadius: 4),
                                        ],
                                      ),
                                      // Nur Label bei heutigen/Favoriten
                                      if (_markerSize(m) > 36)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _favoriteIds.contains(m.id) ? '♥' : m.city,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      // ── Filter-Pills oben ──────
                      Positioned(
                        top: 8, left: 0, right: 0,
                        child: _filterBar(),
                      ),

                      // ── Karten-Legende unten ───
                      Positioned(
                        bottom: 80, right: 12,
                        child: _legend(),
                      ),

                      // ── Info-Badge ─────────────
                      Positioned(
                        top: 62, left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xEE161B22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Text(
                            '${_visibleMarkets.length} Märkte sichtbar',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'location',
            onPressed: _loadAll,
            backgroundColor: const Color(0xFF161B22),
            child: const Icon(Icons.refresh, color: Colors.amber),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'list',
            onPressed: () {
              _mapController.move(
                const LatLng(51.1657, 10.4515), 6.0,
              );
            },
            backgroundColor: const Color(0xFF161B22),
            child: const Icon(Icons.center_focus_strong, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ──────────────────────────────────

  Widget _filterBar() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xEE0D1117),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filterPill('Heute', 'today', Icons.today, Colors.redAccent),
            const SizedBox(width: 6),
            _filterPill('Dieses WE', 'weekend', Icons.event, Colors.orange),
            const SizedBox(width: 6),
            _filterPill('Alle', null, Icons.public, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _filterPill(String label, String? filter, IconData icon, Color color) {
    final active = _activeFilter == filter;
    return GestureDetector(
      onTap: () => _setFilter(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? color : Colors.white54),
            const SizedBox(width: 5),
            Text(label,
              style: TextStyle(
                color: active ? color : Colors.white70,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Legende ─────────────────────────────────────

  Widget _legend() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xEE0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendItem(Colors.redAccent, 'Heute'),
          const SizedBox(height: 3),
          _legendItem(const Color(0xFFFF8F00), 'Dieses WE'),
          const SizedBox(height: 3),
          _legendItem(const Color(0xFF448AFF), 'Demnächst'),
          const SizedBox(height: 3),
          _legendItem(Colors.red, '★ Favorit'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  // ── Bottom Sheet (Marker-Tap) ───────────────────

  void _showPreview(FleaMarket market) {
    final days = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];
    final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final dateStr = '${days[market.date.weekday - 1]}, ${market.date.day}. ${months[market.date.month - 1]}';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title + Fav
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(market.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final newStatus = await StorageService.toggleFavorite(market.id);
                      setModalState(() {
                        if (newStatus) {
                          _favoriteIds.add(market.id);
                        } else {
                          _favoriteIds.remove(market.id);
                        }
                      });
                      // Cache aktualisieren
                      if (newStatus) {
                        final existing = await StorageService.getFavoriteData();
                        existing.add({
                          'id': market.id, 'title': market.title,
                          'city': market.city, 'plz': market.plz,
                          'street': market.street,
                          'date': market.date.toIso8601String(),
                          'date_end': market.dateEnd?.toIso8601String(),
                          'lat': market.lat, 'lng': market.lng,
                          'category': market.category,
                          'organizer': market.organizer,
                          'description': market.description,
                          'entry_fee': market.entryFee,
                          'venue_type': market.venueType,
                          'source': market.source,
                        });
                        await StorageService.cacheFavoriteData(
                          existing.map((j) => FleaMarket.fromJson(j)).toList(),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (_favoriteIds.contains(market.id)
                            ? Colors.red : Colors.white)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _favoriteIds.contains(market.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _favoriteIds.contains(market.id)
                            ? Colors.redAccent
                            : Colors.white38,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Info rows
              _previewRow(Icons.location_on, market.address),
              _previewRow(Icons.calendar_today, dateStr),
              if (market.category != null)
                _previewRow(Icons.category, market.category!),
              _previewRow(
                market.entryFee ? Icons.euro : Icons.money_off,
                market.entryFee ? 'Eintritt kostenpflichtig' : 'Eintritt frei',
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(market: market),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (market.lat != null && market.lng != null) {
                          final url = Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&destination=${market.lat},${market.lng}',
                          );
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Route'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
