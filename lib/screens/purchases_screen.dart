import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppState>().api.get('/purchases', query: {'per_page': 50})
        .then((r) => (r['data'] as List).cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Scaffold(
      appBar: AppBar(title: const Text('Purchases')),
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return ListView(children: [const SizedBox(height: 140), Center(child: Text(snap.error.toString()))]);
            final list = snap.data ?? [];
            if (list.isEmpty) return ListView(children: const [SizedBox(height: 160), Center(child: Text('No purchases.', style: TextStyle(color: Color(0xFF64748B))))]);
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = list[i];
                final due = (p['due'] ?? 0) as num;
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(p['purchase_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${p['vendor'] ?? ''}  ·  ${p['status'] ?? ''}  ·  ${p['date'] ?? ''}'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(cur, (p['total'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (due > 0) Text('Due ${money(cur, due)}', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                    ]),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PurchaseDetailScreen(id: p['id'] as int, number: p['purchase_number'] ?? ''))).then((_) => setState(_load)),
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

class PurchaseDetailScreen extends StatefulWidget {
  const PurchaseDetailScreen({super.key, required this.id, required this.number});
  final int id;
  final String number;
  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  Map<String, dynamic>? _p;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await context.read<AppState>().api.get('/purchases/${widget.id}');
      _p = Map<String, dynamic>.from(r['data']);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay(double due) async {
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (_) => _VendorPaySheet(purchaseId: widget.id, due: due));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cur = state.currency;
    final f = _p?['financials'] as Map<String, dynamic>?;
    final due = (f?['due'] ?? 0) as num;
    return Scaffold(
      appBar: AppBar(title: Text(widget.number)),
      body: _loading || _p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(children: [
                  _row('Vendor', _p!['vendor']?.toString() ?? '—'),
                  _row('Date', _p!['date']?.toString() ?? '—'),
                  _row('Status', _p!['status']?.toString() ?? '—'),
                  const Divider(),
                  _row('Total', money(cur, (f?['total'] ?? 0) as num), bold: true),
                  _row('Paid', money(cur, (f?['paid'] ?? 0) as num), color: const Color(0xFF059669)),
                  _row('Due', money(cur, due), color: const Color(0xFFDC2626), bold: true),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              for (final it in (_p!['items'] as List).cast<Map<String, dynamic>>())
                Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                  dense: true,
                  title: Text(it['product_name']?.toString() ?? '—'),
                  subtitle: Text('${it['quantity']} × ${money(cur, (it['unit_cost'] ?? 0) as num)}'),
                  trailing: Text(money(cur, (it['line_total'] ?? 0) as num)),
                )),
              if (due > 0 && state.can('purchases.manage')) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                  onPressed: () => _pay(due.toDouble()),
                  icon: const Icon(Icons.payments),
                  label: Text('Pay Vendor · Due ${money(cur, due)}'),
                ),
              ],
            ]),
    );
  }

  Widget _row(String l, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: const TextStyle(color: Color(0xFF64748B))),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: color ?? const Color(0xFF0F172A))),
        ]),
      );
}

class _VendorPaySheet extends StatefulWidget {
  const _VendorPaySheet({required this.purchaseId, required this.due});
  final int purchaseId;
  final double due;
  @override
  State<_VendorPaySheet> createState() => _VendorPaySheetState();
}

class _VendorPaySheetState extends State<_VendorPaySheet> {
  late final TextEditingController _amount = TextEditingController(text: widget.due.toStringAsFixed(0));
  final _ref = TextEditingController();
  String _method = 'cash';
  bool _saving = false;
  String? _error;

  static const _methods = {'cash': 'Cash', 'bkash': 'bKash', 'nagad': 'Nagad', 'bank_transfer': 'Bank Transfer', 'cheque': 'Cheque'};

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) { setState(() => _error = 'Enter a valid amount.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final res = await context.read<AppState>().api.post('/purchases/${widget.purchaseId}/payment', body: {
        'amount': amt, 'method': _method, if (_ref.text.trim().isNotEmpty) 'reference': _ref.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Payment recorded.')));
      }
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Pay Vendor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Method'),
            items: _methods.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _method = v ?? 'cash'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Reference (optional)')),
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))],
          const SizedBox(height: 16),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)), onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Record Payment')),
        ]),
      ),
    );
  }
}
