import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'record_payment_sheet.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final int orderId;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _statuses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AppState>().api;
      final res = await api.get('/orders/${widget.orderId}');
      _order = Map<String, dynamic>.from(res['data']);
      if (_statuses.isEmpty) {
        final meta = await api.get('/orders/meta');
        _statuses = (meta['statuses'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open document.')));
    }
  }

  Future<void> _changeStatus() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Change status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          for (final s in _statuses)
            ListTile(title: Text(s['label']), onTap: () => Navigator.pop(context, s['value'] as String)),
        ]),
      ),
    );
    if (selected == null) return;

    final body = <String, dynamic>{'status': selected};
    if (selected == 'hold' || selected == 'cancel') {
      final note = await _prompt(selected == 'cancel' ? 'Cancel reason' : 'Hold note');
      if (note == null || note.isEmpty) return;
      body['note'] = note;
    }
    if (!mounted) return;
    try {
      await context.read<AppState>().api.post('/orders/${widget.orderId}/status', body: body);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<String?> _prompt(String label) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cur = state.currency;
    final o = _order;
    return Scaffold(
      appBar: AppBar(title: Text(o?['order_number'] ?? 'Order')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    _card([
                      _row('Customer', o!['party_name'] ?? ''),
                      if (o['party_phone'] != null) _row('Phone', o['party_phone']),
                      _row('Status', o['status_label'] ?? ''),
                      if (o['challan_number'] != null) _row('Challan', o['challan_number']),
                    ]),
                    const SizedBox(height: 12),
                    _sectionTitle('Items'),
                    _card([
                      for (final it in (o['items'] as List).cast<Map<String, dynamic>>())
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(it['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${_qty(it['quantity'])} × ${money(cur, (it['unit_price'] ?? 0) as num)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ])),
                            Text(money(cur, (it['line_total'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    _sectionTitle('Financials'),
                    _card([
                      _row('Subtotal', money(cur, (o['financials']['subtotal'] ?? 0) as num)),
                      _row('Discount', money(cur, (o['financials']['discount'] ?? 0) as num)),
                      _row('Shipping', money(cur, (o['financials']['shipping_charge'] ?? 0) as num)),
                      const Divider(),
                      _row('Total', money(cur, (o['financials']['total'] ?? 0) as num), bold: true),
                      _row('Paid', money(cur, (o['financials']['paid'] ?? 0) as num), color: const Color(0xFF059669)),
                      _row('Due', money(cur, (o['financials']['due'] ?? 0) as num), color: const Color(0xFFDC2626), bold: true),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: () => _open(o['invoice_url']), icon: const Icon(Icons.description_outlined), label: const Text('Invoice'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(onPressed: () => _open(o['challan_url']), icon: const Icon(Icons.local_shipping_outlined), label: const Text('Challan'))),
                    ]),
                    const SizedBox(height: 10),
                    if (o['is_b2b'] == true && ((o['financials']['due'] ?? 0) as num) > 0 && state.can('b2b.manage'))
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                        onPressed: () async {
                          final ok = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => RecordPaymentSheet(orderId: o['id'] as int, due: (o['financials']['due'] as num).toDouble()),
                          );
                          if (ok == true) _load();
                        },
                        icon: const Icon(Icons.payments),
                        label: Text('Record Payment · Due ${money(cur, (o['financials']['due'] ?? 0) as num)}'),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(onPressed: _changeStatus, icon: const Icon(Icons.sync), label: const Text('Change Status')),
                  ]),
                ),
    );
  }

  String _qty(dynamic q) {
    final n = (q as num).toDouble();
    return n == n.truncateToDouble() ? n.toInt().toString() : n.toString();
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155))),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(children: children),
      );

  Widget _row(String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color ?? const Color(0xFF0F172A)))),
        ]),
      );
}
