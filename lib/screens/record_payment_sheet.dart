import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({super.key, required this.orderId, required this.due});
  final int orderId;
  final double due;
  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  late final TextEditingController _amount = TextEditingController(text: widget.due.toStringAsFixed(0));
  final _note = TextEditingController();
  String _method = 'cash';
  bool _loading = false;
  String? _error;

  static const _methods = {
    'cash': 'Cash', 'bkash': 'bKash', 'nagad': 'Nagad',
    'bank_transfer': 'Bank Transfer', 'cheque': 'Cheque', 'card': 'Card',
  };

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) { setState(() => _error = 'Enter a valid amount.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await context.read<AppState>().api.post('/b2b/orders/${widget.orderId}/payment', body: {
        'amount': amount, 'method': _method, if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Payment recorded.')));
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text('Due: ${money(cur, widget.due)}', style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Method'),
            items: _methods.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _method = v ?? 'cash'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note / Ref (optional)')),
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Receive Payment'),
          ),
        ]),
      ),
    );
  }
}
