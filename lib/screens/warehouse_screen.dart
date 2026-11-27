import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'pack_order_screen.dart';
import 'profile_screen.dart';

/// Warehouse: orders waiting to be packed ("In Packing"), oldest first.
/// Warehouse staff land here straight after login; others open it from More.
class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key, this.standalone = false});

  /// True when this is the whole app (warehouse-only staff): shows a profile button.
  final bool standalone;

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> with WidgetsBindingObserver {
  final List<Map<String, dynamic>> _orders = [];
  int _packedToday = 0;
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // New orders arrive while the screen is open: check every minute.
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load(quiet: true);
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() { _loading = true; _error = null; });
    try {
      final res = await context.read<AppState>().api.get('/warehouse/orders');
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll((res['data'] as List).cast<Map<String, dynamic>>());
        _packedToday = (res['counts']?['packed_today'] ?? 0) as int;
        _error = null;
      });
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> o) async {
    final packed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PackOrderScreen(orderId: o['id'] as int, orderNumber: o['order_number'].toString())),
    );
    if (packed == true) _load(quiet: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cur = state.currency;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Packing'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          if (widget.standalone)
            IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            Row(children: [
              Expanded(child: _count('Waiting to pack', _orders.length, kWarning)),
              const SizedBox(width: 10),
              Expanded(child: _count('Packed today', _packedToday, kSuccess)),
            ]),
            const SizedBox(height: 14),
            if (_loading && _orders.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              _message(Icons.cloud_off_rounded, _error!, action: TextButton(onPressed: _load, child: const Text('Try again')))
            else if (_orders.isEmpty)
              _message(Icons.inventory_2_outlined, 'Nothing to pack right now.\nOrders marked "Confirmed" show up here.')
            else
              ..._orders.map((o) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _tile(o, cur))),
          ],
        ),
      ),
    );
  }

  Widget _count(String label, int n, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: softCard(radius: 16),
        child: Row(children: [
          Text('$n', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kMuted))),
        ]),
      );

  Widget _message(IconData icon, String text, {Widget? action}) => Padding(
        padding: const EdgeInsets.only(top: 70),
        child: Column(children: [
          Icon(icon, size: 44, color: kFaint),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: kMuted, height: 1.4)),
          if (action != null) action,
        ]),
      );

  Widget _tile(Map<String, dynamic> o, String cur) {
    final waited = _since(o['waiting_since']?.toString());
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(o),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: softCard(radius: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(o['order_number'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kInk)),
              if (o['status'] == 'in_packing') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('In Packing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
                ),
              ],
              const Spacer(),
              if (waited != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: kWarning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(waited, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kWarning)),
                ),
            ]),
            const SizedBox(height: 4),
            Text('${o['customer']}${(o['area'] ?? '').toString().isNotEmpty ? ' · ${o['area']}' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 8),
            Text(o['items_preview']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kInk, fontSize: 13.5, height: 1.35)),
            const SizedBox(height: 10),
            Row(children: [
              Text('${o['items_count']} item${o['items_count'] == 1 ? '' : 's'}', style: const TextStyle(color: kMuted, fontSize: 12.5)),
              const Spacer(),
              Text(money(cur, (o['total'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w700, color: kInk)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: kFaint),
            ]),
          ]),
        ),
      ),
    );
  }

  /// "12 min", "3 h" — how long the order has waited for packing.
  String? _since(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso);
    if (t == null) return null;
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h';
    return '${d.inDays} d';
  }
}
