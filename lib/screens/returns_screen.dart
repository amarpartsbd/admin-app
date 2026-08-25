import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  static const _statusColor = {
    'requested': Color(0xFFEA580C), 'approved': Color(0xFF2563EB),
    'completed': Color(0xFF059669), 'rejected': Color(0xFFDC2626),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppState>().api.get('/returns', query: {'per_page': 50})
        .then((r) => (r['data'] as List).cast<Map<String, dynamic>>());
  }

  Future<void> _create() async {
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, builder: (_) => const _NewReturnSheet());
    if (ok == true) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Scaffold(
      appBar: AppBar(title: const Text('Returns')),
      floatingActionButton: context.read<AppState>().can('returns.manage')
          ? FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('New Return'))
          : null,
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return ListView(children: [const SizedBox(height: 140), Center(child: Text(snap.error.toString()))]);
            final list = snap.data ?? [];
            if (list.isEmpty) return ListView(children: const [SizedBox(height: 160), Center(child: Text('No returns.', style: TextStyle(color: Color(0xFF64748B))))]);
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = list[i];
                final st = (r['status'] ?? '').toString();
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Row(children: [
                      Text(r['order_number'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: (_statusColor[st] ?? Colors.grey).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Text(st, style: TextStyle(fontSize: 11, color: _statusColor[st] ?? Colors.grey, fontWeight: FontWeight.w700))),
                    ]),
                    subtitle: Text('${r['reason'] ?? ''}  ·  qty ${r['quantity']}  ·  ${r['date'] ?? ''}'),
                    trailing: (r['refund_amount'] ?? 0) > 0 ? Text(money(cur, (r['refund_amount']) as num), style: const TextStyle(fontWeight: FontWeight.w700)) : null,
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

class _NewReturnSheet extends StatefulWidget {
  const _NewReturnSheet();
  @override
  State<_NewReturnSheet> createState() => _NewReturnSheetState();
}

class _NewReturnSheetState extends State<_NewReturnSheet> {
  final _orderId = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _reason = TextEditingController();
  final _refund = TextEditingController(text: '0');
  bool _restock = true;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_orderId.text.trim().isEmpty || _reason.text.trim().isEmpty) {
      setState(() => _error = 'Order ID and reason are required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await context.read<AppState>().api.post('/returns', body: {
        'order_id': int.tryParse(_orderId.text.trim()),
        'quantity': double.tryParse(_qty.text.trim()) ?? 1,
        'reason': _reason.text.trim(),
        'refund_amount': double.tryParse(_refund.text.trim()) ?? 0,
        'restock': _restock,
      });
      if (mounted) Navigator.pop(context, true);
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
          const Text('New Return', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Enter the order ID (from the order detail).', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          TextField(controller: _orderId, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Order ID')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _refund, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Refund amount'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Restock item'), value: _restock, onChanged: (v) => setState(() => _restock = v)),
          if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
          const SizedBox(height: 12),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Create Return')),
        ]),
      ),
    );
  }
}
