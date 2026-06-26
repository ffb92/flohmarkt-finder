import 'package:flutter/material.dart';
import '../models/flea_market.dart';
import '../services/supabase_service.dart';
import 'detail_screen.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final SupabaseService _api = SupabaseService();
  List<FleaMarket> _markets = [];
  bool _loading = true;
  String? _cityFilter;

  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  Future<void> _loadMarkets({String? city}) async {
    setState(() => _loading = true);
    try {
      final result = await _api.getMarkets(city: city, limit: 200);
      setState(() {
        _markets = result['markets'] as List<FleaMarket>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alle Flohmärkte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showCitySearch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _markets.isEmpty
              ? const Center(child: Text('Keine Märkte gefunden'))
              : RefreshIndicator(
                  onRefresh: () => _loadMarkets(city: _cityFilter),
                  child: ListView.builder(
                    itemCount: _markets.length,
                    itemBuilder: (ctx, i) => _marketCard(_markets[i]),
                  ),
                ),
    );
  }

  Widget _marketCard(FleaMarket market) {
    final isToday =
        market.date.day == DateTime.now().day &&
        market.date.month == DateTime.now().month;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          isToday ? Icons.today : Icons.event,
          color: isToday ? Colors.red : Colors.blue,
        ),
        title: Text(market.title,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📍 ${market.city}'),
            Text('📅 ${market.dateFormatted}'),
          ],
        ),
        trailing: market.category != null
            ? Chip(
                label: Text(market.category!, style: const TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
              )
            : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(market: market)),
        ),
      ),
    );
  }

  void _showCitySearch() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stadt suchen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'z.B. Köln, Berlin...'),
          onSubmitted: (value) {
            Navigator.pop(ctx);
            setState(() => _cityFilter = value);
            _loadMarkets(city: value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _cityFilter = null);
              _loadMarkets();
            },
            child: const Text('Alle zeigen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _cityFilter = controller.text);
              _loadMarkets(city: controller.text);
            },
            child: const Text('Suchen'),
          ),
        ],
      ),
    );
  }
}
