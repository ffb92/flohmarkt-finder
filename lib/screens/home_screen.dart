import 'package:flutter/material.dart';
import '../models/flea_market.dart';
import '../services/supabase_service.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToFavorites;

  const HomeScreen({super.key, this.onNavigateToMap, this.onNavigateToFavorites});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _api = SupabaseService();

  List<FleaMarket> _weekend = [];
  List<FleaMarket> _today = [];
  int _upcomingCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getThisWeekend(),
        _api.getToday(),
        _api.getUpcomingCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _weekend = results[0] as List<FleaMarket>;
        _today = results[1] as List<FleaMarket>;
        _upcomingCount = results[2] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : _error != null
                ? _errorView()
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    color: Colors.amber,
                    child: CustomScrollView(
                      slivers: [
                        _appBar(),
                        _heroCard(),
                        _sectionHeader('Heute unterwegs?', '${_today.length} Märkte'),
                        _today.isNotEmpty
                            ? _todaySlider()
                            : _emptyToday(),
                        _sectionHeader('Anstehende Märkte', '$_upcomingCount insgesamt'),
                        _categoryChips(),
                        _weekendList(),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────

  Widget _appBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.store, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Flohmarkt-Finder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text('Deutschlands Flohmärkte auf einen Blick',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero Card ────────────────────────────────────

  Widget _heroCard() {
    final days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final now = DateTime.now();
    final daysUntilSat = (6 - now.weekday) % 7;
    final sat = now.add(Duration(days: daysUntilSat));
    final dateStr = '${days[sat.weekday - 1]}, ${sat.day}. ${months[sat.month - 1]}';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: GestureDetector(
          onTap: widget.onNavigateToMap,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1F2E), Color(0xFF232D3F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('🔥 HEISSE TIPPS',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward, color: Colors.amber, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Am Wochenende\nist wieder Trödeltag!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(dateStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('$_upcomingCount Märkte',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section Header ───────────────────────────────

  Widget _sectionHeader(String title, String subtitle) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(
          children: [
            Text(title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(subtitle,
                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Today Slider ─────────────────────────────────

  Widget _todaySlider() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _today.length,
          itemBuilder: (ctx, i) => _horizontalCard(_today[i]),
        ),
      ),
    );
  }

  Widget _horizontalCard(FleaMarket m) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context, MaterialPageRoute(builder: (_) => DetailScreen(market: m)),
      ),
      child: Container(
        width: 200,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon-Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.today, color: Colors.redAccent, size: 18),
                ),
                const Spacer(),
                if (m.entryFee)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('€',
                      style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(m.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(m.city,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyToday() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text('🏖️  Heute kein Trödel — aber am Wochenende!',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }

  // ── Category Chips ───────────────────────────────

  Widget _categoryChips() {
    final cats = ['Flohmarkt', 'Trödelmarkt', 'Kinderflohmarkt', 'Nachtflohmarkt', 'Antikmarkt'];
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) => GestureDetector(
            onTap: () {
              // TODO: Filter by category
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Filter: ${cats[i]} (kommt bald!)'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Text(cats[i],
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Weekend List ─────────────────────────────────

  Widget _weekendList() {
    if (_weekend.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text('⏳ Lade Wochenend-Märkte...',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Gruppiere nach Tag
    final Map<String, List<FleaMarket>> grouped = {};
    for (final m in _weekend) {
      final key = '${m.date.year}-${m.date.month}-${m.date.day}';
      grouped.putIfAbsent(key, () => []).add(m);
    }

    final days = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];
    final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];

    final items = <Widget>[];
    for (final entry in grouped.entries) {
      final d = entry.value.first.date;
      final label = '${days[d.weekday - 1]}, ${d.day}. ${months[d.month - 1]}';
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(label,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
      for (final m in entry.value) {
        items.add(_listTile(m));
      }
    }

    return SliverList(delegate: SliverChildListDelegate(items));
  }

  Widget _listTile(FleaMarket m) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context, MaterialPageRoute(builder: (_) => DetailScreen(market: m)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
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
                color: m.entryFee
                    ? Colors.amber.withOpacity(0.12)
                    : Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                m.entryFee ? Icons.euro : Icons.money_off,
                color: m.entryFee ? Colors.amber : Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 11, color: Colors.grey),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(m.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (m.category != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(m.category!,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Error ────────────────────────────────────────

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Keine Verbindung', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
    );
  }
}
