import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _range = 'today';
  Future<Map<String, dynamic>>? _future;

  static const _ranges = {'today': 'Today', 'week': 'This Week', 'month': 'This Month', 'year': 'This Year'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<AppState>().api;
    _future = api.get('/dashboard', query: {'range': _range}).then((d) => Map<String, dynamic>.from(d));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cur = state.currency;
    final brand = state.brandColor;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final kpis = snap.hasData ? Map<String, dynamic>.from(snap.data!['kpis']) : <String, dynamic>{};
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _hero(context, state, brand, cur, kpis, loading, snap.data),
                if (snap.hasError)
                  Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(snap.error.toString(), style: const TextStyle(color: kMuted))))
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    child: _grid(cur, kpis, loading),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, AppState state, Color brand, String cur, Map<String, dynamic> k, bool loading, Map<String, dynamic>? data) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 26),
      decoration: BoxDecoration(
        gradient: brandGradient(brand),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(state.company?['name']?.toString() ?? 'Dashboard',
                      style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                ]),
              ),
              _rangePill(),
            ],
          ),
          const SizedBox(height: 22),
          // Primary metric
          Text('Total Sales', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(loading ? '—' : money(cur, (k['total_sales'] ?? 0) as num),
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 18),
          Row(children: [
            _heroSub('Collected', loading ? '—' : money(cur, (k['collected'] ?? 0) as num), Icons.trending_up_rounded),
            Container(width: 1, height: 34, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 16)),
            _heroSub('Due', loading ? '—' : money(cur, (k['invoice_due'] ?? 0) as num), Icons.schedule_rounded),
            Container(width: 1, height: 34, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 16)),
            _heroSub('Orders', loading ? '—' : '${k['orders'] ?? 0}', Icons.receipt_long_rounded),
          ]),
        ],
      ),
    );
  }

  Widget _heroSub(String label, String value, IconData icon) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: Colors.white70, size: 14), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))]),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _rangePill() => Theme(
        data: Theme.of(context).copyWith(cardColor: Colors.white),
        child: PopupMenuButton<String>(
          initialValue: _range,
          onSelected: (v) => setState(() { _range = v; _load(); }),
          itemBuilder: (_) => _ranges.entries.map((e) => PopupMenuItem(value: e.key, child: Text(e.value))).toList(),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(30)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_ranges[_range]!, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
            ]),
          ),
        ),
      );

  Widget _grid(String cur, Map<String, dynamic> k, bool loading) {
    final cards = [
      _Kpi('Income', loading ? '—' : money(cur, (k['income'] ?? 0) as num), Icons.account_balance_wallet_rounded, const Color(0xFF0EA96E)),
      _Kpi('Expense', loading ? '—' : money(cur, (k['expense'] ?? 0) as num), Icons.payments_rounded, const Color(0xFFEA580C)),
      _Kpi('Purchase', loading ? '—' : money(cur, (k['total_purchase'] ?? 0) as num), Icons.shopping_bag_rounded, const Color(0xFF6366F1)),
      _Kpi('Purchase Due', loading ? '—' : money(cur, (k['purchase_due'] ?? 0) as num), Icons.request_quote_rounded, const Color(0xFFE11D48)),
      _Kpi('Sell Return', loading ? '—' : money(cur, (k['sell_return'] ?? 0) as num), Icons.assignment_return_rounded, const Color(0xFF0891B2)),
      _Kpi('Invoice Due', loading ? '—' : money(cur, (k['invoice_due'] ?? 0) as num), Icons.hourglass_bottom_rounded, const Color(0xFFCA8A04)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(left: 4, bottom: 12), child: Text('Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kInk))),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
        children: cards.map(_card).toList(),
      ),
    ]);
  }

  Widget _card(_Kpi k) => Container(
        padding: const EdgeInsets.all(16),
        decoration: softCard(radius: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: k.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(k.icon, color: k.color, size: 20),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kInk, letterSpacing: -0.3)),
            const SizedBox(height: 1),
            Text(k.label, style: const TextStyle(fontSize: 12, color: kMuted)),
          ]),
        ]),
      );
}

class _Kpi {
  _Kpi(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;
}
