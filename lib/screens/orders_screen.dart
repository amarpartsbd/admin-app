import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'order_detail_screen.dart';
import 'create_order_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final List<Map<String, dynamic>> _orders = [];
  int _page = 1, _lastPage = 1;
  bool _loading = false;
  String _scope = 'all';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _reload();
  }

  Future<void> _reload() async {
    setState(() { _orders.clear(); _page = 1; _lastPage = 1; });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _page > _lastPage) return;
    setState(() => _loading = true);
    try {
      final res = await context.read<AppState>().api.get('/orders', query: {
        'page': _page,
        'per_page': 20,
        'scope': _scope,
        if (_query.isNotEmpty) 'search': _query,
      });
      final data = (res['data'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _orders.addAll(data);
        _lastPage = res['meta']['last_page'] ?? 1;
        _page += 1;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cur = state.currency;
    return Scaffold(
      floatingActionButton: (state.can('orders.create') || state.can('b2b.manage'))
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CreateOrderScreen(),
              )).then((created) { if (created == true) _reload(); }),
              icon: const Icon(Icons.add),
              label: const Text('New Order'),
            )
          : null,
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search order, name, phone…',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.close), onPressed: () { _search.clear(); _query = ''; _reload(); })
                      : null,
                ),
                onSubmitted: (v) { _query = v.trim(); _reload(); },
              ),
              const SizedBox(height: 8),
              Row(children: [
                _chip('All', 'all'),
                const SizedBox(width: 8),
                _chip('Retail', 'retail'),
                const SizedBox(width: 8),
                _chip('B2B', 'b2b'),
              ]),
            ]),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: _orders.isEmpty && !_loading
            ? ListView(children: const [SizedBox(height: 160), Center(child: Text('No orders found.', style: TextStyle(color: Color(0xFF64748B))))])
            : ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: _orders.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == _orders.length) {
                    return _page <= _lastPage
                        ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                        : const SizedBox.shrink();
                  }
                  return _tile(_orders[i], cur);
                },
              ),
      ),
    );
  }

  Widget _chip(String label, String value) => ChoiceChip(
        label: Text(label),
        selected: _scope == value,
        onSelected: (_) { setState(() => _scope = value); _reload(); },
      );

  Widget _tile(Map<String, dynamic> o, String cur) {
    final due = (o['due'] ?? 0) as num;
    final party = (o['party_name'] ?? 'Customer').toString();
    final sc = statusColor((o['status'] ?? '').toString());
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: o['id'] as int),
        )).then((_) => _reload()),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: softCard(radius: 16),
          child: Row(children: [
            Container(
              height: 44, width: 44,
              decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(party.substring(0, 1).toUpperCase(), style: TextStyle(color: sc, fontWeight: FontWeight.w800, fontSize: 17)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(o['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kInk)),
                if (o['is_b2b'] == true) ...[
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(5)), child: const Text('B2B', style: TextStyle(fontSize: 9.5, color: Color(0xFF6D28D9), fontWeight: FontWeight.w800))),
                ],
              ]),
              const SizedBox(height: 2),
              Text(party, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: kMuted)),
              const SizedBox(height: 6),
              _statusPill(o['status_label'] ?? '', sc),
            ])),
            const SizedBox(width: 8),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(cur, (o['total'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kInk)),
              if (due > 0) ...[
                const SizedBox(height: 2),
                Text('Due ${money(cur, due)}', style: const TextStyle(fontSize: 11.5, color: kDanger, fontWeight: FontWeight.w600)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      );
}
