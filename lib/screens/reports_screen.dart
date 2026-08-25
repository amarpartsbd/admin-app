import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _range = 'month';
  Future<Map<String, dynamic>>? _future;

  static const _ranges = {'today': 'Today', 'week': 'This Week', 'month': 'This Month', 'year': 'This Year'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppState>().api.get('/finance/summary', query: {'range': _range}).then((d) => Map<String, dynamic>.from(d));
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Scaffold(
      appBar: AppBar(title: const Text('Reports'), actions: [
        PopupMenuButton<String>(
          initialValue: _range,
          onSelected: (v) => setState(() { _range = v; _load(); }),
          itemBuilder: (_) => _ranges.entries.map((e) => PopupMenuItem(value: e.key, child: Text(e.value))).toList(),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [Text(_ranges[_range]!), const Icon(Icons.arrow_drop_down)])),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return ListView(children: [const SizedBox(height: 140), Center(child: Text(snap.error.toString()))]);
            final s = Map<String, dynamic>.from(snap.data!['summary']);
            final rows = [
              ('Sales', s['sales'], const Color(0xFF2563EB)),
              ('Collected', s['collected'], const Color(0xFF059669)),
              ('Invoice Due', s['invoice_due'], const Color(0xFFDC2626)),
              ('Income', s['income'], const Color(0xFF0891B2)),
              ('Expense', s['expense'], const Color(0xFFEA580C)),
              ('Purchases', s['purchases'], const Color(0xFF475569)),
            ];
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('${snap.data!['from']} → ${snap.data!['to']}', style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.7,
                children: rows.map((r) => Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(money(cur, (r.$2 ?? 0) as num), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: r.$3)),
                    Text(r.$1, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ]),
                )).toList(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Net Cashflow', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(money(cur, (s['net_cashflow'] ?? 0) as num), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
