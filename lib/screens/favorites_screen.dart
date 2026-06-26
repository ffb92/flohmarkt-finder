import 'package:flutter/material.dart';
import '../models/flea_market.dart';
import '../services/storage_service.dart';
import 'detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FleaMarket> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    final data = await StorageService.getFavoriteData();
    if (!mounted) return;
    setState(() {
      _favorites = data.map((j) => FleaMarket.fromJson(j)).toList();
      _loading = false;
    });
  }

  Future<void> _removeFavorite(FleaMarket market) async {
    await StorageService.toggleFavorite(market.id);

    // Aus Cache entfernen
    setState(() => _favorites.removeWhere((m) => m.id == market.id));
    await StorageService.cacheFavoriteData(_favorites);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${market.title} entfernt'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () async {
            await StorageService.toggleFavorite(market.id);
            await _loadFavorites();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : _favorites.isEmpty
                ? _emptyState()
                : CustomScrollView(
                    slivers: [
                      _header(),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _favoriteCard(_favorites[i]),
                          childCount: _favorites.length,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
      ),
    );
  }

  Widget _header() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.redAccent, size: 24),
                ),
                const SizedBox(width: 12),
                const Text('Deine Favoriten',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${_favorites.length} Märkte gespeichert',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favoriteCard(FleaMarket m) {
    final days = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];
    final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final dateStr = '${days[m.date.weekday - 1]}, ${m.date.day}. ${months[m.date.month - 1]}';

    return Dismissible(
      key: Key('fav_${m.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.withOpacity(0.3),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) => _removeFavorite(m),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(market: m)),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${m.city}  •  ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const Icon(Icons.calendar_today, size: 11, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border, size: 64, color: Colors.white24),
          ),
          const SizedBox(height: 24),
          const Text('Noch keine Favoriten',
            style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('Tippe auf das Herz bei einem Markt,\num ihn hier zu speichern.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
