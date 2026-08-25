import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'record_payment_sheet.dart';

class B2bClientScreen extends StatefulWidget {
  const B2bClientScreen({super.key, required this.clientId, required this.name});
  final int clientId;
  final String name;
  @override
  State<B2bClientScreen> createState() => _B2bClientScreenState();
}

class _B2bClientScreenState extends State<B2bClientScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<AppState>().api.get('/b2b/clients/${widget.clientId}');
      _data = Map<String, dynamic>.from(res);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String? url) async {
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cur = state.currency;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(child: _stat('Purchase', money(cur, (_data!['overview']['total_purchase'] ?? 0) as num), const Color(0xFF2563EB))),
                  const SizedBox(width: 10),
                  Expanded(child: _stat('Paid', money(cur, (_data!['overview']['total_paid'] ?? 0) as num), const Color(0xFF059669))),
                  const SizedBox(width: 10),
                  Expanded(child: _stat('Due', money(cur, (_data!['overview']['total_due'] ?? 0) as num), const Color(0xFFDC2626))),
                ]),
                const SizedBox(height: 16),
                const Text('Invoices', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                const SizedBox(height: 8),
                for (final inv in (_data!['invoices'] as List).cast<Map<String, dynamic>>()) _invoice(inv, cur, state),
              ]),
            ),
    );
  }

  Widget _stat(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ]),
      );

  Widget _invoice(Map<String, dynamic> inv, String cur, AppState state) {
    final due = (inv['due'] ?? 0) as num;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(inv['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            Builder(builder: (_) {
              final sc = statusColor((inv['status'] ?? '').toString());
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
                child: Text(inv['status_label'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sc)),
              );
            }),
          ]),
          const SizedBox(height: 2),
          Text('${inv['challan_number'] ?? ''}  ·  ${inv['date'] ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total ${money(cur, (inv['total'] ?? 0) as num)}'),
            Text(due > 0 ? 'Due ${money(cur, due)}' : 'Paid', style: TextStyle(color: due > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669), fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _open(inv['invoice_url']), icon: const Icon(Icons.description_outlined, size: 18), label: const Text('Invoice'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _open(inv['challan_url']), icon: const Icon(Icons.local_shipping_outlined, size: 18), label: const Text('Challan'))),
          ]),
          if (due > 0 && state.can('b2b.manage')) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                onPressed: () async {
                  final ok = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => RecordPaymentSheet(orderId: inv['id'] as int, due: due.toDouble()),
                  );
                  if (ok == true) _load();
                },
                icon: const Icon(Icons.payments, size: 18),
                label: const Text('Record Payment'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
