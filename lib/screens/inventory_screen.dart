import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _search = TextEditingController();
  Future<List<Map<String, dynamic>>>? _future;
  String _query = '';
  bool _lowOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppState>().api.get('/inventory', query: {
      'per_page': 50,
      if (_query.isNotEmpty) 'search': _query,
      if (_lowOnly) 'low_stock': 1,
    }).then((r) => (r['data'] as List).cast<Map<String, dynamic>>());
  }

  Future<void> _adjust(Map<String, dynamic> row) async {
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (_) => _AdjustSheet(variantId: row['variant_id'] as int, name: '${row['product_name']} ${row['variant']}', current: (row['stock'] ?? 0) as num));
    if (ok == true) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final canAdjust = context.read<AppState>().can('inventory.manage') || context.read<AppState>().can('inventory.adjust');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(hintText: 'Search product / SKU…', prefixIcon: const Icon(Icons.search), isDense: true,
                  suffixIcon: _query.isNotEmpty ? IconButton(icon: const Icon(Icons.close), onPressed: () { _search.clear(); setState(() { _query = ''; _load(); }); }) : null),
                onSubmitted: (v) => setState(() { _query = v.trim(); _load(); }),
              ),
              const SizedBox(height: 8),
              Row(children: [
                FilterChip(label: const Text('Low stock only'), selected: _lowOnly, onSelected: (v) => setState(() { _lowOnly = v; _load(); })),
              ]),
            ]),
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
            if (list.isEmpty) return ListView(children: const [SizedBox(height: 160), Center(child: Text('No items.', style: TextStyle(color: Color(0xFF64748B))))]);
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = list[i];
                final low = r['low_stock'] == true;
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(r['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${r['sku'] ?? ''}  ${r['variant'] ?? ''}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: (low ? const Color(0xFFDC2626) : const Color(0xFF059669)).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text('${r['stock']}', style: TextStyle(fontWeight: FontWeight.w700, color: low ? const Color(0xFFDC2626) : const Color(0xFF059669)))),
                      if (canAdjust) IconButton(icon: const Icon(Icons.tune), onPressed: () => _adjust(r)),
                    ]),
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

class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet({required this.variantId, required this.name, required this.current});
  final int variantId;
  final String name;
  final num current;
  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  late final TextEditingController _qty = TextEditingController(text: widget.current.toString());
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final q = double.tryParse(_qty.text.trim());
    if (q == null || q < 0) { setState(() => _error = 'Enter a valid quantity.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await context.read<AppState>().api.post('/inventory/adjust', body: {
        'variant_id': widget.variantId, 'new_quantity': q,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
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
          const Text('Adjust Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(widget.name, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          TextField(controller: _qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'New quantity')),
          const SizedBox(height: 10),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Reason / note (optional)')),
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))],
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Update Stock')),
        ]),
      ),
    );
  }
}
