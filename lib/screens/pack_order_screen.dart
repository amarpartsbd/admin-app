import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Pack one order: weigh each item sold by the kg (the price follows the real weight),
/// check the pieces, then send it to Ready to Ship.
class PackOrderScreen extends StatefulWidget {
  const PackOrderScreen({super.key, required this.orderId, required this.orderNumber});
  final int orderId;
  final String orderNumber;

  @override
  State<PackOrderScreen> createState() => _PackOrderScreenState();
}

class _PackOrderScreenState extends State<PackOrderScreen> {
  Map<String, dynamic>? _order;
  String? _error;
  bool _saving = false;
  final Map<int, TextEditingController> _kg = {};
  final Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _kg.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Server says whether this order can still be packed (Confirmed or In Packing).
  bool get _canPack => _order?['can_pack'] == true || _order?['status'] == 'in_packing';

  List<Map<String, dynamic>> get _items => ((_order?['items'] as List?) ?? const []).cast<Map<String, dynamic>>();

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await context.read<AppState>().api.get('/warehouse/orders/${widget.orderId}');
      final o = Map<String, dynamic>.from(res['data']);
      for (final i in (o['items'] as List).cast<Map<String, dynamic>>()) {
        if (i['sold_by_weight'] == true) _kg.putIfAbsent(i['id'] as int, () => TextEditingController());
      }
      setState(() => _order = o);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  double? _weighed(Map<String, dynamic> i) {
    final t = _kg[i['id']]?.text.trim().replaceAll(',', '.') ?? '';
    final v = double.tryParse(t);
    return (v != null && v > 0) ? v : null;
  }

  /// Line total at the weighed amount (pieces keep their price).
  num _line(Map<String, dynamic> i) {
    if (i['sold_by_weight'] != true) return (i['line_total'] ?? 0) as num;
    final w = _weighed(i);
    if (w == null) return (i['line_total'] ?? 0) as num;
    return ((i['unit_price'] as num) * w * 100).round() / 100;
  }

  bool _farOff(Map<String, dynamic> i) {
    final w = _weighed(i);
    final q = (i['quantity'] as num).toDouble();
    final max = ((_order?['max_change'] ?? 0.5) as num).toDouble();
    return w != null && q > 0 && (w - q).abs() > q * max;
  }

  bool get _allWeighed => _items.every((i) => i['sold_by_weight'] != true || (_weighed(i) != null && !_farOff(i)));

  num get _newTotal {
    final o = _order!;
    final sub = _items.fold<num>(0, (s, i) => s + _line(i));
    return sub - ((o['discount'] ?? 0) as num) + ((o['shipping_charge'] ?? 0) as num);
  }

  double get _parcelKg => _items.fold<double>(0, (s, i) =>
      s + (i['sold_by_weight'] == true ? (_weighed(i) ?? (i['quantity'] as num).toDouble()) : 0));

  String _kgText(num v) {
    final s = v.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    return '$s kg';
  }

  Future<void> _pack() async {
    final cur = context.read<AppState>().currency;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ready to ship?'),
        content: Text('Order ${widget.orderNumber} will move to Ready to Ship.\n\nNew total: ${money(cur, _newTotal)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ready to Ship'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() { _saving = true; _fieldErrors.clear(); });
    try {
      final res = await context.read<AppState>().api.post('/warehouse/orders/${widget.orderId}/pack', body: {
        'weights': {
          for (final i in _items)
            if (i['sold_by_weight'] == true) '${i['id']}': _weighed(i),
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((res['message'] ?? 'Ready to ship.').toString())));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        e.errors.forEach((k, v) => _fieldErrors[k] = (v is List && v.isNotEmpty) ? v.first.toString() : v.toString());
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    final o = _order;
    return Scaffold(
      appBar: AppBar(title: Text('Pack ${widget.orderNumber}')),
      body: o == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
                      TextButton(onPressed: _load, child: const Text('Try again')),
                    ]),
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                children: [
                  if (!_canPack)
                    _banner(Icons.info_outline, 'This order is ${o['status_label']} — it is no longer waiting to be packed.', kWarning),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: softCard(radius: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o['customer'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kInk)),
                      if ((o['address'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(o['address'].toString(), style: const TextStyle(color: kMuted, height: 1.35)),
                      ],
                    ]),
                  ),
                  if ((o['notes'] ?? '').toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _banner(Icons.sticky_note_2_outlined, o['notes'].toString(), const Color(0xFFB45309)),
                  ],
                  const SizedBox(height: 14),
                  const Text('ITEMS', style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: kMuted)),
                  const SizedBox(height: 8),
                  ..._items.map((i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _itemCard(i, cur))),
                ],
              ),
            ),
      bottomNavigationBar: o == null || !_canPack ? null : _bottom(cur),
    );
  }

  Widget _banner(IconData icon, String text, Color c) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w600, height: 1.35))),
        ]),
      );

  Widget _itemCard(Map<String, dynamic> i, String cur) {
    final byWeight = i['sold_by_weight'] == true;
    final q = (i['quantity'] as num);
    final img = i['image']?.toString();
    final err = _fieldErrors['weights.${i['id']}'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: softCard(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52, height: 52,
              child: img == null
                  ? Container(color: kBg, child: const Icon(Icons.image_outlined, color: kFaint))
                  : Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: kBg)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i['product_name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, color: kInk, height: 1.3)),
              if (i['variant'] != null) Text(i['variant'].toString(), style: const TextStyle(color: kMuted, fontSize: 12.5)),
              const SizedBox(height: 4),
              Text(
                byWeight
                    ? 'Ordered ${_kgText(q)} · ${money(cur, i['unit_price'] as num)}/kg'
                    : 'Pack ${q.toStringAsFixed(q.truncateToDouble() == q ? 0 : 2)} × ${(i['unit'] ?? 'pc').toString()}',
                style: const TextStyle(color: kMuted, fontSize: 12.5),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Text(money(cur, _line(i)), style: const TextStyle(fontWeight: FontWeight.w800, color: kInk)),
        ]),
        if (byWeight) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _kg[i['id']],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Weighed (kg)',
                  hintText: q.toString(),
                  suffixText: 'kg',
                  isDense: true,
                  errorText: err ?? (_farOff(i) ? 'Far from the ${_kgText(q)} ordered — check the scale' : null),
                ),
                onChanged: (_) => setState(() => _fieldErrors.remove('weights.${i['id']}')),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => setState(() => _kg[i['id']]!.text = q.toString()),
              child: const Text('As ordered'),
            ),
          ]),
          if (_weighed(i) != null && !_farOff(i)) _diff(i, cur),
        ],
      ]),
    );
  }

  /// "+80 g · +৳65.60" under a weighed item.
  Widget _diff(Map<String, dynamic> i, String cur) {
    final w = _weighed(i)!;
    final q = (i['quantity'] as num).toDouble();
    final g = ((w - q) * 1000).round();
    if (g == 0) return const SizedBox.shrink();
    final money0 = _line(i) - (i['line_total'] as num);
    final c = g > 0 ? kSuccess : kDanger;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text('${g > 0 ? '+' : '−'}${g.abs()} g · ${money0 >= 0 ? '+' : '−'}${money(cur, money0.abs())}',
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12.5)),
    );
  }

  Widget _bottom(String cur) {
    final o = _order!;
    final old = (o['total'] ?? 0) as num;
    final now = _newTotal;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kLine))),
        child: Row(children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(money(cur, now), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kInk)),
                if ((now - old).abs() >= 0.01) ...[
                  const SizedBox(width: 8),
                  Text(money(cur, old), style: const TextStyle(color: kFaint, decoration: TextDecoration.lineThrough)),
                ],
              ]),
              Text('Parcel ≈ ${_kgText(_parcelKg)}', style: const TextStyle(color: kMuted, fontSize: 12.5)),
            ]),
          ),
          FilledButton.icon(
            onPressed: _allWeighed && !_saving ? _pack : null,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.local_shipping_outlined),
            label: Text(_allWeighed ? 'Ready to Ship' : 'Weigh all items'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          ),
        ]),
      ),
    );
  }
}
