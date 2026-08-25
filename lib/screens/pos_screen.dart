import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/product_picker.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _discount = TextEditingController(text: '0');
  String _method = 'cash';
  final List<Map<String, dynamic>> _cart = [];
  bool _saving = false;
  String? _error;

  double get _subtotal => _cart.fold(0.0, (s, i) => s + (i['quantity'] as num) * (i['unit_price'] as num));
  double get _total => _subtotal - (double.tryParse(_discount.text) ?? 0);

  Future<void> _add() async {
    final v = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, builder: (_) => const ProductPicker());
    if (v == null) return;
    final idx = _cart.indexWhere((i) => i['product_variant_id'] == v['product_variant_id']);
    setState(() {
      if (idx >= 0) {
        _cart[idx]['quantity'] = (_cart[idx]['quantity'] as num) + 1;
      } else {
        _cart.add({...v, 'quantity': 1});
      }
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) { setState(() => _error = 'Cart is empty.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final res = await context.read<AppState>().api.post('/pos/sale', body: {
        if (_name.text.trim().isNotEmpty) 'walkin_name': _name.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'walkin_phone': _phone.text.trim(),
        'discount': double.tryParse(_discount.text) ?? 0,
        'method': _method,
        'items': _cart.map((i) => {
          'product_variant_id': i['product_variant_id'],
          'product_name': i['product_name'],
          'sku': i['sku'], 'color': i['color'], 'size': i['size'],
          'quantity': i['quantity'], 'unit_price': i['unit_price'], 'cost_price': i['cost_price'] ?? 0,
        }).toList(),
      });
      if (mounted) {
        setState(() { _cart.clear(); _name.clear(); _phone.clear(); _discount.text = '0'; _saving = false; });
        final o = res['order'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale ${o['order_number']} completed.')));
      }
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Scaffold(
      appBar: AppBar(title: const Text('POS — Quick Sale'), actions: [
        TextButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Item')),
      ]),
      body: Column(children: [
        Expanded(
          child: _cart.isEmpty
              ? const Center(child: Text('Tap "Item" to add products.', style: TextStyle(color: Color(0xFF94A3B8))))
              : ListView(padding: const EdgeInsets.all(12), children: [
                  for (int i = 0; i < _cart.length; i++) _line(i, cur),
                ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Customer (optional)', isDense: true))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', isDense: true))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _discount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount', isDense: true), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Method', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'multiple', child: Text('Multiple')),
                  DropdownMenuItem(value: 'credit', child: Text('Credit')),
                ],
                onChanged: (v) => setState(() => _method = v ?? 'cash'),
              )),
            ]),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))],
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(money(cur, _total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              onPressed: _saving ? null : _checkout,
              icon: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle),
              label: Text(_saving ? 'Processing…' : 'Complete Sale'),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _line(int i, String cur) {
    final it = _cart[i];
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
          IconButton(onPressed: () => setState(() { if (qty > 1) it['quantity'] = qty - 1; else _cart.removeAt(i); }), icon: const Icon(Icons.remove_circle_outline)),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(onPressed: () => setState(() => it['quantity'] = qty + 1), icon: const Icon(Icons.add_circle_outline)),
        ]),
      ),
    );
  }
}
