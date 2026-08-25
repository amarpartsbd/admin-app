import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/product_picker.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  bool _isB2b = false;
  int? _clientId;
  List<Map<String, dynamic>> _clients = [];
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _shipping = TextEditingController(text: '0');
  final _advance = TextEditingController(text: '0');
  final _notes = TextEditingController();
  String _method = 'cash';
  final List<Map<String, dynamic>> _items = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (context.read<AppState>().can('b2b.manage')) _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final res = await context.read<AppState>().api.get('/b2b/clients', query: {'per_page': 100});
      setState(() => _clients = (res['data'] as List).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  double get _subtotal => _items.fold(0.0, (s, i) => s + (i['quantity'] as num) * (i['unit_price'] as num));
  double get _total => _subtotal - (double.tryParse(_discount.text) ?? 0) + (double.tryParse(_shipping.text) ?? 0);

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ProductPicker(),
    );
    if (picked == null) return;
    final idx = _items.indexWhere((i) => i['product_variant_id'] == picked['product_variant_id']);
    setState(() {
      if (idx >= 0) {
        _items[idx]['quantity'] = (_items[idx]['quantity'] as num) + 1;
      } else {
        _items.add({...picked, 'quantity': 1});
      }
    });
  }

  Future<void> _save() async {
    if (_items.isEmpty) { setState(() => _error = 'Add at least one item.'); return; }
    if (_isB2b && _clientId == null) { setState(() => _error = 'Select a B2B client.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final body = <String, dynamic>{
        if (_isB2b) 'b2b_client_id': _clientId,
        if (!_isB2b) 'shipping_name': _name.text.trim(),
        if (!_isB2b) 'shipping_phone': _phone.text.trim(),
        'discount': double.tryParse(_discount.text) ?? 0,
        'shipping_charge': double.tryParse(_shipping.text) ?? 0,
        'advance_paid': double.tryParse(_advance.text) ?? 0,
        'payment_method': _method,
        'notes': _notes.text.trim(),
        'items': _items.map((i) => {
          'product_variant_id': i['product_variant_id'],
          'product_name': i['product_name'],
          'sku': i['sku'],
          'color': i['color'],
          'size': i['size'],
          'quantity': i['quantity'],
          'unit_price': i['unit_price'],
          'cost_price': i['cost_price'] ?? 0,
        }).toList(),
      };
      final res = await context.read<AppState>().api.post('/orders', body: body);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Order created.')));
      }
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cur = state.currency;
    final canB2b = state.can('b2b.manage');
    return Scaffold(
      appBar: AppBar(title: const Text('New Order')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (canB2b)
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Retail'), icon: Icon(Icons.person)),
              ButtonSegment(value: true, label: Text('B2B'), icon: Icon(Icons.business)),
            ],
            selected: {_isB2b},
            onSelectionChanged: (s) => setState(() => _isB2b = s.first),
          ),
        const SizedBox(height: 14),
        if (_isB2b)
          DropdownButtonFormField<int>(
            initialValue: _clientId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'B2B Client'),
            items: _clients.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['company_name'] ?? '', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _clientId = v),
          )
        else ...[
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Customer name')),
          const SizedBox(height: 10),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
        ],
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155))),
          TextButton.icon(onPressed: _pickProduct, icon: const Icon(Icons.add), label: const Text('Add item')),
        ]),
        if (_items.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('No items yet.', style: TextStyle(color: Color(0xFF94A3B8))))),
        for (int i = 0; i < _items.length; i++) _itemTile(i, cur),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _discount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount'), onChanged: (_) => setState(() {}))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _shipping, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Shipping'), onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _advance, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Advance paid'))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Payment'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'bkash', child: Text('bKash')),
              DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
              DropdownMenuItem(value: 'bank_transfer', child: Text('Bank')),
              DropdownMenuItem(value: 'cod', child: Text('COD')),
            ],
            onChanged: (v) => setState(() => _method = v ?? 'cash'),
          )),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(children: [
            _tot('Subtotal', money(cur, _subtotal)),
            _tot('Total', money(cur, _total), bold: true),
          ]),
        ),
        if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check),
          label: Text(_saving ? 'Saving…' : 'Create Order'),
        ),
      ]),
    );
  }

  Widget _itemTile(int i, String cur) {
    final it = _items[i];
    final qty = it['quantity'] as num;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${money(cur, it['unit_price'] as num)}  ·  ${[it['color'], it['size']].where((e) => e != null).join(' ')}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ])),
          IconButton(onPressed: () => setState(() { if (qty > 1) it['quantity'] = qty - 1; else _items.removeAt(i); }), icon: const Icon(Icons.remove_circle_outline)),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(onPressed: () => setState(() => it['quantity'] = qty + 1), icon: const Icon(Icons.add_circle_outline)),
        ]),
      ),
    );
  }

  Widget _tot(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: bold ? const Color(0xFF0F172A) : const Color(0xFF64748B), fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        ]),
      );
}
