import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  Future<List<Map<String, dynamic>>>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppState>().api.get('/products', query: {
      'per_page': 50, if (_query.isNotEmpty) 'search': _query,
    }).then((r) => (r['data'] as List).cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(hintText: 'Search product / SKU…', prefixIcon: const Icon(Icons.search), isDense: true,
                suffixIcon: _query.isNotEmpty ? IconButton(icon: const Icon(Icons.close), onPressed: () { _search.clear(); setState(() { _query = ''; _load(); }); }) : null),
              onSubmitted: (v) => setState(() { _query = v.trim(); _load(); }),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return ListView(children: [const SizedBox(height: 140), Center(child: Text(snap.error.toString()))]);
            final list = snap.data ?? [];
            if (list.isEmpty) return ListView(children: const [SizedBox(height: 160), Center(child: Text('No products.', style: TextStyle(color: Color(0xFF64748B))))]);
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = list[i];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${p['sku'] ?? ''}  ·  ${p['variants']} variants'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(cur, (p['selling_price'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('stock ${p['stock']}', style: TextStyle(fontSize: 12, color: p['low_stock'] == true ? const Color(0xFFDC2626) : const Color(0xFF64748B))),
                    ]),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p['id'] as int, name: p['name'] ?? ''))),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId, required this.name});
  final int productId;
  final String name;
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _p;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<AppState>().api.get('/products/${widget.productId}');
      _p = Map<String, dynamic>.from(r['data']);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: _loading || _p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(children: [
                  _row('SKU', _p!['sku']?.toString() ?? '—'),
                  _row('Cost', money(cur, (_p!['cost_price'] ?? 0) as num)),
                  _row('Selling', money(cur, (_p!['selling_price'] ?? 0) as num)),
                  _row('Total stock', '${_p!['total_stock']}'),
                  _row('Status', _p!['status']?.toString() ?? '—'),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Variants', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              for (final v in (_p!['variants'] as List).cast<Map<String, dynamic>>())
                Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                  title: Text('${v['sku'] ?? ''}  ${[v['color'], v['size']].where((e) => e != null).join(' ')}'),
                  trailing: Text('${money(cur, (v['price'] ?? 0) as num)}  ·  stock ${v['stock']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                )),
            ]),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: const TextStyle(color: Color(0xFF64748B))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}
