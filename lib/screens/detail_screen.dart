import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/flea_market.dart';
import '../services/storage_service.dart';

class DetailScreen extends StatefulWidget {
  final FleaMarket market;

  const DetailScreen({super.key, required this.market});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _checkFav();
  }

  Future<void> _checkFav() async {
    final fav = await StorageService.isFavorite(widget.market.id);
    if (mounted) setState(() => _isFav = fav);
  }

  Future<void> _toggleFav() async {
    final newStatus = await StorageService.toggleFavorite(widget.market.id);
    setState(() => _isFav = newStatus);

    // Cache für Favoriten-Liste
    final data = await StorageService.getFavoriteData();
    if (newStatus) {
      data.add({
        'id': widget.market.id, 'title': widget.market.title,
        'city': widget.market.city, 'plz': widget.market.plz,
        'street': widget.market.street,
        'date': widget.market.date.toIso8601String(),
        'date_end': widget.market.dateEnd?.toIso8601String(),
        'lat': widget.market.lat, 'lng': widget.market.lng,
        'category': widget.market.category,
        'organizer': widget.market.organizer,
        'description': widget.market.description,
        'entry_fee': widget.market.entryFee,
        'venue_type': widget.market.venueType,
        'source': widget.market.source,
      });
    } else {
      data.removeWhere((j) => j['id'] == widget.market.id);
    }
    await StorageService.cacheFavoriteData(
      data.map((j) => FleaMarket.fromJson(j)).toList(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newStatus ? '❤️ Zu Favoriten hinzugefügt' : 'Aus Favoriten entfernt'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.market;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: CustomScrollView(
        slivers: [
          _appBar(m),
          _heroSection(m),
          _infoCard(m),
          if (m.organizer != null && m.organizer!.isNotEmpty) _organizerCard(m),
          if (m.description != null && m.description!.isNotEmpty) _descriptionCard(m),
          _actionBar(m),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────

  Widget _appBar(FleaMarket m) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF0D1117),
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(m.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A1F2E),
                const Color(0xFF0D1117).withOpacity(0),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border,
            color: _isFav ? Colors.redAccent : Colors.white38,
          ),
          onPressed: _toggleFav,
        ),
      ],
    );
  }

  // ── Hero Section ─────────────────────────────────

  Widget _heroSection(FleaMarket m) {
    final days = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];
    final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final dateStr = '${days[m.date.weekday - 1]}, ${m.date.day}. ${months[m.date.month - 1]}';
    final now = DateTime.now();
    final diff = m.date.difference(now).inDays;

    String badgeLabel;
    Color badgeColor;
    if (diff < 0) {
      badgeLabel = 'Vergangen';
      badgeColor = Colors.grey;
    } else if (diff == 0) {
      badgeLabel = '🏃 HEUTE';
      badgeColor = Colors.redAccent;
    } else if (diff <= 2) {
      badgeLabel = '🔥 Dieses WE';
      badgeColor = Colors.orange;
    } else {
      badgeLabel = 'In $diff Tagen';
      badgeColor = Colors.blueAccent;
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(badgeLabel,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (m.entryFee)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Kostenpflichtig',
                      style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (!m.entryFee) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Eintritt frei',
                      style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _detailRow(Icons.calendar_today, dateStr),
            const SizedBox(height: 6),
            _detailRow(Icons.location_on, m.address),
            if (m.category != null) ...[
              const SizedBox(height: 6),
              _detailRow(Icons.category, m.category!),
            ],
            if (m.venueType != null) ...[
              const SizedBox(height: 6),
              _detailRow(Icons.place, m.venueType!),
            ],
          ],
        ),
      ),
    );
  }

  // ── Info Card ────────────────────────────────────

  Widget _infoCard(FleaMarket m) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                const Text('Auf einen Blick',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoGrid(m),
          ],
        ),
      ),
    );
  }

  Widget _infoGrid(FleaMarket m) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _infoTile(Icons.calendar_today, 'Datum', m.dateFormatted),
        if (m.dateEnd != null)
          _infoTile(Icons.calendar_today_outlined, 'Ende',
            '${m.dateEnd!.day}.${m.dateEnd!.month}.${m.dateEnd!.year}'),
        _infoTile(Icons.location_city, 'Stadt', '${m.plz} ${m.city}'),
        _infoTile(Icons.euro, 'Eintritt', m.entryFee ? 'Kostenpflichtig' : 'Frei'),
        if (m.venueType != null)
          _infoTile(Icons.place, 'Art', m.venueType!),
        if (m.source != null)
          _infoTile(Icons.source, 'Quelle', m.source!),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 80) / 2,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                Text(value,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Organizer ────────────────────────────────────

  Widget _organizerCard(FleaMarket m) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                const Text('Veranstalter',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(m.organizer!,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ── Description ──────────────────────────────────

  Widget _descriptionCard(FleaMarket m) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                const Text('Beschreibung',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(m.description!,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action Bar ───────────────────────────────────

  Widget _actionBar(FleaMarket m) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: _pillButton(
                icon: Icons.directions,
                label: 'Route',
                color: Colors.green,
                onTap: () async {
                  if (m.lat != null && m.lng != null) {
                    final url = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination=${m.lat},${m.lng}',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Keine Koordinaten für Routenplanung')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _pillButton(
                icon: Icons.share,
                label: 'Teilen',
                color: Colors.blue,
                onTap: () {
                  final text = '🛍️ ${m.title}\n📍 ${m.address}\n📅 ${m.dateFormatted}\n\n${m.entryFee ? "Eintritt kostenpflichtig" : "Eintritt frei"}\n\n🔗 Flohmarkt-Finder App';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('📋 Kopiert: $text'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _pillButton(
                icon: _isFav ? Icons.favorite : Icons.favorite_border,
                label: _isFav ? 'Gemerkt' : 'Merken',
                color: _isFav ? Colors.redAccent : Colors.grey,
                onTap: _toggleFav,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.amber.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
